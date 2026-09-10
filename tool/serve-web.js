#!/usr/bin/env node
/**
 * Раздача собранного приложения из build/web.
 *
 * Адреса приложения не имеют решётки (`usePathUrlStrategy`), поэтому
 * на неизвестный путь отдаётся index.html: иначе прямой переход
 * на /tickets/12 вернул бы 404 ещё до запуска приложения.
 *
 *   node tool/serve-web.js --port 5555
 */

'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
const portIndex = args.indexOf('--port');
const PORT = Number(portIndex !== -1 ? args[portIndex + 1] : 5555);
const ROOT = path.join(__dirname, '..', 'build', 'web');

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.wasm': 'application/wasm',
  '.symbols': 'text/plain; charset=utf-8',
};

http
  .createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    let file = path.join(ROOT, decodeURIComponent(url.pathname));

    if (!file.startsWith(ROOT)) {
      res.writeHead(403);
      return res.end();
    }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      file = path.join(ROOT, 'index.html');
    }

    res.writeHead(200, {
      'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(file).pipe(res);
  })
  .listen(PORT, () => {
    console.log(`build/web раздаётся на http://localhost:${PORT}`);
  });
