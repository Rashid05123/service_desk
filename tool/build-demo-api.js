#!/usr/bin/env node
/**
 * Учебный сервер внутри опубликованной сборки.
 *
 *   node tool/build-demo-api.js build/web
 *
 * GitHub Pages отдаёт только статические файлы, а страница по HTTPS
 * не может обращаться к серверу на машине проверяющего: браузер блокирует
 * такие запросы. Поэтому api/mock-server.js — тот же самый файл, без
 * копирования логики — собирается в service worker. Он перехватывает
 * запросы страницы к <сайт>/service_desk/api/… и отвечает так же, как
 * сервер на Node: те же адреса, проверка прав, токены и коды ошибок.
 *
 * Что делает скрипт:
 *   - api-sw.js: заглушки модулей Node (http, fs, path, crypto, Buffer),
 *     начальный набор seed.json и исходник mock-server.js;
 *   - demo-api.js: регистрирует service worker и только после того, как
 *     он начал обслуживать страницу, запускает flutter_bootstrap.js —
 *     иначе первые запросы ушли бы мимо него;
 *   - index.html: подключение flutter_bootstrap.js заменяется на demo-api.js.
 *
 * Данные живут в браузере проверяющего и сохраняются в Cache Storage после
 * каждого изменения: браузер останавливает бездействующий service worker,
 * и без сохранения выход из системы случался бы через полминуты простоя.
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const out = path.resolve(process.argv[2] || 'build/web');
const api = path.join(__dirname, '..', 'api');

const server = fs.readFileSync(path.join(api, 'mock-server.js'), 'utf8')
  .replace(/^#!.*\n/, '');
const seed = fs.readFileSync(path.join(api, 'seed.json'), 'utf8');

// ─────────────────────── заглушки модулей Node ───────────────────────

const shims = String.raw`
// SHA-256 и HMAC синхронно: mock-server.js вызывает их синхронно, а
// WebCrypto в браузере умеет только асинхронно.
const K = new Uint32Array([
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);

function sha256(bytes) {
  const len = bytes.length;
  const padded = new Uint8Array(((len + 9 + 63) >> 6) << 6);
  padded.set(bytes);
  padded[len] = 0x80;
  const view = new DataView(padded.buffer);
  view.setUint32(padded.length - 4, len * 8);
  view.setUint32(padded.length - 8, Math.floor(len / 0x20000000));
  const h = new Uint32Array([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
    0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]);
  const w = new Uint32Array(64);
  for (let off = 0; off < padded.length; off += 64) {
    for (let i = 0; i < 16; i++) w[i] = view.getUint32(off + i * 4);
    for (let i = 16; i < 64; i++) {
      const a = w[i - 15], b = w[i - 2];
      const s0 = ((a >>> 7) | (a << 25)) ^ ((a >>> 18) | (a << 14)) ^ ((a >>> 3) | (a << 29));
      const s1 = ((b >>> 17) | (b << 15)) ^ ((b >>> 19) | (b << 13)) ^ ((b >>> 10) | (b << 22));
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
    }
    let [A, B, C, D, E, F, G, H] = h;
    for (let i = 0; i < 64; i++) {
      const s1 = ((E >>> 6) | (E << 26)) ^ ((E >>> 11) | (E << 21)) ^ ((E >>> 25) | (E << 7));
      const t1 = (H + s1 + ((E & F) ^ (~E & G)) + K[i] + w[i]) | 0;
      const s0 = ((A >>> 2) | (A << 30)) ^ ((A >>> 13) | (A << 19)) ^ ((A >>> 22) | (A << 10));
      const t2 = (s0 + ((A & B) ^ (A & C) ^ (B & C))) | 0;
      H = G; G = F; F = E; E = (D + t1) | 0; D = C; C = B; B = A; A = (t1 + t2) | 0;
    }
    h[0] += A; h[1] += B; h[2] += C; h[3] += D; h[4] += E; h[5] += F; h[6] += G; h[7] += H;
  }
  const result = new Uint8Array(32);
  const rv = new DataView(result.buffer);
  for (let i = 0; i < 8; i++) rv.setUint32(i * 4, h[i]);
  return result;
}

const utf8 = new TextEncoder();
const fromUtf8 = new TextDecoder();

class Buffer extends Uint8Array {
  static from(value, encoding) {
    if (typeof value !== 'string') return new Buffer(value);
    if (encoding === 'base64url' || encoding === 'base64') {
      const b64 = value.replace(/-/g, '+').replace(/_/g, '/');
      const bin = atob(b64 + '==='.slice((b64.length + 3) % 4));
      return new Buffer(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
    }
    return new Buffer(utf8.encode(value));
  }
  static concat(list) {
    const total = list.reduce((n, b) => n + b.length, 0);
    const result = new Buffer(total);
    let offset = 0;
    for (const b of list) { result.set(b, offset); offset += b.length; }
    return result;
  }
  toString(encoding) {
    if (encoding === 'hex') return [...this].map((b) => b.toString(16).padStart(2, '0')).join('');
    if (encoding === 'base64url' || encoding === 'base64') {
      const b64 = btoa(String.fromCharCode(...this));
      return encoding === 'base64' ? b64
        : b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    }
    return fromUtf8.decode(this);
  }
}

function digestOf(bytes, encoding) {
  const b = Buffer.from(bytes);
  return encoding ? b.toString(encoding) : b;
}

function hmac(key, data) {
  let k = typeof key === 'string' ? utf8.encode(key) : key;
  if (k.length > 64) k = sha256(k);
  const inner = new Uint8Array(64 + data.length);
  const outer = new Uint8Array(96);
  for (let i = 0; i < 64; i++) {
    inner[i] = (k[i] || 0) ^ 0x36;
    outer[i] = (k[i] || 0) ^ 0x5c;
  }
  inner.set(data, 64);
  outer.set(sha256(inner), 64);
  return sha256(outer);
}

const modules = {
  'node:http': {
    createServer(handler) {
      self.__handleApi = handler;
      return { listen() {} };
    },
  },
  'node:fs': { readFileSync: () => SEED },
  'node:path': { join: (...parts) => parts.join('/') },
  'node:crypto': {
    randomUUID: () => self.crypto.randomUUID(),
    createHash: () => {
      const chunks = [];
      return {
        update(data) { chunks.push(Buffer.from(data)); return this; },
        digest: (encoding) => digestOf(sha256(Buffer.concat(chunks)), encoding),
      };
    },
    createHmac: (_, key) => {
      const chunks = [];
      return {
        update(data) { chunks.push(Buffer.from(data)); return this; },
        digest: (encoding) => digestOf(hmac(key, Buffer.concat(chunks)), encoding),
      };
    },
    timingSafeEqual: (a, b) => a.length === b.length && a.every((v, i) => v === b[i]),
  },
};
const require = (name) => modules[name];
const process = { argv: ['node', 'mock-server.js'] };
const __dirname = '.';
`;

// ─────────────────────── service worker ───────────────────────

const worker = String.raw`'use strict';
/* Собрано tool/build-demo-api.js из api/mock-server.js. Не править вручную. */

const SEED = ${JSON.stringify(seed)};
const STATE_CACHE = 'service-desk-demo-api';
const STATE_KEY = 'state.json';

(function () {
${shims}

// ── api/mock-server.js без изменений ──
${server}
// ── конец api/mock-server.js ──

// Доступ к состоянию сервера для сохранения между остановками worker.
self.__apiState = {
  save: () => ({ db, refreshTokens: [...refreshTokens] }),
  load: (state) => {
    db = state.db;
    refreshTokens.clear();
    for (const token of state.refreshTokens) refreshTokens.add(token);
  },
};
})();

let restored = null;
function restore() {
  return restored ??= caches.open(STATE_CACHE)
    .then((cache) => cache.match(STATE_KEY))
    .then((response) => response && response.json())
    .then((state) => { if (state) self.__apiState.load(state); })
    .catch(() => {});
}

async function persist() {
  const cache = await caches.open(STATE_CACHE);
  await cache.put(STATE_KEY, new Response(JSON.stringify(self.__apiState.save())));
}

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname + 'api/')) {
    return;
  }
  event.respondWith(handle(event.request, url, scope));
});

async function handle(request, url, scope) {
  await restore();
  const body = new Uint8Array(await request.arrayBuffer());
  const headers = { host: url.host };
  request.headers.forEach((value, key) => { headers[key.toLowerCase()] = value; });

  const listeners = {};
  const req = {
    method: request.method,
    url: '/' + url.pathname.slice(scope.pathname.length) + url.search,
    headers,
    on(event, fn) {
      // Тело уже прочитано целиком: события отдаются в следующем такте,
      // в том же порядке, в каком их ждёт readBody.
      if (event === 'data' && body.length) setTimeout(() => fn(body));
      if (event === 'end') setTimeout(fn);
    },
  };

  let finish;
  const done = new Promise((resolve) => { finish = resolve; });
  const res = {
    statusCode: 200,
    headersSent: false,
    headers: {},
    setHeader(key, value) { this.headers[key] = String(value); },
    writeHead(status, extra = {}) {
      this.statusCode = status;
      for (const [key, value] of Object.entries(extra)) this.headers[key] = String(value);
      this.headersSent = true;
    },
    end(chunk) {
      this.headersSent = true;
      (listeners.finish || []).forEach((fn) => fn());
      finish(chunk);
    },
    on(event, fn) { (listeners[event] ||= []).push(fn); },
  };

  self.__handleApi(req, res);
  const chunk = await done;
  if (request.method !== 'GET') await persist();

  delete res.headers['Content-Length'];
  return new Response(res.statusCode === 204 ? null : chunk, {
    status: res.statusCode,
    headers: res.headers,
  });
}
`;

const loader = `'use strict';
// Регистрация учебного сервера (api-sw.js) до запуска приложения: первые
// запросы Flutter должны уже идти через service worker. Если браузер
// service worker не поддерживает, приложение всё равно запускается и
// показывает, что связи с сервером нет.
(async () => {
  try {
    if ('serviceWorker' in navigator) {
      await navigator.serviceWorker.register('api-sw.js');
      if (!navigator.serviceWorker.controller) {
        await new Promise((resolve) => {
          navigator.serviceWorker.addEventListener('controllerchange', resolve, { once: true });
          setTimeout(resolve, 5000);
        });
      }
    }
  } catch (e) {
    console.warn('Учебный сервер в браузере не запущен:', e);
  }
  const script = document.createElement('script');
  script.src = 'flutter_bootstrap.js';
  script.async = true;
  document.body.appendChild(script);
})();
`;

fs.writeFileSync(path.join(out, 'api-sw.js'), worker);
fs.writeFileSync(path.join(out, 'demo-api.js'), loader);

const indexPath = path.join(out, 'index.html');
const index = fs.readFileSync(indexPath, 'utf8');
const tag = '<script src="flutter_bootstrap.js" async></script>';
if (!index.includes(tag)) throw new Error('в index.html не найдено подключение flutter_bootstrap.js');
fs.writeFileSync(indexPath, index.replace(tag, '<script src="demo-api.js"></script>'));

console.log('учебный сервер встроен в', out);
