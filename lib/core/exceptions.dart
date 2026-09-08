/// Ошибки уровня хранилища. Экраны различают их по типу: одну показывают
/// под полем формы, вторую — отдельным сообщением, третью — состоянием
/// «ошибка загрузки».
library;

/// Общий отказ хранилища: записи нет, доступа нет, разбор не удался.
class StorageException implements Exception {
  final String message;

  const StorageException(this.message);

  @override
  String toString() => message;
}

/// Нарушено требование уникальности. Поле [field] совпадает с именем поля
/// формы, поэтому сообщение показывается прямо под ним, а не общей
/// строкой наверху.
class UniqueConstraintException implements Exception {
  final String field;
  final String message;

  const UniqueConstraintException(this.field, this.message);

  @override
  String toString() => message;
}

/// Запись нельзя удалить: на неё ссылаются другие. [dependents] хранит
/// число связанных записей по каждому виду — из него собирается
/// сообщение «на отдел ссылаются 4 сотрудника и 6 заявителей».
class ReferenceConstraintException implements Exception {
  final String subject;
  final Map<String, int> dependents;

  const ReferenceConstraintException(this.subject, this.dependents);

  int get total => dependents.values.fold(0, (sum, value) => sum + value);

  String get details =>
      dependents.entries.map((e) => '${e.value} ${e.key}').join(', ');

  @override
  String toString() => 'Нельзя удалить: $subject. Связанные записи: $details';
}
