'use strict';

/**
 * Снимки опубликованной сборки для отчёта по ПР6: прямая ссылка на
 * внутренний экран GitHub Pages, тот же экран с данными учебного сервера
 * на этой машине и страница прогона автосборки.
 *
 *   node api/mock-server.js --port 8080
 *   node tool/shots.js "папка для снимков" tool/shot-script-pr6-pages.js
 */

const SITE = 'https://rashid05123.github.io/service_desk';
const RUN = process.env.RUN_URL;

module.exports = async function script(page, { sleep }) {
  await page.send('Emulation.setEmulatedMedia', {
    features: [{ name: 'prefers-color-scheme', value: 'light' }],
  });
  await page.resize(1280, 800, false);

  // Прямая ссылка на карточку заявки в чистом профиле: Pages отвечает
  // копией index.html, приложение разбирает адрес и отправляет на вход
  // с запоминанием, куда человек шёл.
  await page.open(`${SITE}/tickets/5`, 9000);
  await page.shot('31-pages-deep-link');

  // Та же ссылка после входа. Страница открыта по HTTPS, сервер — на этой
  // машине по HTTP: смешанным содержимым браузер это не считает, но
  // обращение сайта из интернета к localhost разрешает только с согласия
  // пользователя. Обычный Chrome спрашивает его окном; в браузере без окна
  // спросить некого, и то же согласие выдаётся через протокол отладки.
  try {
    await page.send('Browser.grantPermissions', {
      origin: 'https://rashid05123.github.io',
      permissions: ['localNetworkAccess'],
    });
    console.log('разрешение на доступ к локальной сети выдано');
  } catch (e) {
    console.log('разрешение выдать не удалось:', e.message);
  }
  const auth = await fetch('http://localhost:8080/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'abramov', password: 'abramov123' }),
  }).then((r) => r.json());
  const user = {
    ...auth.user,
    employeeId: auth.user.employee?.id ?? null,
    requesterId: null,
  };
  const now = new Date().toISOString();
  const put = (key, value) =>
    `localStorage.setItem('flutter.${key}', ${JSON.stringify(JSON.stringify(value))});`;
  await page.eval(
    put('auth_access_token', auth.accessToken) +
      put('auth_refresh_token', auth.refreshToken) +
      put('auth_user', JSON.stringify(user)) +
      put('auth_session_started_at', now) +
      put('auth_last_activity_at', now),
  );
  await page.open(`${SITE}/tickets/5`, 9000);
  await page.shot('32-pages-ticket');
  console.log('адрес после перехода:', await page.eval('location.href'));

  if (RUN) {
    await page.resize(1280, 900, false);
    await page.open(RUN, 8000);
    await page.shot('33-actions-run');
  }

  // Управление с клавиатуры: поле логина получает фокус само, три нажатия
  // Tab проводят через пароль и кнопку показа пароля к кнопке «Войти».
  if (process.env.APP_URL) {
    await page.resize(1280, 800, false);
    await page.open(`${process.env.APP_URL}/login`, 3000);
    await page.eval('localStorage.clear()');
    await page.open(`${process.env.APP_URL}/login`, 6000);
    for (let i = 0; i < 3; i++) await page.key('Tab', 'Tab', 9, 700);
    await page.shot('34-keyboard-focus');
  }
  await sleep(100);
};
