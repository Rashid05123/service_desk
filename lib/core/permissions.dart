/// Права ролей в разрезе операций.
///
/// Матрица одна на всё приложение: по ней строятся защита маршрутов,
/// пункты навигации и видимость кнопок. Та же матрица записана
/// на сервере, в api/mock-server.js, и совпадать они обязаны.
///
/// Разница между ними принципиальная. Здесь матрица решает, что
/// показать: код приложения загружен в браузер, и любую проверку в нём
/// можно обойти правкой значений в DevTools. На сервере матрица решает,
/// что разрешить, и обойти её из браузера нельзя.
library;

import '../models/app_user.dart';

enum Permission {
  viewOwnTickets('ownTickets.view', 'Просмотр собственных заявок'),
  createOwnTicket('ownTickets.create', 'Подача обращения'),
  reopenOwnTicket('ownTickets.reopen', 'Возврат решённой заявки в работу'),
  viewQueue('queue.view', 'Личная очередь исполнителя'),
  viewTickets('tickets.view', 'Просмотр журнала заявок'),
  manageTickets('tickets.manage', 'Регистрация, изменение и закрытие заявок'),
  viewRequesters('requesters.view', 'Просмотр заявителей'),
  manageRequesters('requesters.manage', 'Работа с карточками заявителей'),
  viewEmployees('employees.view', 'Просмотр сотрудников поддержки'),
  manageEmployees('employees.manage', 'Управление сотрудниками поддержки'),
  viewDepartments('departments.view', 'Просмотр отделов'),
  manageDepartments('departments.manage', 'Ведение справочника отделов'),
  viewCategories('categories.view', 'Просмотр каталога категорий'),
  manageCategories('categories.manage', 'Ведение каталога категорий'),
  hardDelete('records.hardDelete', 'Физическое удаление записей'),
  restore('records.restore', 'Восстановление удалённых записей'),
  manageUsers('users.manage', 'Управление пользователями и ролями'),
  viewStats('stats.view', 'Просмотр статистики');

  const Permission(this.code, this.label);

  /// Код права, как он записан в матрице сервера.
  final String code;

  final String label;
}

const Map<Role, Set<Permission>> rolePermissions = {
  Role.requester: {
    Permission.viewOwnTickets,
    Permission.createOwnTicket,
    Permission.reopenOwnTicket,
    Permission.viewCategories,
  },
  Role.agent: {
    Permission.viewQueue,
    Permission.viewTickets,
    Permission.manageTickets,
    Permission.viewRequesters,
    Permission.manageRequesters,
    Permission.viewEmployees,
    Permission.viewDepartments,
    Permission.manageDepartments,
    Permission.viewCategories,
    Permission.manageCategories,
  },
  Role.admin: {
    Permission.viewTickets,
    Permission.viewRequesters,
    Permission.viewEmployees,
    Permission.manageEmployees,
    Permission.viewDepartments,
    Permission.viewCategories,
    Permission.hardDelete,
    Permission.restore,
    Permission.manageUsers,
    Permission.viewStats,
  },
};

/// Есть ли у роли право. Без роли — нет ни одного.
bool can(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);

/// Права просмотра и изменения раздела, общего для пяти сущностей.
typedef SectionPermissions = ({Permission view, Permission manage});

const Map<String, SectionPermissions> sectionPermissions = {
  '/tickets': (view: Permission.viewTickets, manage: Permission.manageTickets),
  '/requesters': (
    view: Permission.viewRequesters,
    manage: Permission.manageRequesters,
  ),
  '/employees': (
    view: Permission.viewEmployees,
    manage: Permission.manageEmployees,
  ),
  '/departments': (
    view: Permission.viewDepartments,
    manage: Permission.manageDepartments,
  ),
  '/categories': (
    view: Permission.viewCategories,
    manage: Permission.manageCategories,
  ),
};

/// Право, без которого адрес не открыть. `null` — адрес доступен любому
/// вошедшему: главная, экран отказа и неизвестные адреса, которые
/// отвечают экраном «страница не найдена».
///
/// Разбирается путь, а не имя маршрута: так под проверку попадает
/// и адрес, набранный вручную.
Permission? permissionForLocation(String location) {
  final segments = Uri.parse(location).pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;

  final first = segments.first;
  final second = segments.length > 1 ? segments[1] : null;

  switch (first) {
    case 'my':
      return second == 'new'
          ? Permission.createOwnTicket
          : Permission.viewOwnTickets;
    case 'queue':
      return Permission.viewQueue;
    case 'admin':
      return second == 'stats' ? Permission.viewStats : Permission.manageUsers;
  }

  final section = sectionPermissions['/$first'];
  if (section == null) return null;

  // Форма создания и форма изменения требуют права изменения,
  // список и карточка — права просмотра.
  final editing = second == 'new' || segments.last == 'edit';
  return editing ? section.manage : section.view;
}

/// Можно ли роли открыть адрес.
bool canOpen(Role? role, String location) {
  final required = permissionForLocation(location);
  return required == null ? role != null : can(role, required);
}
