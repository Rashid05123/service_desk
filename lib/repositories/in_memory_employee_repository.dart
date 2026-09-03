import '../core/fault_switch.dart';
import '../data/seed_data.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/page_result.dart';
import 'employee_repository.dart';

/// Реализация хранилища сотрудников на данных в памяти.
class InMemoryEmployeeRepository implements EmployeeRepository {
  InMemoryEmployeeRepository(this._faults);

  final FaultSwitch _faults;

  final List<Employee> _employees = [...seedEmployees];

  int _nextId =
      seedEmployees.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

  static const _latency = Duration(milliseconds: 300);

  @override
  Future<PageResult<Employee>> find(EmployeeQuery query) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();

    var rows = _employees
        .where((e) => query.includeDeleted || !e.isDeleted)
        .toList();

    // Поиск по фамилии и по отделу — поля, отличные от идентификатора.
    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      rows = rows
          .where(
            (e) =>
                e.lastName.toLowerCase().contains(needle) ||
                e.department.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.department != null) {
      rows = rows.where((e) => e.department == query.department).toList();
    }
    if (query.supportLine != null) {
      rows = rows.where((e) => e.supportLine == query.supportLine).toList();
    }
    if (query.onlyActive != null) {
      rows = rows.where((e) => e.isActive == query.onlyActive).toList();
    }

    rows.sort((a, b) {
      final result = switch (query.sortField) {
        'position' => a.position.toLowerCase().compareTo(
          b.position.toLowerCase(),
        ),
        'department' => a.department.toLowerCase().compareTo(
          b.department.toLowerCase(),
        ),
        'supportLine' => a.supportLine.compareTo(b.supportLine),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      };
      return query.sortAscending ? result : -result;
    });

    return PageResult.slice(rows, query.page, query.size);
  }

  @override
  Future<Employee?> findById(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _employees.indexWhere((e) => e.id == id);
    return index == -1 ? null : _employees[index];
  }

  @override
  Future<Employee> create(Employee employee) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final created = Employee(
      id: _nextId++,
      fullName: employee.fullName,
      position: employee.position,
      department: employee.department,
      email: employee.email,
      phone: employee.phone,
      supportLine: employee.supportLine,
      isActive: employee.isActive,
    );
    _employees.add(created);
    return created;
  }

  @override
  Future<Employee> update(Employee employee) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(employee.id);
    _employees[index] = employee;
    return employee;
  }

  @override
  Future<void> softDelete(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _employees[index] = _employees[index].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    _indexOrThrow(id);
    _employees.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> restore(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _employees[index] = _employees[index].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();

    var count = 0;
    for (final id in ids) {
      final index = _employees.indexWhere((e) => e.id == id && !e.isDeleted);
      if (index != -1) {
        _employees[index] = _employees[index].copyWith(
          deletedAt: DateTime.now(),
        );
        count++;
      }
    }
    return count;
  }

  @override
  Future<List<String>> departments() async {
    // Отделы берутся из самих записей, а не из отдельного справочника.
    final unique = _employees.map((e) => e.department).toSet().toList()..sort();
    return unique;
  }

  int _indexOrThrow(int id) {
    final index = _employees.indexWhere((e) => e.id == id);
    if (index == -1) {
      throw StorageException('Сотрудник $id не найден');
    }
    return index;
  }
}
