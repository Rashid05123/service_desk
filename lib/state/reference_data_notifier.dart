import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../models/category_query.dart';
import '../models/department.dart';
import '../models/department_query.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/requester.dart';
import '../models/requester_query.dart';
import '../repositories/app_repositories.dart';

/// Кэш справочников: отделы, категории, сотрудники и заявители.
///
/// В ПР3 эти списки читались из репозитория напрямую и всегда были под
/// рукой. С сервером так нельзя: открытие формы означало бы четыре
/// запроса, а открытие формы заявки в третий раз — ещё четыре. Поэтому
/// справочники запрашиваются один раз и держатся в памяти, пока их не
/// изменят.
///
/// Размер страницы задан с запасом: учебные справочники заведомо меньше
/// сотни записей. Для справочника, который в страницу не помещается,
/// понадобился бы поиск по мере ввода, а не готовый список.
class ReferenceDataNotifier extends ChangeNotifier {
  ReferenceDataNotifier(this._repositories);

  final AppRepositories _repositories;

  static const int _pageSize = 100;

  List<Department> _departments = const [];
  List<TicketCategory> _categories = const [];
  List<Employee> _employees = const [];
  List<Requester> _requesters = const [];

  /// Незавершённая загрузка. Пока она идёт, повторный вызов
  /// [ensureLoaded] ждёт её же, а не отправляет второй набор запросов:
  /// список и форма открываются почти одновременно.
  Future<void>? _loading;

  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Загрузить справочники, если они ещё не загружены.
  ///
  /// Отказ пробрасывается наружу: форма, у которой нет справочников,
  /// показывает состояние ошибки, а не пустые выпадающие списки.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  /// Загрузка «на всякий случай»: список отрисуется и без справочников,
  /// просто вместо названия по ссылке будет прочерк. Отказ здесь гасится
  /// намеренно — иначе сбой второстепенного запроса ронял бы экран,
  /// на котором главный запрос выполнился успешно.
  void warmUp() {
    ensureLoaded().catchError((Object _) {});
  }

  /// Пометить кэш устаревшим.
  ///
  /// Вызывается после изменения записи справочника. Перечитывать сразу
  /// незачем: экран, которому справочники нужны, всё равно начнёт
  /// с [ensureLoaded], а прежние значения до тех пор дают показать
  /// названия по ссылкам вместо прочерков.
  void invalidate() {
    _loaded = false;
    _loading = null;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      // Запросы отправляются все сразу и только потом ожидаются: они
      // независимы, и ждать их по очереди означало бы четырёхкратное
      // ожидание вместо одного.
      final departments = _repositories.departments.find(
        const DepartmentQuery(size: _pageSize, includeDeleted: true),
      );
      final categories = _repositories.categories.find(
        const CategoryQuery(size: _pageSize, includeDeleted: true),
      );
      final employees = _repositories.employees.find(
        const EmployeeQuery(size: _pageSize, includeDeleted: true),
      );
      final requesters = _repositories.requesters.find(
        const RequesterQuery(size: _pageSize, includeDeleted: true),
      );

      // Ждать по очереди нельзя: если откажет первый запрос, метод
      // завершится исключением, а отказы остальных трёх останутся
      // никем не обработанными — в консоли браузера это выглядит как
      // «Uncaught (in promise) NetworkException». Future.wait ждёт все
      // четыре, отдаёт первую ошибку и гасит остальные.
      await Future.wait<void>([
        departments.then((page) {
          _departments = page.items;
        }),
        categories.then((page) {
          _categories = page.items;
        }),
        employees.then((page) {
          _employees = page.items;
        }),
        requesters.then((page) {
          _requesters = page.items;
        }),
      ]);
      _loaded = true;
      notifyListeners();
    } finally {
      _loading = null;
    }
  }

  /// Все записи, включая логически удалённые: по ним разбираются ссылки
  /// в старых заявках, иначе в карточке появится «не найдено».
  List<Department> get allDepartments => _departments;

  List<TicketCategory> get allCategories => _categories;

  List<Employee> get allEmployees => _employees;

  List<Requester> get allRequesters => _requesters;

  /// Действующие записи — то, что предлагается на выбор в формах.
  List<Department> get departments =>
      _departments.where((d) => !d.isDeleted).toList();

  List<TicketCategory> get categories =>
      _categories.where((c) => !c.isDeleted).toList();

  List<Employee> get employees =>
      _employees.where((e) => !e.isDeleted).toList();

  List<Requester> get requesters =>
      _requesters.where((r) => !r.isDeleted).toList();

  Department? departmentById(int? id) => _byId(allDepartments, id, (d) => d.id);

  TicketCategory? categoryById(int? id) =>
      _byId(allCategories, id, (c) => c.id);

  Employee? employeeById(int? id) => _byId(allEmployees, id, (e) => e.id);

  Requester? requesterById(int? id) => _byId(allRequesters, id, (r) => r.id);

  String departmentName(int? id) =>
      departmentById(id)?.name ?? '— отдел не указан —';

  String categoryName(int? id) => categoryById(id)?.name ?? '— без категории —';

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

  static E? _byId<E>(List<E> items, int? id, int Function(E) idOf) {
    if (id == null) return null;
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }
}
