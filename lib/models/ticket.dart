import 'entity.dart';
import 'enums.dart';

/// Заявка в техподдержку — центральная сущность. Модель неизменяемая:
/// изменение идёт через copyWith, иначе provider не отличит старое
/// состояние от нового.
///
/// Связи: многие к одному с категорией, исполнителем и заявителем,
/// многие ко многим с сотрудниками-соисполнителями.
class Ticket implements Entity<Ticket> {
  @override
  final int id;

  /// Регистрационный номер вида SD-000012. Уникален, участвует в поиске.
  final String number;

  final String subject;
  final String description;

  /// Ссылка на категорию. Многие к одному.
  final int categoryId;

  final TicketPriority priority;
  final TicketStatus status;

  /// Исполнитель. `null` — заявка ещё не распределена.
  final int? assigneeId;

  /// Соисполнители: сотрудники, подключённые к заявке дополнительно.
  /// Многие ко многим.
  final List<int> coworkerIds;

  /// Ссылка на заявителя. Многие к одному.
  final int requesterId;

  final DateTime createdAt;

  /// Плановый срок решения по SLA.
  final DateTime dueAt;

  /// Отметка логического удаления. `null` — запись активна.
  @override
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
    required this.coworkerIds,
    required this.requesterId,
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

  /// Все сотрудники, участвующие в заявке, — для проверки ссылок
  /// при удалении сотрудника.
  List<int> get involvedEmployeeIds => [?assigneeId, ...coworkerIds];

  Ticket copyWith({
    String? number,
    String? subject,
    String? description,
    int? categoryId,
    TicketPriority? priority,
    TicketStatus? status,
    int? assigneeId,
    List<int>? coworkerIds,
    int? requesterId,
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
      coworkerIds: coworkerIds ?? this.coworkerIds,
      requesterId: requesterId ?? this.requesterId,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  Ticket withId(int id) => Ticket(
    id: id,
    number: number,
    subject: subject,
    description: description,
    categoryId: categoryId,
    priority: priority,
    status: status,
    assigneeId: assigneeId,
    coworkerIds: coworkerIds,
    requesterId: requesterId,
    createdAt: createdAt,
    dueAt: dueAt,
    deletedAt: deletedAt,
  );

  @override
  Ticket markDeleted(DateTime at) => copyWith(deletedAt: at);

  @override
  Ticket restored() => copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'subject': subject,
    'description': description,
    'categoryId': categoryId,
    // Перечисления пишутся кодом, а не индексом: вставка нового значения
    // в середину enum не должна менять смысл уже сохранённых записей.
    'priority': priority.code,
    'status': status.code,
    'assigneeId': assigneeId,
    'coworkerIds': coworkerIds,
    'requesterId': requesterId,
    'createdAt': createdAt.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final createdAt = Json.asDate(json['createdAt'], DateTime(2026));
    return Ticket(
      id: Json.asInt(json['id']),
      number: Json.asString(json['number']),
      subject: Json.asString(json['subject']),
      description: Json.asString(json['description']),
      // Ссылки приходят развёрнутыми объектами, а уходят числами:
      // контракт различает представление на чтение и на запись.
      categoryId: Json.refId(json['category'], json['categoryId']),
      // Приведение через Json.asString: в записи прошлого формата
      // на этом месте мог оказаться не текст, и `as String?` бросил бы
      // исключение вместо возврата значения по умолчанию.
      priority:
          TicketPriority.fromCode(Json.asString(json['priority'])) ??
          TicketPriority.normal,
      status:
          TicketStatus.fromCode(Json.asString(json['status'])) ??
          TicketStatus.newly,
      assigneeId: Json.refIdOrNull(json['assignee'], json['assigneeId']),
      coworkerIds: Json.refIdList(json['coworkers'], json['coworkerIds']),
      requesterId: Json.refId(json['requester'], json['requesterId']),
      createdAt: createdAt,
      dueAt: Json.asDate(json['dueAt'], createdAt),
      deletedAt: Json.asDateOrNull(json['deletedAt']),
    );
  }
}
