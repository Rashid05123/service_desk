'use strict';

const { execSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

/**
 * Сценарий снятия экранов для отчёта по ПР5: вход и регистрация, главные
 * экраны трёх ролей, защита маршрутов, возврат после входа и сроки сессии.
 *
 * Элементы находятся по подписям в дереве доступности Flutter, а не по
 * координатам: у ролей разный набор разделов, и точки съезжали бы.
 *
 * Учебный сервер сценарий перезапускает сам, с коротким сроком жизни
 * токена. Раздача собранного приложения должна быть уже запущена:
 *
 *   node tool/serve-web.js --port 5555
 *   node tool/shots.js "папка для снимков" tool/shot-script-pr5.js
 */

const SERVER = path.join(__dirname, '..', 'api', 'mock-server.js');
const LOG =
  process.env.SERVER_LOG || path.join(os.tmpdir(), 'sd-pr5-server.log');

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

function startServer(extra = []) {
  const out = fs.openSync(LOG, 'a');
  spawn(process.execPath, [SERVER, '--port', API_PORT, '--origin', APP_ORIGIN, ...extra], {
    detached: true,
    stdio: ['ignore', out, out],
  }).unref();
}

/** Пункт боковой навигации: полоса у левого края окна. */
const RAIL = { within: (hit) => hit.x < 110 };

module.exports = async function script(page, { sleep, APP }) {
  stopServer();
  await sleep(800);
  startServer(['--ttl', '60']);
  await sleep(1500);

  /**
   * Чистый браузер: хранилище пусто, пользователь не вошёл.
   *
   * Дерево доступности здесь не включается. Первое поле формы получает
   * фокус сразу при построении и заводит свой элемент ввода; после
   * включения дерева ввод в этот элемент до поля уже не доходит. Поэтому
   * первое поле заполняется до включения, остальные — после.
   */
  const fresh = async (url, wait = 5000) => {
    await page.open(APP + '/login', 3000);
    await page.eval('localStorage.clear()');
    await page.open(APP + url, wait);
  };

  /**
   * Вход набором логина и пароля. Координаты полей берутся из дерева
   * доступности, затем страница загружается заново, и поля заполняются
   * без него: поле логина с автофокусом после включения дерева ввод
   * теряет. Щелчок по полю пароля в headless-браузере переводит фокус
   * не всегда, и пароль дописывается к логину, поэтому перед вводом
   * пароля проверяется, что активно именно поле пароля; при неудаче
   * попытка повторяется.
   */
  const signIn = async (username, password, wait = 3500, expectOk = true) => {
    const url = await page.eval('location.href');
    for (let attempt = 0; attempt < 6; attempt++) {
      await page.open(url, 4000);
      await page.enableSemantics();
      const [pass] = await page.locate('Пароль');
      await page.open(url, 5000);
      await page.type(username, 300);
      await page.click(pass.x, pass.y, 500);
      const onPassword = await page.eval(
        `document.activeElement?.type === 'password'`,
      );
      if (!onPassword) continue;
      await page.type(password, 300);
      await page.enableSemantics();
      await page.clickText('Войти', { exact: true, wait });
      await page.enableSemantics();
      if (!expectOk || (await page.locate('Выйти')).length > 0) return;
    }
    throw new Error(`не удалось войти под ${username}`);
  };

  const nav = async (label, wait = 3500) => {
    await page.clickText(label, { ...RAIL, wait });
    await page.enableSemantics();
  };

  /** Сессия по ответу сервера на вход — без экрана входа. */
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
    // shared_preferences на web хранит значение в JSON с префиксом flutter.
    const put = (key, value) =>
      `localStorage.setItem('flutter.${key}', ${JSON.stringify(JSON.stringify(value))});`;
    await page.open(APP + '/login', 3000);
    await page.eval(
      put('auth_access_token', auth.accessToken) +
        put('auth_refresh_token', auth.refreshToken) +
        put('auth_user', JSON.stringify(user)) +
        put('auth_session_started_at', now) +
        put('auth_last_activity_at', now),
    );
  };

  await sessionFromApi('grigorev', 'grigorev123');
  // ── форма обращения ─────────────────────────────────────────────────
  // Снимается первой, в чистой вкладке: после множества переходов
  // headless-браузер перестаёт переводить фокус щелчком в многострочное
  // поле. Экран формы от способа входа не зависит, поэтому сессия
  // кладётся в хранилище по ответу /auth/login напрямую. Поля
  // заполняются щелчками по точкам без дерева доступности; перед вводом
  // описания проверяется, что активно многострочное поле.
  const SUBJECT = 'Не сканирует МФУ в кабинете 214';
  const DESCRIPTION = 'При сканировании на почту МФУ показывает ошибку отправки.';
  for (let attempt = 0; ; attempt++) {
    if (attempt === 6) throw new Error('форма обращения не заполнилась');
    await page.open(APP + '/my/new', 6000);
    await page.type(SUBJECT, 300); // тема, автофокус
    await page.click(764, 284, 800); // описание
    // Фокус должен перейти в многострочное поле описания.
    const focused = await page.eval(
      `document.activeElement?.tagName === 'TEXTAREA'`,
    );
    if (!focused) continue;
    await page.type(DESCRIPTION, 400);
    await page.enableSemantics();
    break;
  }
  await page.clickText('Категория', { within: (h) => h.x > 300, wait: 1200 });
  await page.clickText('Печать и расходные материалы', { wait: 1200 });
  await page.shot('08-my-ticket-form');

  await page.clickText('Отправить', { exact: true, wait: 3500 });
  await page.enableSemantics();
  await page.shot('09-my-ticket-created');

  // ── вход и ошибка входа ─────────────────────────────────────────────
  await fresh('/login');
  await page.shot('01-login');

  await signIn('grigorev', 'neverno-123', 1800, false);
  await page.shot('02-login-error');

  // ── регистрация и проверка пароля по мере ввода ─────────────────────
  await fresh('/register');
  await page.type('Петров Пётр Ильич', 300);
  await page.enableSemantics();
  await page.fill('Логин', 'petrov.pi');
  await page.fill('Рабочая почта', 'petrov@corp.local');
  await page.fill('Пароль', 'secret7', 900);
  await page.shot('03-password-weak');

  await page.fill('Пароль', 'Secret-2026', 900);
  await page.fill('Повтор пароля', 'Secret-2026', 900);
  await page.shot('04-password-strong');

  await page.clickText('Зарегистрироваться', { exact: true, wait: 4000 });
  await page.enableSemantics();
  await page.shot('05-registered-home');

  // ── заявитель ───────────────────────────────────────────────────────
  await fresh('/login');
  await signIn('grigorev', 'grigorev123');
  await page.shot('06-home-requester');

  await nav('Мои заявки');
  await page.shot('07-my-tickets');


  // Адрес чужого экрана, набранный вручную.
  await page.open(APP + '/admin/users', 5000);
  await page.enableSemantics();
  await page.shot('10-forbidden');

  // ── специалист поддержки ────────────────────────────────────────────
  // Дальше сессия кладётся через API: после множества действий
  // headless-вкладка перестаёт переводить фокус щелчком между полями,
  // а экраны ролей от способа входа не зависят.
  await sessionFromApi('abramov', 'abramov123');
  await page.open(APP + '/', 6000);
  await page.enableSemantics();
  await page.shot('11-home-agent');

  await nav('Очередь');
  await page.shot('12-queue');

  await nav('Заявки');
  await page.shot('13-tickets-agent');

  // ── администратор ───────────────────────────────────────────────────
  await sessionFromApi('admin', 'admin123');
  await page.open(APP + '/', 6000);
  await page.enableSemantics();
  await page.shot('14-home-admin');

  await nav('Заявки');
  await page.shot('15-tickets-admin');

  await nav('Пользователи');
  await page.shot('16-users');

  await nav('Статистика');
  await page.shot('17-stats');

  // ── возврат на адрес, с которого отправили на вход ─────────────────
  await fresh('/tickets/5?search=');
  await page.shot('18-login-from');
  // Вход выполнен, пользователь снова на экране входа с тем же адресом
  // возврата: маршрутизатор отправляет его по адресу из from.
  await sessionFromApi('abramov', 'abramov123');
  await page.open(APP + '/login?from=' + encodeURIComponent('/tickets/5?search='), 6000);
  await page.shot('19-returned-to-card');

  // ── выход по неактивности ───────────────────────────────────────────
  await sessionFromApi('grigorev', 'grigorev123');
  await page.open(APP + '/', 6000);
  // Три минуты без единого действия: предупреждение за 30 секунд.
  await sleep(152000);
  await page.shot('20-session-warning');
  await sleep(32000);
  await page.shot('21-session-ended');
};
