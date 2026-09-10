#!/usr/bin/env node
/**
 * Учебный мок-сервер API «Служба поддержки» (Service Desk).
 *
 * Реализует контракт из файла КОНТРАКТ-API.md. Зависимостей нет —
 * нужен только Node.js 18 или новее.
 *
 *   node api/mock-server.js
 *   node api/mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Начальный набор берётся из seed.json — того же самого, с которым
 * приложение работало в ПР3. Файл порождается командой
 * `dart run tool/dump_seed.dart`, поэтому данные клиента и сервера
 * совпадают по построению, а не по внимательности переписывающего.
 *
 * Данные держатся в памяти и сбрасываются при перезапуске либо
 * запросом POST /api/__reset.
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах (индикатор загрузки)
 *   ?__fail=500     принудительный код ошибки (обработка ошибок)
 */

'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));

// Список разрешённых источников. localhost и 127.0.0.1 — с точки зрения
// браузера разные источники, поэтому в списке должны быть оба: клиент,
// открытый по одному адресу, иначе не достучится по другому.
const ORIGINS = arg('origin', 'http://localhost:5555,http://127.0.0.1:5555')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const SEED_PATH = path.join(__dirname, 'seed.json');

// ─────────────────────────────── данные ───────────────────────────────

let db = {};

function reset() {
  db = JSON.parse(fs.readFileSync(SEED_PATH, 'utf8'));
}

reset();

const COLLECTION_NAMES = [
  'tickets',
  'employees',
  'requesters',
  'departments',
  'categories',
];

function rows(collection) {
  return db[collection] || [];
}

/** Записи без логически удалённых: на них считаются ссылки и счётчики. */
function live(collection) {
  return rows(collection).filter((r) => r.deletedAt == null);
}

function byId(collection, id) {
  return rows(collection).find((r) => r.id === id) || null;
}

function nextId(collection) {
  return rows(collection).reduce((max, r) => (r.id > max ? r.id : max), 0) + 1;
}

function exists(collection, id) {
  return live(collection).some((r) => r.id === id);
}

function nowIso() {
  return new Date().toISOString();
}

// ────────────────────── представление на чтение ──────────────────────
//
// Контракт различает представление на запись и на чтение: уходят
// идентификаторы, приходят развёрнутые объекты. Кроме них read-модель
// несёт счётчики связей — там, где в ПР3 стоял синхронный подсчёт
// по локальной коллекции, по сети такого сделать нельзя.

function slim(collection, id, field) {
  const item = id == null ? null : byId(collection, id);
  return item == null ? null : { id: item.id, [field]: item[field] };
}

function ticketsOfEmployee(id) {
  return live('tickets').filter(
    (t) => t.assigneeId === id || (t.coworkerIds || []).includes(id),
  ).length;
}

const EXPAND = {
  departments: (d) => ({
    ...d,
    employeeCount: live('employees').filter((e) => e.departmentId === d.id).length,
    requesterCount: live('requesters').filter((r) => r.departmentId === d.id).length,
  }),

  categories: (c) => ({
    ...c,
    ticketCount: live('tickets').filter((t) => t.categoryId === c.id).length,
    employeeCount: live('employees').filter((e) =>
      (e.categoryIds || []).includes(c.id),
    ).length,
  }),

  employees: (e) => ({
    id: e.id,
    fullName: e.fullName,
    position: e.position,
    department: slim('departments', e.departmentId, 'name'),
    email: e.email,
    phone: e.phone,
    supportLine: e.supportLine,
    categories: (e.categoryIds || [])
      .map((id) => slim('categories', id, 'name'))
      .filter(Boolean),
    isActive: e.isActive,
    deletedAt: e.deletedAt,
    ticketCount: ticketsOfEmployee(e.id),
  }),

  requesters: (r) => ({
    id: r.id,
    fullName: r.fullName,
    position: r.position,
    department: slim('departments', r.departmentId, 'name'),
    account: r.account,
    note: r.note,
    deletedAt: r.deletedAt,
    ticketCount: live('tickets').filter((t) => t.requesterId === r.id).length,
  }),

  tickets: (t) => ({
    id: t.id,
    number: t.number,
    subject: t.subject,
    description: t.description,
    category: slim('categories', t.categoryId, 'name'),
    priority: t.priority,
    status: t.status,
    assignee: slim('employees', t.assigneeId, 'fullName'),
    coworkers: (t.coworkerIds || [])
      .map((id) => slim('employees', id, 'fullName'))
      .filter(Boolean),
    requester: slim('requesters', t.requesterId, 'fullName'),
    createdAt: t.createdAt,
    dueAt: t.dueAt,
    deletedAt: t.deletedAt,
  }),
};

// ─────────────────────────── отбор и сортировка ───────────────────────────

const text = (value) => String(value == null ? '' : value);
const lower = (value) => text(value).toLowerCase();
const lastName = (fullName) => text(fullName).split(' ')[0];

/** Поиск повторяет поведение ПР3: у каждой сущности свой набор полей. */
const SEARCH = {
  tickets: (t, q) => lower(t.number).includes(q) || lower(t.subject).includes(q),
  employees: (e, q) =>
    lower(lastName(e.fullName)).includes(q) || lower(e.position).includes(q),
  requesters: (r, q) =>
    lower(lastName(r.fullName)).includes(q) ||
    lower(r.account && r.account.login).includes(q),
  departments: (d, q) => lower(d.name).includes(q) || lower(d.code).includes(q),
  categories: (c, q) =>
    lower(c.name).includes(q) || lower(c.description).includes(q),
};

function num(value) {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

const flag = (value) =>
  value === 'true' ? true : value === 'false' ? false : null;

/** Верхняя граница диапазона дат включает день целиком. */
function endOfDay(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  date.setHours(23, 59, 59, 999);
  return date;
}

const FILTERS = {
  tickets: (list, q) => {
    const categoryId = num(q.categoryId);
    const assigneeId = num(q.assigneeId);
    const requesterId = num(q.requesterId);
    const from = q.createdFrom ? new Date(q.createdFrom) : null;
    const to = q.createdTo ? endOfDay(q.createdTo) : null;

    return list.filter((t) => {
      if (categoryId != null && t.categoryId !== categoryId) return false;
      if (q.priority && t.priority !== q.priority) return false;
      if (q.status && t.status !== q.status) return false;
      // Соисполнители учитываются наравне с исполнителем: связь многие
      // ко многим тоже должна отражаться в отборе.
      if (
        assigneeId != null &&
        t.assigneeId !== assigneeId &&
        !(t.coworkerIds || []).includes(assigneeId)
      ) {
        return false;
      }
      if (requesterId != null && t.requesterId !== requesterId) return false;
      if (from && new Date(t.createdAt) < from) return false;
      if (to && new Date(t.createdAt) > to) return false;
      return true;
    });
  },

  employees: (list, q) => {
    const departmentId = num(q.departmentId);
    const categoryId = num(q.categoryId);
    const supportLine = num(q.supportLine);
    const isActive = flag(q.active);

    return list.filter((e) => {
      if (departmentId != null && e.departmentId !== departmentId) return false;
      if (categoryId != null && !(e.categoryIds || []).includes(categoryId)) {
        return false;
      }
      if (supportLine != null && e.supportLine !== supportLine) return false;
      if (isActive != null && e.isActive !== isActive) return false;
      return true;
    });
  },

  requesters: (list, q) => {
    const departmentId = num(q.departmentId);
    const isBlocked = flag(q.blocked);

    return list.filter((r) => {
      if (departmentId != null && r.departmentId !== departmentId) return false;
      if (isBlocked != null && (r.account || {}).isBlocked !== isBlocked) {
        return false;
      }
      return true;
    });
  },

  departments: (list) => list,

  categories: (list, q) => {
    const isActive = flag(q.active);
    return list.filter((c) => isActive == null || c.isActive === isActive);
  },
};

const PRIORITY_ORDER = ['low', 'normal', 'high', 'critical'];
const STATUS_ORDER = ['new', 'in_progress', 'waiting', 'resolved', 'closed'];

const compareText = (a, b) => text(a).localeCompare(text(b), 'ru');

const SORTERS = {
  tickets: {
    number: (a, b) => compareText(a.number, b.number),
    subject: (a, b) => compareText(a.subject, b.subject),
    // Приоритет и статус — по заданному порядку, а не по алфавиту.
    priority: (a, b) =>
      PRIORITY_ORDER.indexOf(a.priority) - PRIORITY_ORDER.indexOf(b.priority),
    status: (a, b) =>
      STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status),
    dueAt: (a, b) => new Date(a.dueAt) - new Date(b.dueAt),
    createdAt: (a, b) => new Date(a.createdAt) - new Date(b.createdAt),
  },
  employees: {
    fullName: (a, b) => compareText(a.fullName, b.fullName),
    position: (a, b) => compareText(a.position, b.position),
    supportLine: (a, b) => a.supportLine - b.supportLine,
    email: (a, b) => compareText(a.email, b.email),
  },
  requesters: {
    fullName: (a, b) => compareText(a.fullName, b.fullName),
    position: (a, b) => compareText(a.position, b.position),
    login: (a, b) => compareText(a.account.login, b.account.login),
  },
  departments: {
    name: (a, b) => compareText(a.name, b.name),
    code: (a, b) => compareText(a.code, b.code),
    location: (a, b) => compareText(a.location, b.location),
  },
  categories: {
    name: (a, b) => compareText(a.name, b.name),
    slaHours: (a, b) => a.slaHours - b.slaHours,
  },
};

const DEFAULT_SORT = {
  tickets: 'createdAt',
  employees: 'fullName',
  requesters: 'fullName',
  departments: 'name',
  categories: 'name',
};

function select(collection, query) {
  let list = rows(collection).filter(
    (r) => query.includeDeleted === 'true' || r.deletedAt == null,
  );

  const needle = lower(query.search).trim();
  if (needle) list = list.filter((r) => SEARCH[collection](r, needle));

  list = FILTERS[collection](list, query);

  const [field, direction] = text(
    query.sort || DEFAULT_SORT[collection],
  ).split(',');
  const sorters = SORTERS[collection];
  const compare = sorters[field] || sorters[DEFAULT_SORT[collection]];
  const sign = direction === 'desc' ? -1 : 1;
  list = [...list].sort((a, b) => sign * compare(a, b));

  const size = Math.min(Math.max(num(query.size) || 10, 1), 100);
  const page = Math.max(num(query.page) || 1, 1);
  const total = list.length;
  const from = (page - 1) * size;

  return {
    items: list.slice(from, from + size).map(EXPAND[collection]),
    page,
    size,
    total,
    totalPages: total === 0 ? 1 : Math.ceil(total / size),
  };
}

// ──────────────────────────── проверка полей ────────────────────────────
//
// Ключи объекта errors совпадают с именами полей формы, включая
// вложенные («account.login»), поэтому клиент раскладывает ошибки
// по полям без сопоставления вручную.

const EMAIL_RE = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;
const PHONE_RE = /^\+?[\d\s()-]{7,20}$/;
const LOGIN_RE = /^[a-z][a-z0-9._-]{2,29}$/;
const CODE_RE = /^[A-Z0-9]{2,10}$/;
const NUMBER_RE = /^SD-\d{6}$/;

function required(errors, key, value, message) {
  const empty =
    value === null ||
    value === undefined ||
    (typeof value === 'string' && value.trim() === '') ||
    (Array.isArray(value) && value.length === 0);
  if (empty) errors[key] = message;
  return !empty;
}

function length(errors, key, value, min, max) {
  const size = text(value).trim().length;
  if (size < min || size > max) {
    errors[key] = `Длина от ${min} до ${max} символов, сейчас ${size}`;
  }
}

function range(errors, key, value, min, max) {
  const parsed = num(value);
  if (parsed == null || parsed < min || parsed > max) {
    errors[key] = `Значение от ${min} до ${max}`;
  }
}

function reference(errors, key, collection, id, message) {
  if (!exists(collection, num(id))) errors[key] = message;
}

/** Собственная запись при сравнении исключается: иначе она конфликтует сама с собой. */
function unique(errors, collection, key, id, value, valueOf, message) {
  const needle = lower(value).trim();
  const clash = rows(collection).some(
    (r) => r.id !== id && lower(valueOf(r)).trim() === needle,
  );
  if (clash) errors[key] = message;
}

const VALIDATORS = {
  tickets(body, id) {
    const errors = {};
    if (required(errors, 'number', body.number, 'Укажите регистрационный номер')) {
      if (!NUMBER_RE.test(text(body.number).trim())) {
        errors.number = 'Номер имеет вид SD-000012';
      } else {
        unique(errors, 'tickets', 'number', id, body.number, (r) => r.number,
          `Заявка с номером ${text(body.number).trim()} уже зарегистрирована`);
      }
    }
    if (required(errors, 'subject', body.subject, 'Укажите тему заявки')) {
      length(errors, 'subject', body.subject, 5, 120);
    }
    if (required(errors, 'description', body.description, 'Опишите обращение')) {
      length(errors, 'description', body.description, 10, 2000);
    }
    if (required(errors, 'categoryId', body.categoryId, 'Выберите категорию')) {
      reference(errors, 'categoryId', 'categories', body.categoryId,
        'Такой категории нет в справочнике');
    }
    if (required(errors, 'requesterId', body.requesterId, 'Выберите заявителя')) {
      reference(errors, 'requesterId', 'requesters', body.requesterId,
        'Такого заявителя нет в справочнике');
    }
    if (body.assigneeId != null) {
      reference(errors, 'assigneeId', 'employees', body.assigneeId,
        'Такого сотрудника нет в справочнике');
      // Правило предметной области: исполнителем может быть только
      // сотрудник, обслуживающий категорию заявки.
      const employee = byId('employees', num(body.assigneeId));
      if (
        employee &&
        body.categoryId != null &&
        !(employee.categoryIds || []).includes(num(body.categoryId))
      ) {
        errors.assigneeId = 'Сотрудник не обслуживает выбранную категорию';
      }
    }
    for (const coworkerId of body.coworkerIds || []) {
      if (!exists('employees', num(coworkerId))) {
        errors.coworkerIds = 'В списке соисполнителей есть несуществующая запись';
      }
    }
    if (
      body.createdAt &&
      body.dueAt &&
      new Date(body.dueAt) < new Date(body.createdAt)
    ) {
      errors.dueAt = 'Срок решения не может быть раньше даты регистрации';
    }
    return errors;
  },

  employees(body, id) {
    const errors = {};
    if (required(errors, 'fullName', body.fullName, 'Укажите ФИО сотрудника')) {
      length(errors, 'fullName', body.fullName, 5, 100);
    }
    if (required(errors, 'position', body.position, 'Укажите должность')) {
      length(errors, 'position', body.position, 2, 80);
    }
    if (required(errors, 'departmentId', body.departmentId, 'Выберите отдел')) {
      reference(errors, 'departmentId', 'departments', body.departmentId,
        'Такого отдела нет в справочнике');
    }
    if (required(errors, 'email', body.email, 'Укажите адрес почты')) {
      if (!EMAIL_RE.test(text(body.email).trim())) {
        errors.email = 'Адрес имеет вид name@example.com';
      } else {
        unique(errors, 'employees', 'email', id, body.email, (r) => r.email,
          `Адрес ${text(body.email).trim()} уже занят другим сотрудником`);
      }
    }
    if (required(errors, 'phone', body.phone, 'Укажите телефон')) {
      if (!PHONE_RE.test(text(body.phone).trim())) {
        errors.phone = 'Телефон имеет вид +7 495 000-00-00';
      }
    }
    range(errors, 'supportLine', body.supportLine, 1, 3);
    if (
      required(errors, 'categoryIds', body.categoryIds,
        'Отметьте хотя бы одну обслуживаемую категорию')
    ) {
      for (const categoryId of body.categoryIds) {
        if (!exists('categories', num(categoryId))) {
          errors.categoryIds = 'В списке компетенций есть несуществующая категория';
        }
      }
    }
    return errors;
  },

  requesters(body, id) {
    const errors = {};
    const account = body.account || {};
    if (required(errors, 'fullName', body.fullName, 'Укажите ФИО заявителя')) {
      length(errors, 'fullName', body.fullName, 5, 100);
    }
    if (required(errors, 'position', body.position, 'Укажите должность')) {
      length(errors, 'position', body.position, 2, 80);
    }
    if (required(errors, 'departmentId', body.departmentId, 'Выберите отдел')) {
      reference(errors, 'departmentId', 'departments', body.departmentId,
        'Такого отдела нет в справочнике');
    }
    if (required(errors, 'account.login', account.login, 'Укажите доменный логин')) {
      if (!LOGIN_RE.test(text(account.login).trim())) {
        errors['account.login'] = 'Латиница в нижнем регистре, от 3 до 30 символов';
      } else {
        unique(errors, 'requesters', 'account.login', id, account.login,
          (r) => (r.account || {}).login,
          `Логин ${text(account.login).trim()} уже занят`);
      }
    }
    if (required(errors, 'account.email', account.email, 'Укажите адрес почты')) {
      if (!EMAIL_RE.test(text(account.email).trim())) {
        errors['account.email'] = 'Адрес имеет вид name@example.com';
      } else {
        unique(errors, 'requesters', 'account.email', id, account.email,
          (r) => (r.account || {}).email,
          `Адрес ${text(account.email).trim()} уже занят`);
      }
    }
    if (required(errors, 'account.phone', account.phone, 'Укажите телефон')) {
      if (!PHONE_RE.test(text(account.phone).trim())) {
        errors['account.phone'] = 'Телефон имеет вид +7 495 000-00-00';
      }
    }
    return errors;
  },

  departments(body, id) {
    const errors = {};
    if (required(errors, 'name', body.name, 'Укажите название отдела')) {
      length(errors, 'name', body.name, 3, 120);
      if (!errors.name) {
        unique(errors, 'departments', 'name', id, body.name, (r) => r.name,
          `Отдел с названием «${text(body.name).trim()}» уже есть в справочнике`);
      }
    }
    if (required(errors, 'code', body.code, 'Укажите код отдела')) {
      if (!CODE_RE.test(text(body.code).trim().toUpperCase())) {
        errors.code = 'Заглавная латиница и цифры, от 2 до 10 символов';
      } else {
        unique(errors, 'departments', 'code', id, body.code, (r) => r.code,
          `Код ${text(body.code).trim().toUpperCase()} уже занят другим отделом`);
      }
    }
    if (required(errors, 'location', body.location, 'Укажите корпус и кабинет')) {
      length(errors, 'location', body.location, 3, 80);
    }
    if (required(errors, 'phone', body.phone, 'Укажите телефон отдела')) {
      if (!PHONE_RE.test(text(body.phone).trim())) {
        errors.phone = 'Телефон имеет вид +7 495 000-00-00';
      }
    }
    return errors;
  },

  categories(body, id) {
    const errors = {};
    if (required(errors, 'name', body.name, 'Укажите название категории')) {
      length(errors, 'name', body.name, 3, 80);
      if (!errors.name) {
        unique(errors, 'categories', 'name', id, body.name, (r) => r.name,
          `Категория «${text(body.name).trim()}» уже есть в справочнике`);
      }
    }
    if (
      required(errors, 'description', body.description,
        'Опишите, что относится к категории')
    ) {
      length(errors, 'description', body.description, 10, 500);
    }
    range(errors, 'slaHours', body.slaHours, 1, 720);
    return errors;
  },
};

// ─────────────────────── ссылочная целостность ───────────────────────

const DEPENDENCIES = {
  departments: [
    {
      label: 'сотрудников',
      count: (id) => live('employees').filter((e) => e.departmentId === id).length,
    },
    {
      label: 'заявителей',
      count: (id) => live('requesters').filter((r) => r.departmentId === id).length,
    },
  ],
  categories: [
    {
      label: 'заявок',
      count: (id) => live('tickets').filter((t) => t.categoryId === id).length,
    },
    {
      label: 'сотрудников',
      count: (id) =>
        live('employees').filter((e) => (e.categoryIds || []).includes(id)).length,
    },
  ],
  employees: [{ label: 'заявок', count: ticketsOfEmployee }],
  requesters: [
    {
      label: 'заявок',
      count: (id) => live('tickets').filter((t) => t.requesterId === id).length,
    },
  ],
  tickets: [],
};

const DESCRIBE = {
  tickets: (t) => `заявка ${t.number}`,
  employees: (e) => `сотрудник ${e.fullName}`,
  requesters: (r) => `заявитель ${r.fullName}`,
  departments: (d) => `отдел «${d.name}»`,
  categories: (c) => `категория «${c.name}»`,
};

/** Текст отказа или null, если ссылок нет. */
function referenceConflict(collection, item) {
  const found = DEPENDENCIES[collection]
    .map((d) => ({ label: d.label, count: d.count(item.id) }))
    .filter((d) => d.count > 0);

  if (found.length === 0) return null;

  const details = found.map((d) => `${d.count} ${d.label}`).join(', ');
  return `Нельзя удалить: ${DESCRIBE[collection](item)}. Связанные записи: ${details}`;
}

// ─────────────────── представление на запись ───────────────────

/** Из тела запроса берутся только поля модели: идентификатор выдаёт сервер. */
const NORMALIZE = {
  tickets: (body, current) => ({
    number: text(body.number).trim(),
    subject: text(body.subject).trim(),
    description: text(body.description).trim(),
    categoryId: num(body.categoryId),
    priority: body.priority || 'normal',
    status: body.status || 'new',
    assigneeId: body.assigneeId == null ? null : num(body.assigneeId),
    coworkerIds: (body.coworkerIds || []).map(num).filter((v) => v != null),
    requesterId: num(body.requesterId),
    createdAt: body.createdAt || (current && current.createdAt) || nowIso(),
    dueAt: body.dueAt || (current && current.dueAt) || nowIso(),
  }),

  employees: (body) => ({
    fullName: text(body.fullName).trim(),
    position: text(body.position).trim(),
    departmentId: num(body.departmentId),
    email: text(body.email).trim(),
    phone: text(body.phone).trim(),
    supportLine: num(body.supportLine) || 1,
    categoryIds: (body.categoryIds || []).map(num).filter((v) => v != null),
    isActive: body.isActive !== false,
  }),

  requesters: (body) => ({
    fullName: text(body.fullName).trim(),
    position: text(body.position).trim(),
    departmentId: num(body.departmentId),
    account: {
      login: text((body.account || {}).login).trim(),
      email: text((body.account || {}).email).trim(),
      phone: text((body.account || {}).phone).trim(),
      office: text((body.account || {}).office).trim(),
      isBlocked: (body.account || {}).isBlocked === true,
    },
    note: text(body.note).trim(),
  }),

  departments: (body) => ({
    name: text(body.name).trim(),
    code: text(body.code).trim().toUpperCase(),
    location: text(body.location).trim(),
    phone: text(body.phone).trim(),
  }),

  categories: (body) => ({
    name: text(body.name).trim(),
    description: text(body.description).trim(),
    slaHours: num(body.slaHours) || 24,
    isActive: body.isActive !== false,
  }),
};

// ──────────────────────────── ответы и CORS ────────────────────────────

/**
 * Заголовки доступа с другого источника. Если источник запроса не входит
 * в список, Access-Control-Allow-Origin не отправляется вовсе — и браузер
 * блокирует ответ, хотя сервер его вернул. Со стороны клиента это
 * выглядит в точности как «сервер недоступен».
 */
function cors(res, origin) {
  if (origin && ORIGINS.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  );
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
}

function send(res, status, payload) {
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = Buffer.from(JSON.stringify(payload), 'utf8');
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': body.length,
  });
  res.end(body);
}

const fail = (res, status, message) => send(res, status, { message });

const MESSAGES = {
  400: 'Некорректный запрос',
  401: 'Требуется вход в систему',
  403: 'Недостаточно прав для этого действия',
  404: 'Объект не найден',
  409: 'Нарушено ограничение целостности',
  422: 'Ошибка валидации',
  500: 'Внутренняя ошибка сервера',
  503: 'Сервис временно недоступен',
};

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ─────────────────────────────── маршруты ───────────────────────────────

async function route(req, res, url) {
  const query = Object.fromEntries(url.searchParams);
  const segments = url.pathname.replace(/^\/+|\/+$/g, '').split('/');

  if (segments[0] !== 'api') return fail(res, 404, 'Неизвестный адрес');

  // Учебные возможности: задержка ответа и принудительный код ошибки.
  const delay = num(query.__delay);
  if (delay) await sleep(Math.min(delay, 10000));

  const forced = num(query.__fail);
  if (forced) return fail(res, forced, MESSAGES[forced] || 'Принудительная ошибка');

  const [, first, second, third] = segments;

  if (first === '__health') {
    return send(res, 200, {
      status: 'ok',
      collections: Object.fromEntries(
        COLLECTION_NAMES.map((c) => [c, rows(c).length]),
      ),
      origins: ORIGINS,
    });
  }

  if (first === '__reset' && req.method === 'POST') {
    reset();
    return send(res, 200, { status: 'reset' });
  }

  const collection = first;
  if (!COLLECTION_NAMES.includes(collection)) {
    return fail(res, 404, 'Неизвестная коллекция');
  }

  // Свободный регистрационный номер. Разбирается раньше адреса записи:
  // иначе «next-number» будет принят за идентификатор.
  if (collection === 'tickets' && second === 'next-number') {
    const max = rows('tickets').reduce((acc, t) => {
      const digits = Number(text(t.number).replace(/\D/g, '')) || 0;
      return digits > acc ? digits : acc;
    }, 0);
    return send(res, 200, { number: `SD-${String(max + 1).padStart(6, '0')}` });
  }

  if (second === 'bulk-delete' && req.method === 'POST') {
    const body = await readBody(req);
    const ids = (body.ids || []).map(num).filter((v) => v != null);

    // Сначала проверяются все выбранные записи и только потом удаляется
    // хоть одна: иначе при отказе на середине списка часть записей уже
    // была бы удалена, а клиент увидел бы только сообщение об ошибке.
    const targets = [];
    for (const id of ids) {
      const item = byId(collection, id);
      if (!item || item.deletedAt != null) continue;
      const conflict = referenceConflict(collection, item);
      if (conflict) return fail(res, 409, conflict);
      targets.push(item);
    }
    const at = nowIso();
    for (const item of targets) item.deletedAt = at;
    return send(res, 200, { deleted: targets.length });
  }

  // Список коллекции.
  if (!second) {
    if (req.method === 'GET') return send(res, 200, select(collection, query));

    if (req.method === 'POST') {
      const body = await readBody(req);
      const errors = VALIDATORS[collection](body, null);
      if (Object.keys(errors).length > 0) {
        return send(res, 422, { message: MESSAGES[422], errors });
      }
      const created = {
        id: nextId(collection),
        ...NORMALIZE[collection](body, null),
        deletedAt: null,
      };
      rows(collection).push(created);
      return send(res, 201, EXPAND[collection](created));
    }

    return fail(res, 400, `Метод ${req.method} здесь не поддерживается`);
  }

  const id = num(second);
  if (id == null) return fail(res, 400, `Идентификатор «${second}» не число`);

  const item = byId(collection, id);
  if (!item) return fail(res, 404, `Запись ${id} не найдена`);

  if (third === 'restore' && req.method === 'POST') {
    item.deletedAt = null;
    return send(res, 200, EXPAND[collection](item));
  }

  if (third) return fail(res, 404, 'Неизвестный адрес');

  if (req.method === 'GET') return send(res, 200, EXPAND[collection](item));

  if (req.method === 'PUT') {
    const body = await readBody(req);
    const errors = VALIDATORS[collection](body, id);
    if (Object.keys(errors).length > 0) {
      return send(res, 422, { message: MESSAGES[422], errors });
    }
    Object.assign(item, NORMALIZE[collection](body, item));
    return send(res, 200, EXPAND[collection](item));
  }

  if (req.method === 'DELETE') {
    const conflict = referenceConflict(collection, item);
    if (conflict) return fail(res, 409, conflict);

    if (query.hard === 'true') {
      db[collection] = rows(collection).filter((r) => r.id !== id);
    } else {
      item.deletedAt = nowIso();
    }
    return send(res, 204);
  }

  return fail(res, 400, `Метод ${req.method} здесь не поддерживается`);
}

// ─────────────────────────────── сервер ───────────────────────────────

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  cors(res, req.headers.origin);

  // Предварительный запрос браузер отправляет перед любым обращением
  // с заголовком Authorization или методом, отличным от GET и POST.
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const started = Date.now();
  res.on('finish', () => {
    console.log(
      `${req.method} ${url.pathname}${url.search} → ${res.statusCode}` +
        ` (${Date.now() - started} мс, источник ${req.headers.origin || '—'})`,
    );
  });

  try {
    await route(req, res, url);
  } catch (e) {
    console.error('сбой обработки:', e);
    if (!res.headersSent) fail(res, 500, MESSAGES[500]);
  }
});

server.listen(PORT, () => {
  console.log(`API «Служба поддержки» слушает http://localhost:${PORT}/api`);
  console.log(`Разрешённые источники: ${ORIGINS.join(', ')}`);
  console.log(`Проверка: http://localhost:${PORT}/api/__health`);
});
