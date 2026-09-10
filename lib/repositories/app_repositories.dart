import 'package:dio/dio.dart';

import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import 'api_repositories.dart';
import 'category_repository.dart';
import 'department_repository.dart';
import 'employee_repository.dart';
import 'requester_repository.dart';
import 'ticket_repository.dart';

/// Пять репозиториев одним объектом.
///
/// Хранятся договоры, а не реализации: приложение работает с сервером,
/// проверки ПР3 — с локальным хранилищем, и различие сводится к тому,
/// какой фабрикой собран этот объект. Это и есть та самая замена
/// реализации, ради которой договор доступа к данным в ПР2 был отделён
/// от способа хранения.
class AppRepositories {
  const AppRepositories({
    required this.tickets,
    required this.employees,
    required this.requesters,
    required this.departments,
    required this.categories,
  });

  /// Работа через учебное API — то, как приложение собрано в ПР4.
  factory AppRepositories.api(Dio dio) {
    final api = ApiRepositories(dio);
    return AppRepositories(
      tickets: api.tickets,
      employees: api.employees,
      requesters: api.requesters,
      departments: api.departments,
      categories: api.categories,
    );
  }

  final TicketRepository tickets;
  final EmployeeRepository employees;
  final RequesterRepository requesters;
  final DepartmentRepository departments;
  final CategoryRepository categories;
}

/// Локальное хранилище со связями между репозиториями.
///
/// Приложением больше не используется: данные приходят с сервера.
/// Осталось как эталон поведения — правила уникальности и запрета
/// удаления связанных записей учебный сервер повторяет один в один,
/// и 74 проверки ПР3 продолжают сторожить именно их.
class LocalRepositories {
  LocalRepositories(FaultSwitch faults, this.store)
    : departments = PersistentDepartmentRepository(faults, store),
      categories = PersistentCategoryRepository(faults, store),
      employees = PersistentEmployeeRepository(faults, store),
      requesters = PersistentRequesterRepository(faults, store),
      tickets = PersistentTicketRepository(faults, store) {
    _wireDependencies();
  }

  final CollectionStore store;

  final PersistentDepartmentRepository departments;
  final PersistentCategoryRepository categories;
  final PersistentEmployeeRepository employees;
  final PersistentRequesterRepository requesters;
  final PersistentTicketRepository tickets;

  /// Кто на кого ссылается. Отсюда берётся и запрет удаления, и число
  /// связанных записей в сообщении об отказе. С сервером эту же роль
  /// играет сам сервер, и клиенту связывать нечего.
  void _wireDependencies() {
    departments.dependsOn('сотрудников', employees.countByDepartment);
    departments.dependsOn('заявителей', requesters.countByDepartment);

    categories.dependsOn('заявок', tickets.countByCategory);
    categories.dependsOn('сотрудников', employees.countByCategory);

    employees.dependsOn('заявок', tickets.countByEmployee);

    requesters.dependsOn('заявок', tickets.countByRequester);
  }
}
