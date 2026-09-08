import 'exceptions.dart';

/// Учебный переключатель отказа хранилища: пока включён, любой запрос
/// к репозиторию завершается исключением. Нужен, чтобы показать состояние
/// ошибки на локальных данных.
class FaultSwitch {
  bool _enabled = false;

  bool get enabled => _enabled;

  void toggle() => _enabled = !_enabled;

  /// Вызывается репозиторием перед выполнением операции.
  void throwIfEnabled() {
    if (_enabled) {
      throw const StorageException('Хранилище недоступно');
    }
  }
}
