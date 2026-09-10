'use strict';
module.exports = async function script(page, { sleep, APP }) {
  // Прямой переход по адресу карточки: справочники ещё не загружены.
  await page.open(APP + '/tickets/1', 7000);
  await page.shot('10-ticket-detail');
  await page.open(APP + '/requesters/1', 6000);
  await page.shot('18-requester-detail');
};
