import 'entity.dart';

/// Отдел организации. Сторона «один» в связи один ко многим: на отдел
/// ссылаются и сотрудники поддержки, и заявители.
class Department implements Entity<Department> {
  @override
  final int id;

  final String name;

  /// Короткий код вида ITSUP — им отдел обозначается в узких колонках.
  final String code;

  /// Расположение: корпус и кабинет.
  final String location;

  final String phone;

  @override
  final DateTime? deletedAt;

  /// Счётчики связей приходят с сервера вместе с записью и служат только
  /// для показа. В ПР3 это же число считалось синхронным перебором чужой
  /// коллекции — по сети так нельзя, а отдельный запрос на каждую строку
  /// таблицы означал бы десяток обращений на одну страницу списка.
  /// В [toJson] они не попадают: на запись сервер их не принимает.
  final int employeeCount;
  final int requesterCount;

  const Department({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    required this.phone,
    this.deletedAt,
    this.employeeCount = 0,
    this.requesterCount = 0,
  });

  bool get isDeleted => deletedAt != null;

  Department copyWith({
    String? name,
    String? code,
    String? location,
    String? phone,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Department(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Department withId(int id) => Department(
    id: id,
    name: name,
    code: code,
    location: location,
    phone: phone,
    deletedAt: deletedAt,
  );

  @override
  Department markDeleted(DateTime at) => copyWith(deletedAt: at);

  @override
  Department restored() => copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'location': location,
    'phone': phone,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: Json.asInt(json['id']),
    name: Json.asString(json['name']),
    code: Json.asString(json['code']),
    location: Json.asString(json['location']),
    phone: Json.asString(json['phone']),
    deletedAt: Json.asDateOrNull(json['deletedAt']),
    employeeCount: Json.asInt(json['employeeCount']),
    requesterCount: Json.asInt(json['requesterCount']),
  );
}
