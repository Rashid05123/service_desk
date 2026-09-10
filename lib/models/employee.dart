import 'entity.dart';

/// Сотрудник поддержки. Две связи наружу: многие к одному с отделом
/// и многие ко многим с категориями — это компетенции, по которым
/// сотрудника можно назначить исполнителем.
class Employee implements Entity<Employee> {
  @override
  final int id;

  final String fullName;
  final String position;

  /// Ссылка на отдел. Многие к одному.
  final int departmentId;

  final String email;
  final String phone;

  /// Линия поддержки: 1 — приём обращений, 2 — специалисты, 3 — эксперты.
  final int supportLine;

  /// Обслуживаемые категории заявок. Многие ко многим: категорию ведут
  /// несколько сотрудников, сотрудник ведёт несколько категорий.
  final List<int> categoryIds;

  final bool isActive;

  @override
  final DateTime? deletedAt;

  /// Число заявок, в которых участвует запись. Приходит с сервера вместе
  /// с ней и служит только для показа; в [toJson] не попадает.
  final int ticketCount;

  const Employee({
    required this.id,
    required this.fullName,
    required this.position,
    required this.departmentId,
    required this.email,
    required this.phone,
    required this.supportLine,
    required this.categoryIds,
    required this.isActive,
    this.deletedAt,
    this.ticketCount = 0,
  });

  bool get isDeleted => deletedAt != null;

  /// Фамилия — первое слово ФИО. Используется в поиске и при сортировке.
  String get lastName => fullName.split(' ').first;

  Employee copyWith({
    String? fullName,
    String? position,
    int? departmentId,
    String? email,
    String? phone,
    int? supportLine,
    List<int>? categoryIds,
    bool? isActive,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Employee(
      id: id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      departmentId: departmentId ?? this.departmentId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      supportLine: supportLine ?? this.supportLine,
      categoryIds: categoryIds ?? this.categoryIds,
      isActive: isActive ?? this.isActive,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Employee withId(int id) => Employee(
    id: id,
    fullName: fullName,
    position: position,
    departmentId: departmentId,
    email: email,
    phone: phone,
    supportLine: supportLine,
    categoryIds: categoryIds,
    isActive: isActive,
    deletedAt: deletedAt,
  );

  @override
  Employee markDeleted(DateTime at) => copyWith(deletedAt: at);

  @override
  Employee restored() => copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'position': position,
    'departmentId': departmentId,
    'email': email,
    'phone': phone,
    'supportLine': supportLine,
    'categoryIds': categoryIds,
    'isActive': isActive,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: Json.asInt(json['id']),
    fullName: Json.asString(json['fullName']),
    position: Json.asString(json['position']),
    // Ссылка приходит развёрнутым объектом, а уходит числом.
    departmentId: Json.refId(json['department'], json['departmentId']),
    email: Json.asString(json['email']),
    phone: Json.asString(json['phone']),
    supportLine: Json.asInt(json['supportLine'], 1),
    categoryIds: Json.refIdList(json['categories'], json['categoryIds']),
    isActive: Json.asBool(json['isActive'], true),
    deletedAt: Json.asDateOrNull(json['deletedAt']),
    ticketCount: Json.asInt(json['ticketCount']),
  );
}
