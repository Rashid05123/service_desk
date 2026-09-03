/// Сотрудник поддержки. Ticket.assigneeId ссылается на Employee.id.
class Employee {
  final int id;
  final String fullName;
  final String position;
  final String department;
  final String email;
  final String phone;

  /// Линия поддержки: 1 — приём обращений, 2 — специалисты, 3 — эксперты.
  final int supportLine;

  final bool isActive;
  final DateTime? deletedAt;

  const Employee({
    required this.id,
    required this.fullName,
    required this.position,
    required this.department,
    required this.email,
    required this.phone,
    required this.supportLine,
    required this.isActive,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Фамилия — первое слово ФИО. Используется в поиске и при сортировке.
  String get lastName => fullName.split(' ').first;

  Employee copyWith({
    String? fullName,
    String? position,
    String? department,
    String? email,
    String? phone,
    int? supportLine,
    bool? isActive,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Employee(
      id: id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      supportLine: supportLine ?? this.supportLine,
      isActive: isActive ?? this.isActive,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
