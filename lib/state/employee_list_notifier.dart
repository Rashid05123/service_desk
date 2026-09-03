import 'package:flutter/foundation.dart';

import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/page_result.dart';
import '../repositories/employee_repository.dart';
import 'load_status.dart';

/// Состояние экрана списка сотрудников. Устроено так же, как
/// TicketListNotifier.
class EmployeeListNotifier extends ChangeNotifier {
  EmployeeListNotifier(this._repository);

  final EmployeeRepository _repository;

  EmployeeQuery _query = const EmployeeQuery();
  PageResult<Employee> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};

  bool _disposed = false;
  int _requestId = 0;

  EmployeeQuery get query => _query;

  PageResult<Employee> get result => _result;

  LoadStatus get status => _status;

  String? get error => _error;

  Set<int> get selected => Set.unmodifiable(_selected);

  bool get hasSelection => _selected.isNotEmpty;

  int get selectedCount => _selected.length;

  bool get allOnPageSelected =>
      _result.items.isNotEmpty &&
      _result.items.every((e) => _selected.contains(e.id));

  Future<void> load() async {
    final requestId = ++_requestId;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final page = await _repository.find(_query);
      if (requestId != _requestId) return;
      _result = page;
      _status = LoadStatus.success;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = 'Не удалось загрузить список сотрудников: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(EmployeeQuery next) async {
    if (next == _query && _status != LoadStatus.idle) return;
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _safeNotify();
  }

  void toggleSelectAllOnPage() {
    if (allOnPageSelected) {
      for (final employee in _result.items) {
        _selected.remove(employee.id);
      }
    } else {
      for (final employee in _result.items) {
        _selected.add(employee.id);
      }
    }
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  Future<void> softDelete(int id) => _mutate(() => _repository.softDelete(id));

  Future<void> hardDelete(int id) => _mutate(() => _repository.hardDelete(id));

  Future<void> restore(int id) => _mutate(() => _repository.restore(id));

  Future<int> deleteSelected() async {
    final ids = _selected.toList();
    var deleted = 0;
    await _mutate(() async {
      deleted = await _repository.deleteMany(ids);
    });
    _selected.clear();
    return deleted;
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _error = 'Операция не выполнена: $e';
      _status = LoadStatus.error;
      _safeNotify();
      return;
    }
    await load();
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
