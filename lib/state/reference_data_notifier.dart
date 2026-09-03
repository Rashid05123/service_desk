import 'package:flutter/foundation.dart';

import '../data/seed_data.dart';
import '../models/category.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../repositories/employee_repository.dart';

/// Справочные данные для нескольких экранов: категории, сотрудники для
/// фильтра «Исполнитель», отделы. Загружаются один раз.
class ReferenceDataNotifier extends ChangeNotifier {
  ReferenceDataNotifier(this._employeeRepository);

  final EmployeeRepository _employeeRepository;

  List<Employee> _employees = const [];
  List<String> _departments = const [];
  bool _disposed = false;

  List<TicketCategory> get categories => seedCategories;

  List<Employee> get employees => _employees;

  List<String> get departments => _departments;

  /// Поиск сотрудника по идентификатору.
  Employee? employeeById(int? id) {
    if (id == null) return null;
    for (final employee in _employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  String categoryName(int id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return 'Без категории';
  }

  Future<void> load() async {
    try {
      // Справочник целиком: размер страницы заведомо больше числа записей.
      final page = await _employeeRepository.find(
        const EmployeeQuery(size: 50, includeDeleted: true),
      );
      _employees = page.items;
      _departments = await _employeeRepository.departments();
    } catch (_) {
      // Отказ справочника не должен ломать список заявок.
      _employees = const [];
      _departments = const [];
    }
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
