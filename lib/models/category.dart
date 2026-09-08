import 'entity.dart';

/// Категория заявки. Сторона «один» для заявок и одновременно сторона
/// связи многие ко многим с сотрудниками: категория — это компетенция.
class TicketCategory implements Entity<TicketCategory> {
  @override
  final int id;

  final String name;

  final String description;

  /// Норматив решения в часах: из него считается плановый срок заявки.
  final int slaHours;

  final bool isActive;

  @override
  final DateTime? deletedAt;

  const TicketCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.slaHours,
    required this.isActive,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  TicketCategory copyWith({
    String? name,
    String? description,
    int? slaHours,
    bool? isActive,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TicketCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      slaHours: slaHours ?? this.slaHours,
      isActive: isActive ?? this.isActive,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  TicketCategory withId(int id) => TicketCategory(
    id: id,
    name: name,
    description: description,
    slaHours: slaHours,
    isActive: isActive,
    deletedAt: deletedAt,
  );

  @override
  TicketCategory markDeleted(DateTime at) => copyWith(deletedAt: at);

  @override
  TicketCategory restored() => copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'slaHours': slaHours,
    'isActive': isActive,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory TicketCategory.fromJson(Map<String, dynamic> json) => TicketCategory(
    id: Json.asInt(json['id']),
    name: Json.asString(json['name']),
    description: Json.asString(json['description']),
    slaHours: Json.asInt(json['slaHours'], 24),
    isActive: Json.asBool(json['isActive'], true),
    deletedAt: Json.asDateOrNull(json['deletedAt']),
  );
}
