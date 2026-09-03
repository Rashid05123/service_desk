import 'enums.dart';

/// Заявка в техподдержку. Модель неизменяемая: изменение идёт через
/// copyWith, иначе provider не отличит старое состояние от нового.
class Ticket {
  final int id;

  /// Регистрационный номер вида SD-000012, участвует в поиске.
  final String number;

  final String subject;
  final String description;
  final int categoryId;
  final TicketPriority priority;
  final TicketStatus status;

  /// Исполнитель. `null` — заявка ещё не распределена.
  final int? assigneeId;

  final String requesterName;
  final String requesterDepartment;
  final DateTime createdAt;

  /// Плановый срок решения по SLA.
  final DateTime dueAt;

  /// Отметка логического удаления. `null` — запись активна.
  final DateTime? deletedAt;

  const Ticket({
    required this.id,
    required this.number,
    required this.subject,
    required this.description,
    required this.categoryId,
    required this.priority,
    required this.status,
    required this.assigneeId,
    required this.requesterName,
    required this.requesterDepartment,
    required this.createdAt,
    required this.dueAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Заявка считается просроченной, если срок вышел, а работа не завершена.
  bool get isOverdue =>
      dueAt.isBefore(DateTime.now()) &&
      status != TicketStatus.resolved &&
      status != TicketStatus.closed;

  Ticket copyWith({
    String? number,
    String? subject,
    String? description,
    int? categoryId,
    TicketPriority? priority,
    TicketStatus? status,
    int? assigneeId,
    String? requesterName,
    String? requesterDepartment,
    DateTime? createdAt,
    DateTime? dueAt,
    DateTime? deletedAt,
    // Отдельный флаг вместо null: выражение deletedAt ?? this.deletedAt
    // вернуло бы старую дату, а очистка поля и есть восстановление записи.
    bool clearDeletedAt = false,
    bool clearAssignee = false,
  }) {
    return Ticket(
      id: id,
      number: number ?? this.number,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      requesterName: requesterName ?? this.requesterName,
      requesterDepartment: requesterDepartment ?? this.requesterDepartment,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
