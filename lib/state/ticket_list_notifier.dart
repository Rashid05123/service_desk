import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import '../repositories/ticket_repository.dart';
import 'load_status.dart';

/// Состояние экрана списка заявок: условия отбора, результат выборки
/// и набор выделенных строк.
class TicketListNotifier extends ChangeNotifier {
  TicketListNotifier(this._repository);

  final TicketRepository _repository;

  TicketQuery _query = const TicketQuery();
  PageResult<Ticket> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};

  bool _disposed = false;

  /// Счётчик запросов: при быстром вводе в поиск запросы завершаются
  /// не в том порядке, в котором отправлены.
  int _requestId = 0;

  TicketQuery get query => _query;

  PageResult<Ticket> get result => _result;

  LoadStatus get status => _status;

  String? get error => _error;

  Set<int> get selected => Set.unmodifiable(_selected);

  bool get hasSelection => _selected.isNotEmpty;

  int get selectedCount => _selected.length;

  /// Все ли строки текущей страницы выделены — для флажка в шапке таблицы.
  bool get allOnPageSelected =>
      _result.items.isNotEmpty &&
      _result.items.every((t) => _selected.contains(t.id));

  Future<void> load() async {
    final requestId = ++_requestId;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final page = await _repository.find(_query);
      if (requestId != _requestId) return; // ответ устарел
      _result = page;
      _status = LoadStatus.success;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = 'Не удалось загрузить список заявок: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  /// Применение новых условий отбора. Выделение очищается: после смены
  /// фильтра на экране другие записи.
  Future<void> applyQuery(TicketQuery next) async {
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

  /// Выделить или снять выделение со всех строк текущей страницы.
  void toggleSelectAllOnPage() {
    if (allOnPageSelected) {
      for (final ticket in _result.items) {
        _selected.remove(ticket.id);
      }
    } else {
      for (final ticket in _result.items) {
        _selected.add(ticket.id);
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

  /// Множественное удаление выделенных заявок.
  Future<int> deleteSelected() async {
    final ids = _selected.toList();
    var deleted = 0;
    await _mutate(() async {
      deleted = await _repository.deleteMany(ids);
    });
    _selected.clear();
    return deleted;
  }

  /// Изменяющая операция: выполнить, затем перечитать страницу. После
  /// удаления меняется и состав страницы, и число страниц.
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

  /// Обращение к notifyListeners после dispose приводит к исключению.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
