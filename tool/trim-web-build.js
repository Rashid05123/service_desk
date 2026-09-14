#!/usr/bin/env node
/**
 * Удаление из build/web файлов, которые браузер никогда не загружает.
 *
 *   node tool/trim-web-build.js build/web
 *
 * Файлы *.symbols — таблицы имён движка отрисовки для расшифровки
 * стека при падении. Приложение их не запрашивает, а в сборке они
 * занимают около восьми мегабайт из сорока.
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(process.argv[2] || 'build/web');
let removed = 0;
let bytes = 0;

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(file);
    } else if (entry.name.endsWith('.symbols')) {
      bytes += fs.statSync(file).size;
      fs.rmSync(file);
      removed++;
    }
  }
}

walk(root);
console.log(
  `удалено файлов: ${removed}, освобождено ${(bytes / 1048576).toFixed(1)} МБ`,
);
