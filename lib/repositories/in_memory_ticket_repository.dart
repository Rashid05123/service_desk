import '../core/fault_switch.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import 'ticket_repository.dart';

/// Хранилище заявок на данных в памяти. Порядок операций такой же, как
/// на сервере: отбор, сортировка, вырезка страницы.
class InMemoryTicketRepository implements TicketRepository {
  InMemoryTicketRepository(this._faults);

  final FaultSwitch _faults;

  final List<Ticket> _tickets = [...seedTickets];

  int _nextId =
      seedTickets.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

  /// Задержка, имитирующая обращение к серверу.
  static const _latency = Duration(milliseconds: 350);

  @override
  Future<PageResult<Ticket>> find(TicketQuery query) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();

    var rows = _tickets
        .where((t) => query.includeDeleted || !t.isDeleted)
        .toList();

    // Поиск по номеру заявки и по теме, регистр не учитывается.
    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      rows = rows
          .where(
            (t) =>
                t.number.toLowerCase().contains(needle) ||
                t.subject.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.categoryId != null) {
      rows = rows.where((t) => t.categoryId == query.categoryId).toList();
    }
    if (query.priority != null) {
      rows = rows.where((t) => t.priority == query.priority).toList();
    }
    if (query.status != null) {
      rows = rows.where((t) => t.status == query.status).toList();
    }
    if (query.assigneeId != null) {
      rows = rows.where((t) => t.assigneeId == query.assigneeId).toList();
    }
    if (query.createdFrom != null) {
      rows = rows
          .where((t) => !t.createdAt.isBefore(query.createdFrom!))
          .toList();
    }
    if (query.createdTo != null) {
      // Верхняя граница включает весь день целиком.
      final upperBound = DateTime(
        query.createdTo!.year,
        query.createdTo!.month,
        query.createdTo!.day,
        23,
        59,
        59,
      );
      rows = rows.where((t) => !t.createdAt.isAfter(upperBound)).toList();
    }

    rows.sort((a, b) {
      final result = switch (query.sortField) {
        'number' => a.number.compareTo(b.number),
        'subject' => a.subject.toLowerCase().compareTo(b.subject.toLowerCase()),
        // Приоритет и статус — по заданному порядку, а не по алфавиту.
        'priority' => a.priority.sortIndex.compareTo(b.priority.sortIndex),
        'status' => a.status.sortIndex.compareTo(b.status.sortIndex),
        'dueAt' => a.dueAt.compareTo(b.dueAt),
        _ => a.createdAt.compareTo(b.createdAt),
      };
      return query.sortAscending ? result : -result;
    });

    return PageResult.slice(rows, query.page, query.size);
  }

  @override
  Future<Ticket?> findById(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _tickets.indexWhere((t) => t.id == id);
    return index == -1 ? null : _tickets[index];
  }

  @override
  Future<Ticket> create(Ticket ticket) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final id = _nextId++;
    final created = ticket.copyWith(
      number: 'SD-${id.toString().padLeft(6, '0')}',
      createdAt: DateTime.now(),
    );
    // copyWith сохраняет прежний id, поэтому новый объект собирается явно.
    final withId = Ticket(
      id: id,
      number: created.number,
      subject: created.subject,
      description: created.description,
      categoryId: created.categoryId,
      priority: created.priority,
      status: created.status,
      assigneeId: created.assigneeId,
      requesterName: created.requesterName,
      requesterDepartment: created.requesterDepartment,
      createdAt: created.createdAt,
      dueAt: created.dueAt,
    );
    _tickets.add(withId);
    return withId;
  }

  @override
  Future<Ticket> update(Ticket ticket) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(ticket.id);
    _tickets[index] = ticket;
    return ticket;
  }

  @override
  Future<void> softDelete(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _tickets[index] = _tickets[index].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    _indexOrThrow(id);
    _tickets.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> restore(int id) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();
    final index = _indexOrThrow(id);
    _tickets[index] = _tickets[index].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await Future.delayed(_latency);
    _faults.throwIfEnabled();

    var count = 0;
    for (final id in ids) {
      // В образце указаний здесь было `!b[i].isDeleted`: индексирование
      // самого элемента переменной, объявляемой этой же строкой. Проверять
      // нужно сам элемент.
      final index = _tickets.indexWhere((t) => t.id == id && !t.isDeleted);
      if (index != -1) {
        _tickets[index] = _tickets[index].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }

  int _indexOrThrow(int id) {
    final index = _tickets.indexWhere((t) => t.id == id);
    if (index == -1) {
      throw StorageException('Заявка $id не найдена');
    }
    return index;
  }
}
