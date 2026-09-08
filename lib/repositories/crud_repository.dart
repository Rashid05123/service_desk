import '../models/page_result.dart';

/// Договор доступа к данным, общий для всех пяти сущностей. Обобщённые
/// экран списка и состояние списка работают только через него, поэтому
/// новая сущность не требует ни нового notifier, ни нового экрана.
///
/// T — тип записи, Q — тип условий отбора.
abstract interface class CrudRepository<T, Q> {
  /// Выборка страницы по условиям отбора.
  Future<PageResult<T>> find(Q query);

  Future<T?> findById(int id);

  Future<T> create(T item);

  Future<T> update(T item);

  /// Логическое удаление: запись получает deletedAt и уходит из выборок.
  Future<void> softDelete(int id);

  /// Физическое удаление: запись стирается безвозвратно.
  Future<void> hardDelete(int id);

  /// Восстановление логически удалённой записи.
  Future<void> restore(int id);

  /// Множественное удаление. Возвращает число фактически удалённых
  /// записей: часть переданных могла быть удалена раньше.
  Future<int> deleteMany(List<int> ids);
}
