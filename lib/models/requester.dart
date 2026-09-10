import 'entity.dart';
import 'service_account.dart';

/// Заявитель — сотрудник организации, обратившийся в поддержку.
/// Многие к одному с отделом и один к одному с учётной записью.
class Requester implements Entity<Requester> {
  @override
  final int id;

  final String fullName;

  final String position;

  final int departmentId;

  /// Вложенная сущность связи один к одному.
  final ServiceAccount account;

  final String note;

  @override
  final DateTime? deletedAt;

  /// Число заявок, в которых участвует запись. Приходит с сервера вместе
  /// с ней и служит только для показа; в [toJson] не попадает.
  final int ticketCount;

  const Requester({
    required this.id,
    required this.fullName,
    required this.position,
    required this.departmentId,
    required this.account,
    required this.note,
    this.deletedAt,
    this.ticketCount = 0,
  });

  bool get isDeleted => deletedAt != null;

  /// Фамилия — первое слово ФИО. Используется в поиске и при сортировке.
  String get lastName => fullName.split(' ').first;

  Requester copyWith({
    String? fullName,
    String? position,
    int? departmentId,
    ServiceAccount? account,
    String? note,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Requester(
      id: id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      departmentId: departmentId ?? this.departmentId,
      account: account ?? this.account,
      note: note ?? this.note,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Requester withId(int id) => Requester(
    id: id,
    fullName: fullName,
    position: position,
    departmentId: departmentId,
    account: account,
    note: note,
    deletedAt: deletedAt,
  );

  @override
  Requester markDeleted(DateTime at) => copyWith(deletedAt: at);

  @override
  Requester restored() => copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'position': position,
    'departmentId': departmentId,
    'account': account.toJson(),
    'note': note,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Requester.fromJson(Map<String, dynamic> json) => Requester(
    id: Json.asInt(json['id']),
    fullName: Json.asString(json['fullName']),
    position: Json.asString(json['position']),
    departmentId: Json.refId(json['department'], json['departmentId']),
    // Вложенный объект тоже может отсутствовать: разбор идёт через
    // asMap, а не приведением к Map<String, dynamic> напрямую.
    account: ServiceAccount.fromJson(Json.asMap(json['account'])),
    note: Json.asString(json['note']),
    deletedAt: Json.asDateOrNull(json['deletedAt']),
    ticketCount: Json.asInt(json['ticketCount']),
  );
}
