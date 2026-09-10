'use strict';

const { execSync, spawn } = require('node:child_process');
const path = require('node:path');

/**
 * Сценарий снятия экранов для отчёта по ПР4.
 *
 * Отделён от драйвера (`shots.js`): здесь только последовательность
 * действий и координаты. Flutter рисует в canvas, поэтому щелчки
 * задаются точками; размер окна в драйвере зафиксирован, и точки
 * от запуска к запуску не съезжают.
 *
 * Перед запуском должны работать учебный сервер и раздача build/web:
 *
 *   node api/mock-server.js --port 8080
 *   node tool/serve-web.js --port 5555
 *   node tool/shots.js "путь к папке со снимками"
 */

function stopServer() {
  execSync(
    'powershell -Command "Get-CimInstance Win32_Process -Filter \\"Name=\'node.exe\'\\" ' +
      "| Where-Object { $_.CommandLine -like '*mock-server*' } " +
      '| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"',
    { stdio: 'ignore' },
  );
}

function startServer() {
  spawn(
    process.execPath,
    [
      path.join(__dirname, '..', 'api', 'mock-server.js'),
      '--port',
      '8080',
      '--origin',
      'http://localhost:5555,http://127.0.0.1:5555',
    ],
    { detached: true, stdio: 'ignore' },
  ).unref();
}

module.exports = async function script(page, { sleep, APP }) {
  // ── список с сервера ────────────────────────────────────────────────
  await page.open(APP + '/tickets', 5000);
  await page.shot('01-tickets-from-api');

  // Переход на следующую страницу: выборку делает сервер, клиент держит
  // только текущую страницу — уходит новый запрос.
  await page.click(1368, 876, 1500);
  await page.shot('02-page-two');

  // ── поиск на сервере ────────────────────────────────────────────────
  await page.open(APP + '/tickets', 4000);
  await page.click(700, 88, 300);
  await page.type('принтер', 1800);
  await page.shot('03-search-on-server');

  // ── пустой результат ────────────────────────────────────────────────
  await page.open(APP + '/tickets?search=квартальный%20отчёт', 4000);
  await page.shot('04-empty-result');

  // ── форма создания: номер выдал сервер ──────────────────────────────
  await page.open(APP + '/tickets/new', 5000);
  await page.shot('05-form-new');

  // ── проверка сервера с кодом 422 ────────────────────────────────────
  await page.open(APP + '/tickets/2/edit', 5000);
  await page.click(545, 96, 300);
  await page.selectAll();
  await page.type('SD-000001', 300);
  await page.click(1126, 860, 2500); // «Сохранить»
  await page.shot('06-validation-422');

  // ── отказ по ссылкам с кодом 409 ────────────────────────────────────
  await page.open(APP + '/departments', 5000);
  await page.shot('07-departments-counters');
  await page.click(1332, 580, 800); // мусорка «Отдела технической поддержки»
  await page.shot('08-delete-confirm');
  await page.click(1148, 496, 2000); // «Удалить»
  await page.shot('09-conflict-409');

  // ── карточки со связями: прямой переход по адресу ───────────────────
  await page.open(APP + '/tickets/1', 5000);
  await page.shot('10-ticket-detail');
  await page.open(APP + '/requesters/1', 5000);
  await page.shot('18-requester-detail');

  // ── учебные переключатели ───────────────────────────────────────────
  // Каждый пункт меню закрывает меню, поэтому перед вторым
  // переключателем оно открывается заново.
  await page.open(APP + '/tickets', 4500);
  await page.click(1412, 28, 700);
  await page.shot('11-fault-toggles');

  await page.click(1336, 116, 800); // «Медленный ответ»
  await page.click(1372, 28, 400); // обновить
  await page.shot('12-loading');
  await sleep(3000);

  await page.click(1412, 28, 700);
  await page.click(1336, 116, 700); // снять «Медленный ответ»
  await page.click(1412, 28, 700);
  await page.click(1320, 76, 700); // «Сбой сервера»
  await page.click(1372, 28, 4000); // обновить: три попытки с паузами
  await page.shot('13-error-500');

  // ── узкое окно ──────────────────────────────────────────────────────
  await page.resize(390, 844, true);
  await page.open(APP + '/tickets', 5000);
  await page.shot('14-mobile-list');
  await page.open(APP + '/tickets/2/edit', 5000);
  await page.shot('15-mobile-form');
  await page.resize(1440, 900);

  // ── сервер остановлен ───────────────────────────────────────────────
  // Сервер гасится уже после того, как приложение отрисовалось: если
  // открывать страницу при выключенном сервере, в безголовом Chrome
  // первый кадр не успевает попасть в снимок и получается белый лист.
  await page.open(APP + '/tickets', 6000);
  stopServer();
  await sleep(1000);
  await page.click(1372, 28, 14000);
  await page.shot('16-server-down');
  startServer();
  await sleep(1500);
};
