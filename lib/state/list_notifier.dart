import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../repositories/crud_repository.dart';
import 'load_status.dart';

/// Состояние экрана списка: условия отбора, результат выборки и набор
/// выделенных строк. Обобщён по типу записи и по типу условий, поэтому
/// один и тот же класс обслуживает все пять списков.
class ListNotifier<T, Q extends ListQuery<Q>> extends ChangeNotifier {
  ListNotifier({
    required this.repository,
    required this.idOf,
    required Q initialQuery,
    required this.failureMessage,
  }) : _query = initialQuery;

  final CrudRepository<T, Q> repository;

  /// Идентификатор записи: по нему ведётся набор выделенных строк.
  final int Function(T item) idOf;

  /// Начало сообщения об ошибке загрузки: «Не удалось загрузить …».
  final String failureMessage;

  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  String? _actionError;
  final Set<int> _selected = {};

  bool _disposed = false;

  /// Счётчик запросов: при быстром вводе в поиск запросы завершаются
  /// не в том порядке, в котором отправлены.
  int _requestId = 0;

  Q get query => _query;

  PageResult<T> get result => _result;

  LoadStatus get status => _status;

  String? get error => _error;

  Set<int> get selected => Set.unmodifiable(_selected);

  bool get hasSelection => _selected.isNotEmpty;

  int get selectedCount => _selected.length;

  /// Все ли строки текущей страницы выделены — для флажка в шапке таблицы.
  bool get allOnPageSelected =>
      _result.items.isNotEmpty &&
      _result.items.every((item) => _selected.contains(idOf(item)));

  Future<void> load() async {
    final requestId = ++_requestId;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final page = await repository.find(_query);
      if (requestId != _requestId) return; // ответ устарел
      _result = page;
      _status = LoadStatus.success;
    } catch (e) {
      if (requestId != _requestId) return;
      _error = '$failureMessage: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  /// Применение новых условий отбора. Выделение очищается: после смены
  /// фильтра на экране другие записи.
  Future<void> applyQuery(Q next) async {
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
      for (final item in _result.items) {
        _selected.remove(idOf(item));
      }
    } else {
      for (final item in _result.items) {
        _selected.add(idOf(item));
      }
    }
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  /// Сообщение об отказе последней операции. Читается один раз: экран
  /// показывает его всплывающей строкой и не должен показывать дважды.
  String? takeActionError() {
    final value = _actionError;
    _actionError = null;
    return value;
  }

  Future<bool> softDelete(int id) => _mutate(() => repository.softDelete(id));

  Future<bool> hardDelete(int id) => _mutate(() => repository.hardDelete(id));

  Future<bool> restore(int id) => _mutate(() => repository.restore(id));

  /// Множественное удаление выделенных записей. Возвращает число
  /// удалённых или −1, если операция отклонена.
  Future<int> deleteSelected() async {
    final ids = _selected.toList();
    var deleted = -1;
    final ok = await _mutate(() async {
      deleted = await repository.deleteMany(ids);
    });
    if (!ok) return -1;
    _selected.clear();
    return deleted;
  }

  /// Изменяющая операция: выполнить, затем перечитать страницу. После
  /// удаления меняется и состав страницы, и число страниц.
  ///
  /// Отказ по ссылкам — не сбой хранилища: список остаётся на экране,
  /// пользователь получает объяснение, а не состояние «ошибка».
  Future<bool> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on ReferenceConstraintException catch (e) {
      // Без местоимения: род у «отдела», «категории» и «заявки» разный,
      // и одна формулировка на всех иначе не получается.
      _actionError =
          'Нельзя удалить: ${e.subject}. Связанные записи: ${e.details}.';
      _safeNotify();
      return false;
    } catch (e) {
      _error = 'Операция не выполнена: $e';
      _status = LoadStatus.error;
      _safeNotify();
      return false;
    }
    await load();
    return true;
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
