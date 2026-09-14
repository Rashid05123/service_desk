'use strict';

const { execSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

/**
 * Снимки панели разработчика для отчёта по ПР5: подмена роли
 * в localStorage и ответ 403, обновление токена и выход без
 * зацикливания при отказе в обновлении.
 *
 * Сервер сценарий перезапускает сам с параметром --ttl 60, журнал сервера
 * пишется в файл: строки журнала за время каждого опыта сохраняются рядом
 * как доказательство, сколько запросов ушло на самом деле.
 *
 *   node tool/serve-web.js --port 5555
 *   node tool/devtools-shots.js "папка для снимков" tool/devtools-script-pr5.js
 */

const SERVER = path.join(__dirname, '..', 'api', 'mock-server.js');
const LOG =
  process.env.SERVER_LOG || path.join(os.tmpdir(), 'sd-pr5-devtools.log');
const EVIDENCE = process.env.EVIDENCE || os.tmpdir();

// Порт сервера сценария. Останавливается только сервер на этом порту:
// учебный сервер, запущенный рядом вручную, сценарий не трогает.
const API_PORT = process.env.API_PORT || '8080';
const APP_ORIGIN = new URL(process.env.APP_URL || 'http://localhost:5555').origin;

function stopServer() {
  execSync(
    'powershell -Command "Get-CimInstance Win32_Process -Filter \\"Name=\'node.exe\'\\" ' +
      `| Where-Object { $_.CommandLine -like '*mock-server*--port ${API_PORT}*' } ` +
      '| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"',
    { stdio: 'ignore' },
  );
}

function startServer() {
  const out = fs.openSync(LOG, 'a');
  spawn(process.execPath, [SERVER, '--port', API_PORT, '--origin', APP_ORIGIN, '--ttl', '60'], {
    detached: true,
    stdio: ['ignore', out, out],
  }).unref();
}

/** Строки журнала сервера, дописанные после отметки. */
const logSize = () => (fs.existsSync(LOG) ? fs.statSync(LOG).size : 0);
function logSince(offset) {
  const text = fs.readFileSync(LOG).subarray(offset).toString('utf8');
  return text
    .split('\n')
    .filter((line) => /^(GET|POST|PUT|DELETE) /.test(line))
    .join('\n');
}

/** Перетаскивание разделителя между трансляцией страницы и панелью. */
async function drag(devtools, from, to, sleep) {
  const send = (type, x, buttons) =>
    devtools.send('Input.dispatchMouseEvent', {
      type,
      x,
      y: 500,
      button: 'left',
      buttons,
      clickCount: type === 'mouseMoved' ? 0 : 1,
    });
  await send('mouseMoved', from, 0);
  await send('mousePressed', from, 1);
  await sleep(200);
  await send('mouseMoved', Math.round((from + to) / 2), 1);
  await sleep(200);
  await send('mouseMoved', to, 1);
  await sleep(200);
  await send('mouseReleased', to, 0);
  await sleep(1000);
}

async function insertText(tab, text, sleep, wait = 300) {
  await tab.send('Input.insertText', { text });
  await sleep(wait);
}

async function pressEnter(tab, sleep, wait = 800) {
  await tab.send('Input.dispatchKeyEvent', {
    type: 'keyDown', key: 'Enter', code: 'Enter',
    windowsVirtualKeyCode: 13, text: '\r',
  });
  await tab.send('Input.dispatchKeyEvent', {
    type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13,
  });
  await sleep(wait);
}

async function pressEscape(tab, sleep, wait = 1200) {
  for (const type of ['keyDown', 'keyUp']) {
    await tab.send('Input.dispatchKeyEvent', {
      type, key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27,
    });
  }
  await sleep(wait);
}

const CLEAR = [195, 40]; // «очистить» в панели Network
const TAB_CONSOLE = [317, 14]; // вкладка Console в полосе панелей
const TAB_NETWORK = [446, 14]; // вкладка Network

/** Область снимка без полосы с трансляцией страницы. */
const PANEL = { x: 150, y: 0, width: 1432, height: 905 };

// Точки полосы навигации приложения при окне 1440×900.
const railItem = (index) => [44, 96 + index * 64];

module.exports = async function script({ app, devtools, sleep, APP }) {
  stopServer();
  await sleep(800);
  startServer();
  await sleep(1500);

  await app.send('Emulation.setDeviceMetricsOverride', {
    width: 1440, height: 900, deviceScaleFactor: 1, mobile: false,
  });

  await devtools.front();
  await devtools.click(1391, 66, 1500); // закрыть сообщение о языке
  await drag(devtools, 1283, 8, sleep); // свернуть трансляцию страницы
  await devtools.click(1013, 67, 400); // тип запросов: все
  await devtools.click(400, 67, 400); // поле отбора
  await insertText(devtools, 'api', sleep, 600);

  /**
   * Сессия по ответу сервера на вход. Опыты этого сценария — про
   * хранилище, токены и ответы сервера, а не про форму входа, а набор
   * в поля headless-браузером после множества действий ненадёжен.
   */
  const signIn = async (username, password) => {
    const auth = await fetch(`http://localhost:${API_PORT}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    }).then((r) => r.json());
    const user = {
      ...auth.user,
      employeeId: auth.user.employee?.id ?? null,
      requesterId: auth.user.requester?.id ?? null,
    };
    const now = new Date().toISOString();
    // shared_preferences на web хранит значение в JSON с префиксом flutter.
    const put = (key, value) =>
      `localStorage.setItem('flutter.${key}', ${JSON.stringify(JSON.stringify(value))});`;
    await app.front();
    await app.open(APP + '/login', 3000);
    await app.send('Runtime.evaluate', {
      expression:
        'localStorage.clear();' +
        put('auth_access_token', auth.accessToken) +
        put('auth_refresh_token', auth.refreshToken) +
        put('auth_user', JSON.stringify(user)) +
        put('auth_session_started_at', now) +
        put('auth_last_activity_at', now),
    });
    await app.open(APP + '/', 6000);
  };

  // Переменная ONLY=noloop оставляет только последний опыт.
  const all = process.env.ONLY !== 'noloop';

  // ── подмена роли в localStorage ─────────────────────────────────────
  if (all) {
  await signIn('grigorev', 'grigorev123');

  // Консоль открывается вкладкой: фокус переходит в строку ввода консоли,
  // и команда выполняется в контексте страницы приложения.
  await devtools.front();
  await devtools.click(...TAB_CONSOLE, 1500);
  await insertText(
    devtools,
    "localStorage['flutter.auth_user'] = " +
      "localStorage['flutter.auth_user'].replace('requester', 'admin')",
    sleep,
  );
  await pressEnter(devtools, sleep, 1200);
  await devtools.shot('22-devtools-spoof', PANEL);
  await devtools.click(...TAB_NETWORK, 1200);

  await app.front();
  await app.open(APP + '/', 7000);
  await app.shot('23-spoofed-home');

  await devtools.click(...CLEAR, 600);
  await app.front();
  await app.click(...railItem(6), 4000); // «Пользователи»
  await app.shot('24-spoofed-403');
  await devtools.shot('25-network-403', PANEL);

  // ── обновление токена ───────────────────────────────────────────────
  await signIn('abramov', 'abramov123');
  await devtools.click(...CLEAR, 600);
  await sleep(65000); // токен доступа живёт 60 секунд
  const mark = logSize();
  await app.front();
  await app.click(...railItem(2), 5000); // «Заявки»
  fs.writeFileSync(path.join(EVIDENCE, 'refresh.log'), logSince(mark));
  await devtools.shot('26-network-refresh', PANEL);
  }

  // ── отказ в обновлении ──────────────────────────────────────────────
  // Опыт самостоятельный: вход, перезапуск сервера, ожидание. После
  // перезапуска выданные токены обновления недействительны, а токен
  // доступа с тем же ключом подписи доживает свой срок. Запросы
  // вызываются перезагрузкой страницы: пользователь вернулся к вкладке
  // и обновил её.
  await signIn('abramov', 'abramov123');
  stopServer();
  await sleep(800);
  startServer();
  await sleep(1500);
  await devtools.front();
  await devtools.click(...CLEAR, 600);
  await sleep(65000);
  const mark = logSize();
  await app.front();
  await app.open(APP + '/tickets', 6000);
  fs.writeFileSync(path.join(EVIDENCE, 'noloop.log'), logSince(mark));
  await devtools.shot('27-network-no-loop', PANEL);
  await app.shot('28-session-expired');
};
