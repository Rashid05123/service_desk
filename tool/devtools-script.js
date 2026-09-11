'use strict';

/**
 * Снимки вкладки Network панели разработчика.
 *
 * Панель открыта отдельной вкладкой и направлена на вкладку
 * с приложением, поэтому её видно на снимке целиком, а приложением
 * при этом можно управлять как обычно.
 */

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

async function typeInto(tab, text, sleep) {
  for (const ch of text) {
    await tab.send('Input.dispatchKeyEvent', { type: 'keyDown', text: ch });
    await tab.send('Input.dispatchKeyEvent', { type: 'keyUp' });
    await sleep(40);
  }
}

async function prepare({ app, devtools, sleep }) {
  // Приложение на том же размере окна, что и остальные снимки, —
  // координаты щелчков совпадают.
  await app.send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });

  await devtools.front();
  await devtools.click(1391, 66, 1500); // закрыть сообщение о языке
  await drag(devtools, 1283, 8, sleep); // свернуть трансляцию страницы

  // Отбор по адресу надёжнее набора кнопок: их положение зависит
  // от ширины панели.
  await devtools.click(1013, 67, 400); // тип: все
  await devtools.click(400, 67, 400); // поле отбора
  await typeInto(devtools, 'api', sleep);
  await sleep(600);
}

const CLEAR = [195, 40]; // «очистить» в панели
const ROW = [250, 200]; // первая строка списка запросов
const TAB_HEADERS = [419, 176];
const TAB_PAYLOAD = [484, 176];
const CLOSE_DETAILS = [370, 176];

/// Область снимка без полосы с трансляцией страницы.
const PANEL = { x: 150, y: 0, width: 1432, height: 905 };

module.exports = async function script(ctx) {
  const { app, devtools, sleep, APP } = ctx;
  await prepare(ctx);

  // Приложение должно быть на переднем плане, пока с ним работают:
  // фоновая вкладка не получает кадров, и Flutter не видит щелчков.
  const act = async (fn) => {
    await app.front();
    await fn();
  };

  // ── запрос списка и его параметры ───────────────────────────────────
  await act(() => app.open(APP + '/tickets', 7000));
  await devtools.click(...ROW, 1200);
  await devtools.click(...TAB_PAYLOAD, 1200);
  await devtools.shot('19-network-payload', PANEL);

  await devtools.click(...TAB_HEADERS, 1200);
  await devtools.shot('20-network-headers', PANEL);
  await devtools.click(...CLOSE_DETAILS, 800);

  // ── переход по страницам отправляет новый запрос ────────────────────
  await devtools.click(...CLEAR, 600);
  await act(async () => {
    await app.click(1368, 876, 2000); // вторая страница
    await app.click(1368, 876, 2000); // третья страница
    await app.click(1248, 876, 2000); // назад на вторую
  });
  await devtools.shot('21-network-paging', PANEL);

  // ── отмена устаревших запросов ──────────────────────────────────────
  await devtools.click(...CLEAR, 600);
  await act(async () => {
    await app.click(1412, 28, 800); // меню учебных переключателей
    await app.click(1336, 116, 1000); // «медленный ответ»
    await app.click(700, 88, 500); // поле поиска
    for (const letter of ['п', 'р', 'и', 'н', 'т', 'е', 'р']) {
      await app.send('Input.dispatchKeyEvent', { type: 'keyDown', text: letter });
      await app.send('Input.dispatchKeyEvent', { type: 'keyUp' });
      await sleep(500);
    }
    await sleep(4000);
  });
  await devtools.shot('22-network-cancelled', PANEL);
};
