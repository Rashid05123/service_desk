import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../data/seed_data.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';
import 'stored_repository.dart';

/// Договор доступа к сотрудникам поддержки.
abstract interface class EmployeeRepository
    implements CrudRepository<Employee, EmployeeQuery> {}

/// Хранилище сотрудников. Отличается от заявок только составом полей,
/// поэтому вся общая часть унаследована от StoredRepository.
class PersistentEmployeeRepository extends StoredRepository<Employee>
    implements EmployeeRepository {
  PersistentEmployeeRepository(FaultSwitch faults, CollectionStore store)
    : super(
        faults: faults,
        store: store,
        collection: 'employees',
        seed: seedEmployees,
        fromJson: Employee.fromJson,
      );

  @override
  String describe(Employee item) => 'сотрудник ${item.fullName}';

  /// Адрес почты — второй уникальный признак после идентификатора.
  @override
  void checkUnique(Employee item) {
    final email = item.email.trim().toLowerCase();
    final duplicate = rows.any(
      (e) => e.id != item.id && e.email.trim().toLowerCase() == email,
    );
    if (duplicate) {
      throw UniqueConstraintException(
        'email',
        'Адрес ${item.email} уже занят другим сотрудником',
      );
    }
  }

  List<Employee> get available => activeRows;

  int countByDepartment(int departmentId) =>
      rows.where((e) => !e.isDeleted && e.departmentId == departmentId).length;

  int countByCategory(int categoryId) => rows
      .where((e) => !e.isDeleted && e.categoryIds.contains(categoryId))
      .length;

  @override
  Future<PageResult<Employee>> find(EmployeeQuery query) async {
    await Future.delayed(StoredRepository.latency);
    faults.throwIfEnabled();

    var result = rows
        .where((e) => query.includeDeleted || !e.isDeleted)
        .toList();

    // Поиск по фамилии и должности — поля, отличные от идентификатора.
    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result
          .where(
            (e) =>
                e.lastName.toLowerCase().contains(needle) ||
                e.position.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.departmentId != null) {
      result = result
          .where((e) => e.departmentId == query.departmentId)
          .toList();
    }
    if (query.categoryId != null) {
      result = result
          .where((e) => e.categoryIds.contains(query.categoryId))
          .toList();
    }
    if (query.supportLine != null) {
      result = result.where((e) => e.supportLine == query.supportLine).toList();
    }
    if (query.onlyActive != null) {
      result = result.where((e) => e.isActive == query.onlyActive).toList();
    }

    result.sort((a, b) {
      final compared = switch (query.sortField) {
        'position' => a.position.toLowerCase().compareTo(
          b.position.toLowerCase(),
        ),
        'supportLine' => a.supportLine.compareTo(b.supportLine),
        'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      };
      return query.sortAscending ? compared : -compared;
    });

    return PageResult.slice(result, query.page, query.size);
  }
}
