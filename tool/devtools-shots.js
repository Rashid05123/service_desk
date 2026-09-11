#!/usr/bin/env node
/**
 * Снятие вкладки Network панели разработчика Chrome.
 *
 * Панель разработчика — обычная веб-страница: Chrome отдаёт её по своему
 * же отладочному порту, по адресу /devtools/inspector.html. Поэтому её
 * можно открыть второй вкладкой, направить на вкладку с приложением
 * и снять как любую другую страницу.
 *
 *   node tool/devtools-shots.js <папка для снимков>
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
const PORT = 9222;
const WIDTH = 1600;
const HEIGHT = 1000;

const OUT = process.argv[2] || 'shots';
fs.mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ───────────────────────────── запуск Chrome ─────────────────────────────

async function launch() {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'sd-devtools-'));
  const chrome = spawn(
    CHROME,
    [
      '--headless=new',
      `--remote-debugging-port=${PORT}`,
      // Без этого Chrome отклоняет подключение самой панели разработчика:
      // она приходит с заголовком Origin, а он по умолчанию запрещён.
      '--remote-allow-origins=*',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      // Вкладка в фоне перестаёт получать кадры, и Flutter не
      // обрабатывает щелчки. Эти ключи снимают часть ограничений,
      // остальное решает переключение вкладки перед действием.
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--hide-scrollbars',
      '--force-device-scale-factor=1',
      `--window-size=${WIDTH},${HEIGHT}`,
      `--user-data-dir=${profile}`,
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  for (let i = 0; i < 80; i++) {
    try {
      const version = await fetch(
        `http://127.0.0.1:${PORT}/json/version`,
      ).then((r) => r.json());
      if (version.webSocketDebuggerUrl) {
        return { chrome, browserWs: version.webSocketDebuggerUrl };
      }
    } catch (_) {
      // порт ещё не открыт
    }
    await sleep(250);
  }
  throw new Error('Chrome не открыл отладочный порт');
}

// ─────────────────── обёртка над протоколом отладки ───────────────────

class Browser {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      this.pending.delete(message.id);
      message.error
        ? waiter.reject(new Error(message.error.message))
        : waiter.resolve(message.result);
    });
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify(payload));
    });
  }

  /** Новая вкладка и присоединённый к ней сеанс. */
  async openTab(url) {
    const { targetId } = await this.send('Target.createTarget', { url });
    const { sessionId } = await this.send('Target.attachToTarget', {
      targetId,
      flatten: true,
    });
    await this.send('Page.enable', {}, sessionId);
    return new Tab(this, targetId, sessionId);
  }
}

class Tab {
  constructor(browser, targetId, sessionId) {
    this.browser = browser;
    this.targetId = targetId;
    this.sessionId = sessionId;
  }

  send(method, params) {
    return this.browser.send(method, params, this.sessionId);
  }

  async open(url, wait = 3000) {
    await this.send('Page.navigate', { url });
    await sleep(wait);
  }

  async click(x, y, wait = 800) {
    // Вкладка в фоне не обрабатывает ввод, поэтому перед щелчком она
    // выводится на передний план.
    await this.front();
    const base = { x, y, button: 'left', clickCount: 1 };
    await this.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
    await this.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...base });
    await sleep(40);
    await this.send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...base });
    await sleep(wait);
  }

  async typeChar(char, wait = 600) {
    await this.send('Input.dispatchKeyEvent', { type: 'keyDown', text: char });
    await this.send('Input.dispatchKeyEvent', { type: 'keyUp' });
    await sleep(wait);
  }

  async front() {
    await this.send('Page.bringToFront');
    await sleep(400);
  }

  /**
   * Снимок. Полоса слева — трансляция осматриваемой страницы, она
   * в отчёте не нужна, поэтому кадр обрезается по [clip].
   */
  async shot(name, clip) {
    await this.front();
    const { data } = await this.send('Page.captureScreenshot', {
      format: 'png',
      ...(clip ? { clip: { ...clip, scale: 1 } } : {}),
    });
    const file = path.join(OUT, name + '.png');
    fs.writeFileSync(file, Buffer.from(data, 'base64'));
    console.log('снято:', file);
  }
}

// ─────────────────────────────── сценарий ───────────────────────────────

async function main() {
  const { chrome, browserWs } = await launch();
  const ws = new WebSocket(browserWs);
  await new Promise((resolve) => ws.addEventListener('open', resolve));
  const browser = new Browser(ws);

  // Вкладка с приложением.
  const app = await browser.openTab(APP + '/tickets');
  await sleep(6000);

  // Вкладка с панелью разработчика, направленной на первую.
  const devtoolsUrl =
    `http://127.0.0.1:${PORT}/devtools/inspector.html` +
    `?ws=127.0.0.1:${PORT}/devtools/page/${app.targetId}&panel=network`;
  const devtools = await browser.openTab(devtoolsUrl);
  await sleep(6000);

  const script = require('./devtools-script.js');
  await script({ app, devtools, sleep, APP });

  ws.close();
  chrome.kill();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
