import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище коллекций записей. За интерфейсом — localStorage браузера,
/// в тестах — обычная карта в памяти.
abstract interface class CollectionStore {
  /// Прочитанные записи или `null`, если коллекции в хранилище нет:
  /// это первый запуск, и репозиторий возьмёт начальный набор.
  List<Map<String, dynamic>>? read(String collection);

  Future<void> write(String collection, List<Map<String, dynamic>> rows);

  /// Сообщение о смене формата данных. Показывается один раз, после чего
  /// сбрасывается вызовом [consumeNotice].
  String? get notice;

  String? consumeNotice();
}

/// Хранилище поверх shared_preferences. На web пакет пишет в localStorage,
/// поэтому данные переживают перезагрузку вкладки.
class PrefsCollectionStore implements CollectionStore {
  PrefsCollectionStore(this._prefs) {
    _checkSchemaVersion();
  }

  final SharedPreferences _prefs;

  /// Версия формата данных. Меняется, когда меняется состав полей
  /// моделей: записи прошлой версии в браузере пользователя разбираться
  /// уже не будут.
  static const int schemaVersion = 1;

  static const String _versionKey = 'sd.schemaVersion';

  /// Ключ коллекции содержит версию: смена версии сама уводит приложение
  /// на чистые данные, ручная чистка localStorage не нужна.
  static String _keyOf(String collection) => 'sd.v$schemaVersion.$collection';

  String? _notice;

  @override
  String? get notice => _notice;

  @override
  String? consumeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  /// Записи прошлых версий стираются, а пользователю показывается
  /// сообщение — молча терять данные хуже, чем сказать об этом.
  void _checkSchemaVersion() {
    final stored = _prefs.getInt(_versionKey);
    if (stored == schemaVersion) return;

    if (stored != null) {
      _notice =
          'Формат данных изменился (версия $stored → $schemaVersion). '
          'Записи прошлой версии удалены, справочники заполнены заново.';
      for (final key in _prefs.getKeys().toList()) {
        if (key.startsWith('sd.v')) _prefs.remove(key);
      }
    }
    _prefs.setInt(_versionKey, schemaVersion);
  }

  @override
  List<Map<String, dynamic>>? read(String collection) {
    final raw = _prefs.getString(_keyOf(collection));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      // Данные испорчены — начинаем заново, но не роняем приложение.
      _notice =
          'Сохранённые данные не удалось прочитать, справочники '
          'заполнены заново.';
      return null;
    }
  }

  @override
  Future<void> write(String collection, List<Map<String, dynamic>> rows) async {
    await _prefs.setString(_keyOf(collection), jsonEncode(rows));
  }
}

/// Хранилище в памяти: тестам не нужен ни браузер, ни асинхронная
/// инициализация shared_preferences.
class MemoryCollectionStore implements CollectionStore {
  final Map<String, List<Map<String, dynamic>>> _data = {};

  @override
  List<Map<String, dynamic>>? read(String collection) => _data[collection];

  @override
  Future<void> write(String collection, List<Map<String, dynamic>> rows) async {
    _data[collection] = rows;
  }

  @override
  String? get notice => null;

  @override
  String? consumeNotice() => null;
}
