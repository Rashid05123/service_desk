import 'package:flutter/foundation.dart';

import 'load_status.dart';

/// Состояние экрана карточки. Обобщён по типу записи: у заявки и у
/// сотрудника отличается только функция загрузки.
class DetailNotifier<T> extends ChangeNotifier {
  DetailNotifier(this._loader);

  final Future<T?> Function(int id) _loader;

  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _disposed = false;
  int? _lastId;

  T? get item => _item;

  LoadStatus get status => _status;

  String? get error => _error;

  /// Загрузка прошла, но записи нет. Это не ошибка: адрес могли набрать
  /// руками.
  bool get isMissing => _status == LoadStatus.success && _item == null;

  Future<void> load(int id) async {
    _lastId = id;
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _loader(id);
      if (_lastId != id) return; // пользователь успел открыть другую запись
      _item = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (_lastId != id) return;
      _error = 'Не удалось загрузить запись: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> reload() async {
    final id = _lastId;
    if (id != null) await load(id);
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
