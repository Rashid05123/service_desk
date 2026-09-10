import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../data/seed_data.dart';
import '../models/department.dart';
import '../models/department_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';
import 'stored_repository.dart';

/// Договор доступа к отделам.
abstract interface class DepartmentRepository
    implements CrudRepository<Department, DepartmentQuery> {}

/// Хранилище отделов. Сторона «один» связи один ко многим, поэтому именно
/// здесь срабатывает запрет удаления записи, на которую ссылаются.
class PersistentDepartmentRepository extends StoredRepository<Department>
    implements DepartmentRepository {
  PersistentDepartmentRepository(FaultSwitch faults, CollectionStore store)
    : super(
        faults: faults,
        store: store,
        collection: 'departments',
        seed: seedDepartments,
        fromJson: Department.fromJson,
      );

  @override
  String describe(Department item) => 'отдел «${item.name}»';

  @override
  void checkUnique(Department item) {
    final name = item.name.trim().toLowerCase();
    final code = item.code.trim().toUpperCase();

    if (rows.any(
      (d) => d.id != item.id && d.name.trim().toLowerCase() == name,
    )) {
      throw UniqueConstraintException(
        'name',
        'Отдел с названием «${item.name}» уже есть в справочнике',
      );
    }
    if (rows.any(
      (d) => d.id != item.id && d.code.trim().toUpperCase() == code,
    )) {
      throw UniqueConstraintException(
        'code',
        'Код ${item.code} уже занят другим отделом',
      );
    }
  }

  List<Department> get available => activeRows;

  @override
  Future<PageResult<Department>> find(DepartmentQuery query) async {
    await Future.delayed(StoredRepository.latency);
    faults.throwIfEnabled();

    var result = rows
        .where((d) => query.includeDeleted || !d.isDeleted)
        .toList();

    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result
          .where(
            (d) =>
                d.name.toLowerCase().contains(needle) ||
                d.code.toLowerCase().contains(needle),
          )
          .toList();
    }

    result.sort((a, b) {
      final compared = switch (query.sortField) {
        'code' => a.code.compareTo(b.code),
        'location' => a.location.toLowerCase().compareTo(
          b.location.toLowerCase(),
        ),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return query.sortAscending ? compared : -compared;
    });

    return PageResult.slice(result, query.page, query.size);
  }
}
