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

function stopServer() {
  execSync(
    'powershell -Command "Get-CimInstance Win32_Process -Filter \\"Name=\'node.exe\'\\" ' +
      "| Where-Object { $_.CommandLine -like '*mock-server*' } " +
      '| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"',
    { stdio: 'ignore' },
  );
}

function startServer(extra = []) {
  const out = fs.openSync(LOG, 'a');
  spawn(process.execPath, [SERVER, '--port', '8080', ...extra], {
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
   * Вход под учётной записью учебного стенда: щелчок по её метке под
   * формой заполняет оба поля, затем «Войти». Набор текста в поля
   * headless-браузером ненадёжен — после перезагрузок страницы фокус
   * поля ввода не всегда переходит по щелчку.
   */
  const signIn = async (account, wait = 3500) => {
    await page.enableSemantics();
    await page.clickText(account, { wait: 600 });
    await page.clickText('Войти', { exact: true, wait });
    await page.enableSemantics();
  };

  const nav = async (label, wait = 3500) => {
    await page.clickText(label, { ...RAIL, wait });
    await page.enableSemantics();
  };

  // ── вход и ошибка входа ─────────────────────────────────────────────
  await fresh('/login');
  await page.shot('01-login');

  // Неверный пароль набирается в поля: логин — в поле с автофокусом до
  // включения дерева доступности, пароль — после.
  await page.type('grigorev', 300);
  await page.enableSemantics();
  await page.fill('Пароль', 'neverno-123');
  await page.clickText('Войти', { exact: true, wait: 1800 });
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
  await signIn('grigorev · заявитель');
  await page.shot('06-home-requester');

  await nav('Мои заявки');
  await page.shot('07-my-tickets');

  // Форма обращения заполняется щелчками по точкам, без дерева
  // доступности: многострочное поле через него фокус не получает, и текст
  // дописывался бы в поле темы. Страница открывается заново, дерево
  // доступности после перезагрузки выключено, сессия восстанавливается
  // из хранилища.
  await page.open(APP + '/my/new', 6000);
  await page.type('Не сканирует МФУ в кабинете 214', 300); // тема, автофокус
  await page.click(764, 284, 400); // описание
  await page.type('При сканировании на почту МФУ показывает ошибку отправки.');
  await page.click(545, 416, 1200); // категория
  await page.click(549, 464, 1200); // «Печать и расходные материалы»
  await page.shot('08-my-ticket-form');

  await page.click(1125, 500, 3500); // «Отправить»
  await page.enableSemantics();
  await page.shot('09-my-ticket-created');

  // Адрес чужого экрана, набранный вручную.
  await page.open(APP + '/admin/users', 5000);
  await page.enableSemantics();
  await page.shot('10-forbidden');

  // ── специалист поддержки ────────────────────────────────────────────
  await fresh('/login');
  await signIn('abramov · специалист');
  await page.shot('11-home-agent');

  await nav('Очередь');
  await page.shot('12-queue');

  await nav('Заявки');
  await page.shot('13-tickets-agent');

  // ── администратор ───────────────────────────────────────────────────
  await fresh('/login');
  await signIn('admin · администратор');
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
  await signIn('abramov · специалист', 5000);
  await page.shot('19-returned-to-card');

  // ── выход по неактивности ───────────────────────────────────────────
  await fresh('/login');
  await signIn('grigorev · заявитель');
  // Три минуты без единого действия: предупреждение за 30 секунд.
  await sleep(152000);
  await page.shot('20-session-warning');
  await sleep(32000);
  await page.shot('21-session-ended');
};
