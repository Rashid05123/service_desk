/// Учебный переключатель отказа хранилища: пока включён, любой запрос
/// к репозиторию завершается исключением. Нужен, чтобы показать состояние
/// ошибки на данных в памяти.
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

/// Ошибка уровня хранилища.
class StorageException implements Exception {
  final String message;

  const StorageException(this.message);

  @override
  String toString() => message;
}
