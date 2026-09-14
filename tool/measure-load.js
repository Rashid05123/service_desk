#!/usr/bin/env node
/**
 * Замер первой загрузки собранного приложения.
 *
 *   node tool/measure-load.js <адрес> [число прогонов]
 *   node tool/measure-load.js http://localhost:5601/login 5
 *
 * Каждый прогон — новый Chrome с пустым профилем и отключённым кэшем,
 * то есть действительно первая загрузка. Меряется время от начала
 * перехода до события flutter-first-frame, объём переданных до этого
 * момента данных и то, какой вариант сборки выбрал браузер: WebAssembly
 * или JavaScript. Итог — медиана по прогонам: одиночный замер на машине,
 * где работает что-то ещё, скачет на десятки процентов.
 */

'use strict';

const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const URL_ = process.argv[2];
const RUNS = Number(process.argv[3] || 5);
const PORT = 9223;

if (!URL_) {
  console.error('укажите адрес приложения');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function launch() {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'sd-measure-'));
  const chrome = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-unsafe-swiftshader',
    '--window-size=1280,800',
    `--user-data-dir=${profile}`,
    'about:blank',
  ], { stdio: 'ignore' });

  for (let i = 0; i < 80; i++) {
    try {
      const list = await fetch(`http://127.0.0.1:${PORT}/json/list`).then((r) => r.json());
      const page = list.find((t) => t.type === 'page');
      if (page) return { chrome, profile, wsUrl: page.webSocketDebuggerUrl };
    } catch (_) {
      // порт ещё не открыт
    }
    await sleep(250);
  }
  throw new Error('Chrome не открыл порт отладки');
}

async function run() {
  const { chrome, profile, wsUrl } = await launch();
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve) => ws.addEventListener('open', resolve));

  let id = 0;
  const pending = new Map();
  const requests = new Map();
  let transferred = 0;
  let frameSeen = false;

  ws.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg.result);
      pending.delete(msg.id);
      return;
    }
    if (msg.method === 'Network.requestWillBeSent') {
      requests.set(msg.params.requestId, { url: msg.params.request.url, bytes: 0 });
    } else if (msg.method === 'Network.loadingFinished' && !frameSeen) {
      const req = requests.get(msg.params.requestId);
      if (req) req.bytes = msg.params.encodedDataLength;
      transferred += msg.params.encodedDataLength;
    }
  });

  const send = (method, params = {}) => new Promise((resolve) => {
    const n = ++id;
    pending.set(n, resolve);
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  const evaluate = async (expression) =>
    (await send('Runtime.evaluate', { expression, returnByValue: true })).result.value;

  await send('Page.enable');
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source:
      "window.__firstFrame = null;" +
      "window.addEventListener('flutter-first-frame', function () {" +
      "  window.__firstFrame = performance.now();" +
      "});",
  });

  await send('Page.navigate', { url: URL_ });

  let firstFrame = null;
  for (let i = 0; i < 1200 && firstFrame == null; i++) {
    await sleep(50);
    firstFrame = await evaluate('window.__firstFrame');
  }
  frameSeen = true;

  const urls = [...requests.values()].map((r) => r.url);
  const variant = urls.some((u) => u.endsWith('main.dart.wasm')) ? 'wasm' : 'js';
  const renderer = urls.find((u) => /\/(canvaskit|skwasm[^/]*)\.wasm$/.test(u)) || '—';

  ws.close();
  chrome.kill();
  await sleep(500);
  fs.rmSync(profile, { recursive: true, force: true });

  return {
    firstFrameMs: firstFrame == null ? null : Math.round(firstFrame),
    transferredKb: Math.round(transferred / 1024),
    requests: requests.size,
    variant,
    renderer,
  };
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : Math.round((sorted[mid - 1] + sorted[mid]) / 2);
}

(async () => {
  const results = [];
  for (let i = 0; i < RUNS; i++) {
    const r = await run();
    console.log(`прогон ${i + 1}:`, JSON.stringify(r));
    results.push(r);
  }
  const ok = results.filter((r) => r.firstFrameMs != null);
  console.log(JSON.stringify({
    url: URL_,
    runs: ok.length,
    medianFirstFrameMs: median(ok.map((r) => r.firstFrameMs)),
    medianTransferredKb: median(ok.map((r) => r.transferredKb)),
    variant: ok[0]?.variant,
    renderer: ok[0]?.renderer,
  }));
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
