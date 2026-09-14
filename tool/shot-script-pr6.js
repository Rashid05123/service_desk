'use strict';

const { execSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

/**
 * Сценарий снятия экранов для отчёта по ПР6: основные экраны на ширинах
 * 360, 768, 1280 и 1920, смена ширины без перезагрузки страницы,
 * заглушка начальной загрузки, пропажа и возвращение связи с сервером
 * и ответ 404 простого файлового сервера на внутренний адрес.
 *
 * Ширина меняется на уже открытой странице, как если бы окно тянули
 * мышью: раскладка обязана перестроиться без перезагрузки. Ошибки
 * консоли и необработанные исключения собираются за весь сценарий и
 * печатаются в конце отдельно по этапам.
 *
 * Учебный сервер сценарий перезапускает сам. Собранное приложение должно
 * раздаваться заранее:
 *
 *   node tool/serve-web.js --port 5555
 *   node tool/shots.js "папка для снимков" tool/shot-script-pr6.js
 *
 * Продолжить с раздела после сбоя: FROM=dialog node tool/shots.js …
 */

const SERVER = path.join(__dirname, '..', 'api', 'mock-server.js');
const WEB = path.join(__dirname, '..', 'build', 'web');
const LOG =
  process.env.SERVER_LOG || path.join(os.tmpdir(), 'sd-pr6-server.log');
const API_PORT = process.env.API_PORT || '8080';

/** Высота окна для каждой ширины: телефон, планшет, ноутбук, монитор. */
const HEIGHT = { 360: 780, 768: 1024, 1280: 800, 1920: 1080 };

const SECTIONS = [
  'login', 'home', 'tickets', 'ticket', 'queue', 'dialog',
  'requester', 'admin', 'splash', 'offline', 'http-server',
];

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
  spawn(process.execPath, [SERVER, '--port', API_PORT], {
    detached: true,
    stdio: ['ignore', out, out],
  }).unref();
}

module.exports = async function script(page, { sleep, APP }) {
  // ── журнал ошибок консоли ────────────────────────────────────────────
  const problems = [];
  const marks = {};
  page.ws.addEventListener('message', (event) => {
    const m = JSON.parse(event.data);
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      problems.push(`исключение: ${d.exception?.description ?? d.text}`);
    } else if (
      m.method === 'Runtime.consoleAPICalled' &&
      ['error', 'warning', 'assert'].includes(m.params.type)
    ) {
      problems.push(
        `console.${m.params.type}: ` +
          m.params.args.map((a) => a.value ?? a.description).join(' '),
      );
    } else if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') {
      problems.push(`браузер: ${m.params.entry.text} ${m.params.entry.url ?? ''}`);
    }
  });
  await page.send('Runtime.enable');
  await page.send('Log.enable');

  // Светлая тема независимо от настроек системы: снимки идут в отчёт,
  // который печатается на белой бумаге.
  await page.send('Emulation.setEmulatedMedia', {
    features: [{ name: 'prefers-color-scheme', value: 'light' }],
  });

  const from = SECTIONS.indexOf(process.env.FROM || 'login');
  const run = (name) => SECTIONS.indexOf(name) >= from;

  const at = async (width, wait = 1500) => {
    await page.resize(width, HEIGHT[width], false);
    await sleep(wait);
  };

  /** Сессия по ответу сервера на вход — без набора пароля. */
  const sessionFromApi = async (username, password) => {
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
    const put = (key, value) =>
      `localStorage.setItem('flutter.${key}', ${JSON.stringify(JSON.stringify(value))});`;
    await page.open(APP + '/login', 3000);
    await page.eval(
      'localStorage.clear();' +
        put('auth_access_token', auth.accessToken) +
        put('auth_refresh_token', auth.refreshToken) +
        put('auth_user', JSON.stringify(user)) +
        put('auth_session_started_at', now) +
        put('auth_last_activity_at', now),
    );
  };

  /** Ожидание элемента с подписью в дереве доступности. */
  const waitFor = async (text, timeout = 15000) => {
    const until = Date.now() + timeout;
    while (Date.now() < until) {
      if ((await page.locate(text)).length > 0) return true;
      await sleep(250);
    }
    return false;
  };

  stopServer();
  await sleep(800);
  startServer();
  await sleep(1500);

  // ── вход ─────────────────────────────────────────────────────────────
  if (run('login')) {
    await at(360);
    await page.open(APP + '/login', 3000);
    await page.eval('localStorage.clear()');
    await page.open(APP + '/login', 5000);
    await page.shot('01-login-360');
    await at(1280);
    await page.shot('02-login-1280');
  }

  // ── главная: четыре ширины на одной странице ─────────────────────────
  if (run('home')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(360);
    await page.open(APP + '/', 6000);
    await page.shot('03-home-360');
    await at(768);
    await page.shot('04-home-768');
    await at(1280);
    await page.shot('05-home-1280');
    await at(1920);
    await page.shot('06-home-1920');
  }

  // ── журнал заявок: обратный порядок ширин, тоже без перезагрузки ─────
  if (run('tickets')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(1920);
    await page.open(APP + '/tickets', 6000);
    await page.shot('07-tickets-1920');
    await at(1280);
    await page.shot('08-tickets-1280');
    await at(768);
    await page.shot('09-tickets-768');
    await at(360);
    await page.shot('10-tickets-360');

    await page.enableSemantics();
    await page.clickText('Ещё', { exact: true, wait: 1500 });
    await page.shot('11-more-360');

    await page.open(APP + '/tickets', 5000);
    await page.enableSemantics();
    await page.clickText('Фильтры', { exact: true, wait: 1500 });
    await page.shot('12-filters-360');
  }

  // ── карточка и форма заявки ──────────────────────────────────────────
  if (run('ticket')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(360);
    await page.open(APP + '/tickets/5', 5000);
    await page.shot('13-ticket-360');
    await at(1280);
    await page.shot('14-ticket-1280');

    await page.open(APP + '/tickets/5/edit', 6000);
    await page.shot('15-ticket-form-1280');
    await at(360);
    await page.shot('16-ticket-form-360');
  }

  // ── очередь специалиста ──────────────────────────────────────────────
  if (run('queue')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(360);
    await page.open(APP + '/queue', 5000);
    await page.shot('17-queue-360');
    await at(1280);
    await page.shot('18-queue-1280');
  }

  // ── диалог на мониторе 1920 не растягивается ─────────────────────────
  if (run('dialog')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(1920);
    await page.open(APP + '/tickets', 6000);
    await page.enableSemantics();
    await page.clickText('Удалить (логически)', { wait: 1500 });
    await page.shot('19-dialog-1920');
  }

  // ── заявитель ────────────────────────────────────────────────────────
  if (run('requester')) {
    await sessionFromApi('grigorev', 'grigorev123');
    await at(360);
    await page.open(APP + '/my', 6000);
    await page.shot('20-my-360');
    await at(1280);
    await page.shot('21-my-1280');
  }

  // ── администратор ────────────────────────────────────────────────────
  if (run('admin')) {
    await sessionFromApi('admin', 'admin123');
    await at(360);
    await page.open(APP + '/admin/stats', 6000);
    await page.shot('22-stats-360');
    await at(1280);
    await page.shot('23-stats-1280');
    await page.open(APP + '/admin/users', 6000);
    await page.shot('24-users-1280');
    await at(360);
    await page.shot('25-users-360');
  }

  marks.adaptive = problems.length;

  // ── заглушка начальной загрузки ──────────────────────────────────────
  // Сеть замедлена до 4 Мбит/с, кэш выключен: заглушка видна, пока
  // скачивается main.dart.js.
  if (run('splash')) {
    await at(1280);
    await page.send('Network.enable');
    await page.send('Network.setCacheDisabled', { cacheDisabled: true });
    await page.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: 150,
      downloadThroughput: 500000,
      uploadThroughput: 500000,
    });
    await page.send('Page.navigate', { url: APP + '/login' });
    await sleep(1500);
    await page.shot('26-splash');
    await sleep(20000);
    await page.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: 0,
      downloadThroughput: -1,
      uploadThroughput: -1,
    });
    await page.send('Network.setCacheDisabled', { cacheDisabled: false });
  }

  marks.splash = problems.length;

  // ── пропажа и возвращение связи ──────────────────────────────────────
  if (run('offline')) {
    await sessionFromApi('abramov', 'abramov123');
    await at(1280);
    await page.open(APP + '/tickets', 6000);
    marks.beforeOffline = problems.length;
    stopServer();
    await sleep(1000);
    await page.enableSemantics();
    await page.clickText('Обновить', { wait: 500 });
    if (!(await waitFor('Нет связи с сервером'))) {
      throw new Error('сообщение о пропаже связи не появилось');
    }
    await sleep(800);
    await page.shot('27-offline');

    console.log(
      'полоса о пропаже связи в дереве доступности:',
      (await page.locate('Данные не загружаются')).length > 0,
    );

    // После запуска сервера страницу никто не трогает. Ждём, когда список
    // появится сам: сообщение о восстановлении видно три секунды, и снимок
    // делается сразу, пока оно на экране.
    startServer();
    if (!(await waitFor('SD-000025', 20000))) {
      throw new Error('список не загрузился без перезагрузки');
    }
    await page.shot('28-restored');
    console.log(
      'сообщение о восстановлении в дереве доступности:',
      (await page.locate('Связь с сервером восстановлена')).length > 0,
    );
  }

  // ── простой файловый сервер и внутренний адрес ───────────────────────
  if (run('http-server')) {
    const py = spawn('python', ['-m', 'http.server', '8000'], {
      cwd: WEB,
      stdio: 'ignore',
    });
    await sleep(2000);
    await at(1280);
    await page.open('http://localhost:8000/', 6000);
    await page.shot('29-http-server-root');
    await page.open('http://localhost:8000/tickets', 2500);
    await page.shot('30-http-server-404');
    py.kill();
  }

  const offlineStart = marks.beforeOffline ?? marks.splash;
  console.log('\nошибки консоли при смене ширины и переходах:');
  console.log(problems.slice(0, marks.adaptive).join('\n') || 'нет');
  console.log('\nошибки консоли при загрузке с медленной сетью:');
  console.log(problems.slice(marks.adaptive, marks.splash).join('\n') || 'нет');
  console.log('\nошибки консоли при выключенном сервере и после:');
  console.log(problems.slice(offlineStart).join('\n') || 'нет');
};
