'use strict';

/**
 * Проверка всех экранов на переполнение при ширинах 360, 768, 1280 и 1920.
 *
 * В релизной сборке Flutter об ошибках раскладки молчит: полоса
 * переполнения не рисуется, а сообщение «A RenderFlex overflowed» в консоль
 * не пишется. Поэтому проверка идёт на отладочной сборке:
 *
 *   flutter run -d web-server --web-port=5555 --web-hostname=127.0.0.1 \
 *     --dart-define-from-file=config/local.json
 *   node api/mock-server.js --port 8080
 *   APP_URL=http://127.0.0.1:5555 node tool/shots.js папка tool/layout-check-pr6.js
 *
 * Отладочная сборка грузится долго, поэтому страница открывается один раз
 * на роль, а экраны сменяются переходом внутри приложения (history.pushState
 * и событие popstate) — так же, как кнопками «назад» и «вперёд».
 */

const WIDTHS = [
  [360, 780],
  [768, 1024],
  [1280, 800],
  [1920, 1080],
];

const LISTS = ['/tickets', '/requesters', '/employees', '/departments', '/categories'];

const ROLES = [
  {
    username: 'admin',
    password: 'admin123',
    routes: [
      '/', '/tickets', '/tickets/5', '/requesters', '/requesters/1',
      '/employees', '/employees/1', '/employees/1/edit', '/employees/new',
      '/departments', '/departments/1', '/categories', '/categories/1',
      '/admin/users', '/admin/stats', '/forbidden?from=%2Fqueue', '/no-such-page',
    ],
  },
  {
    username: 'abramov',
    password: 'abramov123',
    routes: [
      '/', '/queue', '/tickets/5/edit', '/tickets/new', '/requesters/1/edit',
      '/requesters/new', '/departments/1/edit', '/departments/new',
      '/categories/1/edit', '/categories/new',
    ],
  },
  {
    username: 'grigorev',
    password: 'grigorev123',
    routes: ['/', '/my', '/my/new', '/categories', '/categories/1'],
  },
  { username: null, routes: ['/login', '/register'] },
];

module.exports = async function script(page, { sleep, APP }) {
  let context = 'загрузка';
  const problems = [];
  let checked = 0;

  page.ws.addEventListener('message', (event) => {
    const m = JSON.parse(event.data);
    let text = null;
    if (m.method === 'Runtime.consoleAPICalled') {
      text = m.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
    } else if (m.method === 'Runtime.exceptionThrown') {
      text = m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text;
    }
    if (text && /overflowed|EXCEPTION CAUGHT|Another exception was thrown|Unhandled|Uncaught/.test(text)) {
      problems.push(`${context}: ${text.split('\n').slice(0, 3).join(' | ')}`);
    }
  });
  await page.send('Runtime.enable');

  const go = async (route) => {
    await page.eval(`(() => {
      history.pushState(null, '', ${JSON.stringify(route)});
      window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
    })()`);
    await sleep(2500);
  };

  const signIn = async (username, password) => {
    await page.open(APP + '/login', 4000);
    await page.eval('localStorage.clear()');
    if (!username) return;
    const auth = await fetch('http://localhost:8080/api/auth/login', {
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
    await page.eval(
      put('auth_access_token', auth.accessToken) +
        put('auth_refresh_token', auth.refreshToken) +
        put('auth_user', JSON.stringify(user)) +
        put('auth_session_started_at', now) +
        put('auth_last_activity_at', now),
    );
  };

  for (const role of ROLES) {
    await signIn(role.username, role.password);
    await page.resize(1280, 800, false);
    // Отладочная сборка: сотни модулей, первый кадр — десятки секунд.
    await page.open(APP + '/', 45000);

    for (const route of role.routes) {
      await go(route);
      const withFilters = LISTS.includes(route);
      for (const pass of withFilters ? ['', ' с панелью фильтров'] : ['']) {
        if (pass) {
          await page.enableSemantics();
          await page.clickText('Фильтры', { exact: true, wait: 1500 });
        }
        for (const [width, height] of WIDTHS) {
          context = `${role.username ?? 'без входа'} ${route} ${width}${pass}`;
          await page.resize(width, height, false);
          await sleep(1500);
          checked++;
        }
      }
    }
  }

  console.log(`\nпроверено сочетаний «экран × ширина»: ${checked}`);
  console.log('ошибки раскладки и исключения:');
  console.log(problems.length ? [...new Set(problems)].join('\n') : 'нет');
};
