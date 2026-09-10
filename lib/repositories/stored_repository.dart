import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../models/entity.dart';

/// Описание зависимости: как называются ссылающиеся записи и сколько их
/// для заданного идентификатора.
typedef Dependency = ({String label, int Function(int id) count});

/// Общая часть всех репозиториев: чтение начального набора, запись
/// в хранилище после каждого изменения, выдача идентификаторов, оба вида
/// удаления, проверка уникальности и проверка ссылок.
///
/// Специфична для сущности только выборка [find] — она объявлена
/// в CrudRepository и реализуется наследником.
abstract class StoredRepository<T extends Entity<T>> {
  StoredRepository({
    required this.faults,
    required this.store,
    required this.collection,
    required List<T> seed,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    _restore(seed, fromJson);
  }

  /// Учебный переключатель отказа. Наследник дёргает его в своём find.
  final FaultSwitch faults;

  /// Хранилище коллекций: localStorage в приложении, карта в тестах.
  final CollectionStore store;

  /// Имя коллекции в хранилище: 'tickets', 'employees'.
  final String collection;

  /// Записи коллекции. Наследник читает их в find, писать в них напрямую
  /// нельзя: изменение обязано пройти через методы этого класса, иначе
  /// оно не попадёт в хранилище.
  final List<T> rows = [];

  final List<Dependency> _dependencies = [];

  int _nextId = 1;

  /// Задержка, имитирующая обращение к серверу.
  static const Duration latency = Duration(milliseconds: 200);

  /// Первый запуск — начальный набор; иначе разбор сохранённых записей.
  /// Испорченные данные не роняют приложение: хранилище сообщит об этом
  /// само, вернув null.
  void _restore(List<T> seed, T Function(Map<String, dynamic>) fromJson) {
    final saved = store.read(collection);
    if (saved == null) {
      rows.addAll(seed);
      _resetNextId();
      _persist();
      return;
    }

    for (final json in saved) {
      try {
        rows.add(fromJson(json));
      } catch (_) {
        // Одна испорченная запись не должна стоить всей коллекции.
        continue;
      }
    }
    if (rows.isEmpty) rows.addAll(seed);
    _resetNextId();
  }

  void _resetNextId() {
    _nextId = rows.isEmpty
        ? 1
        : rows.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Запись коллекции в хранилище. Вызывается после каждого изменения:
  /// забытый вызов — самая частая причина «данные исчезли после
  /// перезагрузки».
  Future<void> _persist() =>
      store.write(collection, rows.map((e) => e.toJson()).toList());

  /// Объявление зависимости: записи [label] ссылаются на записи этой
  /// коллекции. Проверяется перед удалением.
  void dependsOn(String label, int Function(int id) count) {
    _dependencies.add((label: label, count: count));
  }

  /// Проверка уникальности. Наследник переопределяет и бросает
  /// [UniqueConstraintException] с именем поля формы.
  void checkUnique(T item) {}

  /// Название записи для сообщения об отказе в удалении.
  String describe(T item) => 'запись $item';

  /// Локальная выборка завершается сразу же, отменять нечего.
  void cancelPendingFind() {}

  Future<T?> findById(int id) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    final index = rows.indexWhere((e) => e.id == id);
    return index == -1 ? null : rows[index];
  }

  Future<T> create(T item) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    checkUnique(item);
    // Идентификатор выдаёт хранилище, поэтому copyWith тут не подходит:
    // он сохраняет прежний id.
    final created = item.withId(_nextId++);
    rows.add(created);
    await _persist();
    return created;
  }

  Future<T> update(T item) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    checkUnique(item);
    final index = _indexOrThrow(item.id);
    rows[index] = item;
    await _persist();
    return item;
  }

  Future<void> softDelete(int id) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _checkReferences(rows[index]);
    rows[index] = rows[index].markDeleted(DateTime.now());
    await _persist();
  }

  Future<void> hardDelete(int id) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _checkReferences(rows[index]);
    rows.removeAt(index);
    await _persist();
  }

  Future<void> restore(int id) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    rows[index] = rows[index].restored();
    await _persist();
  }

  Future<int> deleteMany(List<int> ids) async {
    await Future.delayed(latency);
    faults.throwIfEnabled();

    // Сначала проверяются все выбранные записи и только потом удаляется
    // хоть одна: иначе при отказе на середине списка часть записей уже
    // была бы удалена, а пользователь увидел бы только ошибку.
    final targets = <int>[];
    for (final id in ids) {
      final index = rows.indexWhere((e) => e.id == id && e.deletedAt == null);
      if (index == -1) continue;
      _checkReferences(rows[index]);
      targets.add(index);
    }

    final now = DateTime.now();
    for (final index in targets) {
      rows[index] = rows[index].markDeleted(now);
    }
    await _persist();
    return targets.length;
  }

  /// Уже удалённая запись не считается: удаляя отдел, на который
  /// ссылается только удалённый сотрудник, ничего не ломаем.
  void _checkReferences(T item) {
    final found = <String, int>{};
    for (final dependency in _dependencies) {
      final count = dependency.count(item.id);
      if (count > 0) found[dependency.label] = count;
    }
    if (found.isNotEmpty) {
      throw ReferenceConstraintException(describe(item), found);
    }
  }

  int _indexOrThrow(int id) {
    final index = rows.indexWhere((e) => e.id == id);
    if (index == -1) {
      throw StorageException('Запись $id не найдена');
    }
    return index;
  }

  /// Активные записи — без логически удалённых. Из них собираются
  /// выпадающие списки форм.
  List<T> get activeRows => rows.where((e) => e.deletedAt == null).toList();
}
