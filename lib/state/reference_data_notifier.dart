import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/department.dart';
import '../models/employee.dart';
import '../models/requester.dart';
import '../repositories/app_repositories.dart';

/// Справочные данные для всех экранов сразу: отделы, категории,
/// сотрудники и заявители. Отсюда выпадающие списки форм берут значения,
/// а таблицы — названия по ссылкам.
///
/// Данные читаются из репозиториев, а не из констант в коде: изменённая
/// в форме категория обязана сразу появиться в списке выбора.
class ReferenceDataNotifier extends ChangeNotifier {
  ReferenceDataNotifier(this._repositories);

  final AppRepositories _repositories;

  /// Все записи, включая логически удалённые: по ним разбираются ссылки
  /// в старых заявках, иначе в карточке появится «не найдено».
  List<Department> get allDepartments => _repositories.departments.rows;

  List<TicketCategory> get allCategories => _repositories.categories.rows;

  List<Employee> get allEmployees => _repositories.employees.rows;

  List<Requester> get allRequesters => _repositories.requesters.rows;

  /// Действующие записи — то, что предлагается на выбор в формах.
  List<Department> get departments => _repositories.departments.available;

  List<TicketCategory> get categories => _repositories.categories.available;

  List<Employee> get employees => _repositories.employees.available;

  List<Requester> get requesters => _repositories.requesters.available;

  Department? departmentById(int? id) => _byId(allDepartments, id, (d) => d.id);

  TicketCategory? categoryById(int? id) => _byId(allCategories, id, (c) => c.id);

  Employee? employeeById(int? id) => _byId(allEmployees, id, (e) => e.id);

  Requester? requesterById(int? id) => _byId(allRequesters, id, (r) => r.id);

  String departmentName(int? id) =>
      departmentById(id)?.name ?? '— отдел не указан —';

  String categoryName(int? id) =>
      categoryById(id)?.name ?? '— без категории —';

  String employeeName(int? id) =>
      employeeById(id)?.fullName ?? '— не назначен —';

  String requesterName(int? id) =>
      requesterById(id)?.fullName ?? '— заявитель не указан —';

  /// Сотрудники, обслуживающие категорию. Отсюда берётся список
  /// исполнителей в форме заявки: выбор категории сужает выбор
  /// исполнителя — связь многие ко многим работает как каскад.
  List<Employee> employeesForCategory(int? categoryId) {
    // Уволенный сотрудник не предлагается ни при какой категории.
    final working = employees.where((e) => e.isActive);
    if (categoryId == null) return working.toList();
    return working.where((e) => e.categoryIds.contains(categoryId)).toList();
  }

  /// Списки живут в репозиториях, поэтому обновление — это сообщение
  /// подписчикам, а не повторное чтение.
  void refresh() => notifyListeners();

  static E? _byId<E>(List<E> items, int? id, int Function(E) idOf) {
    if (id == null) return null;
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }
}
