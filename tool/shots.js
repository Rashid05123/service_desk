#!/usr/bin/env node
/**
 * Снятие экранов приложения через протокол разработчика Chrome.
 *
 * Нужен, чтобы снимки для отчёта делались одной командой и повторялись
 * один в один: тот же размер окна, та же последовательность действий.
 * Зависимостей нет — Node 22 умеет WebSocket сам.
 *
 *   node tool/shots.js <папка для снимков>
 *
 * Приложение и учебный сервер должны быть уже запущены.
 */

'use strict';

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const APP = 'http://localhost:5555';
const WIDTH = 1440;
const HEIGHT = 900;

const OUT = process.argv[2] || 'shots';
fs.mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ───────────────────────────── запуск Chrome ─────────────────────────────

async function launch() {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'sd-shots-'));
  const chrome = spawn(CHROME, [
    '--headless=new',
    '--remote-debugging-port=9222',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-unsafe-swiftshader',
    '--hide-scrollbars',
    '--force-device-scale-factor=1',
    `--window-size=${WIDTH},${HEIGHT}`,
    `--user-data-dir=${profile}`,
    'about:blank',
  ], { stdio: 'ignore' });

  for (let i = 0; i < 60; i++) {
    try {
      const list = await fetch('http://127.0.0.1:9222/json/list').then((r) => r.json());
      const page = list.find((t) => t.type === 'page');
      if (page) return { chrome, wsUrl: page.webSocketDebuggerUrl };
    } catch (_) {
      // порт ещё не открыт
    }
    await sleep(250);
  }
  throw new Error('Chrome не открыл порт отладки');
}

// ─────────────────────────── обёртка над CDP ───────────────────────────

class Session {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      this.pending.delete(message.id);
      message.error ? waiter.reject(new Error(message.error.message))
                    : waiter.resolve(message.result);
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async open(url, wait = 2500) {
    await this.send('Page.navigate', { url });
    await sleep(wait);
  }

  /** Клик по точке. Flutter рисует в canvas, поэтому только координаты. */
  async click(x, y, wait = 900) {
    const base = { x, y, button: 'left', clickCount: 1 };
    await this.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
    await this.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...base });
    await sleep(40);
    await this.send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...base });
    await sleep(wait);
  }

  /** Выделить содержимое поля: Ctrl+A внутри сфокусированного ввода. */
  async selectAll() {
    for (const type of ['keyDown', 'keyUp']) {
      await this.send('Input.dispatchKeyEvent', {
        type,
        key: 'a',
        code: 'KeyA',
        windowsVirtualKeyCode: 65,
        nativeVirtualKeyCode: 65,
        modifiers: 2, // Ctrl
      });
    }
    await sleep(200);
  }

  async type(text, wait = 300) {
    await this.send('Input.insertText', { text });
    await sleep(wait);
  }

  /** Посимвольный ввод настоящими событиями клавиатуры. */
  async typeChar(char, wait = 450) {
    await this.send('Input.dispatchKeyEvent', { type: 'keyDown', text: char });
    await this.send('Input.dispatchKeyEvent', { type: 'char', text: char });
    await this.send('Input.dispatchKeyEvent', { type: 'keyUp', text: char });
    await sleep(wait);
  }

  async key(key, code, windowsVirtualKeyCode, wait = 600) {
    for (const type of ['keyDown', 'keyUp']) {
      await this.send('Input.dispatchKeyEvent', {
        type, key, code, windowsVirtualKeyCode,
        nativeVirtualKeyCode: windowsVirtualKeyCode,
      });
    }
    await sleep(wait);
  }

  async shot(name) {
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    const file = path.join(OUT, name + '.png');
    fs.writeFileSync(file, Buffer.from(data, 'base64'));
    console.log('снято:', file);
  }

  async resize(width, height, mobile = false) {
    await this.send('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: 1, mobile,
    });
    await sleep(600);
  }
}

// ─────────────────────────────── сценарий ───────────────────────────────

async function main() {
  const { chrome, wsUrl } = await launch();
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve) => ws.addEventListener('open', resolve));

  const page = new Session(ws);
  await page.send('Page.enable');
  await page.resize(WIDTH, HEIGHT);

  const script = require('./shot-script.js');
  await script(page, { sleep, APP });

  ws.close();
  chrome.kill();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
