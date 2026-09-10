/// Общий договор записи справочника. Всё, что нужно обобщённому
/// репозиторию: идентификатор, отметка логического удаления,
/// сериализация и три операции, которые нельзя выразить через copyWith,
/// потому что у каждой модели свой набор полей.
abstract interface class Entity<T> {
  int get id;

  /// Отметка логического удаления. `null` — запись активна.
  DateTime? get deletedAt;

  Map<String, dynamic> toJson();

  /// Копия с присвоенным идентификатором: id выдаёт хранилище.
  T withId(int id);

  /// Копия с отметкой логического удаления.
  T markDeleted(DateTime at);

  /// Копия без отметки — восстановление записи.
  T restored();
}

/// Разбор значений из хранилища. Данные могли быть записаны прошлой
/// версией модели, поэтому ни одно поле не считается обязательным:
/// приведение без запасного значения — самая частая причина падения
/// при чтении JSON.
class Json {
  const Json._();

  static int asInt(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Отличается от [asInt] тем, что отсутствие значения остаётся `null`,
  /// а не превращается в 0: 0 — это несуществующая ссылка.
  static int? asIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String asString(Object? value, [String fallback = '']) {
    if (value is String) return value;
    if (value == null) return fallback;
    return value.toString();
  }

  static bool asBool(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is String) return value == 'true';
    if (value is num) return value != 0;
    return fallback;
  }

  static List<int> asIntList(Object? value) {
    if (value is! List) return const [];
    return value.map(asIntOrNull).whereType<int>().toList();
  }

  /// Время приводится к местному поясу. Хранилище писало дату без
  /// пояса, сервер отдаёт её с суффиксом Z — без приведения одно и то же
  /// время показывалось бы по-разному в зависимости от источника.
  static DateTime? asDateOrNull(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  static DateTime asDate(Object? value, DateTime fallback) =>
      asDateOrNull(value) ?? fallback;

  static Map<String, dynamic> asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  /// Ссылка на другую запись в любом из двух представлений.
  ///
  /// Контракт API различает запись и чтение: на сервер уходит
  /// `categoryId`, а обратно приходит развёрнутый объект `category`.
  /// Модель хранит ссылку числом, поэтому идентификатор берётся из того
  /// представления, которое пришло. Это же позволяет читать записи,
  /// сохранённые в браузере в ПР3.
  static int? refIdOrNull(Object? nested, Object? plain) {
    if (nested is Map) return asIntOrNull(nested['id']);
    return asIntOrNull(plain);
  }

  static int refId(Object? nested, Object? plain, [int fallback = 0]) =>
      refIdOrNull(nested, plain) ?? fallback;

  /// Список ссылок: `coworkers: [{id: 4}]` либо `coworkerIds: [4]`.
  static List<int> refIdList(Object? nested, Object? plain) {
    if (nested is List) {
      return nested
          .map((e) => e is Map ? asIntOrNull(e['id']) : asIntOrNull(e))
          .whereType<int>()
          .toList();
    }
    return asIntList(plain);
  }
}
