import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import 'crud_repository.dart';
import 'stored_repository.dart';

/// Договор доступа к заявкам. Интерфейс описан отдельно от реализации:
/// сейчас за ним локальное хранилище, в ПР4 будет обращение к API.
abstract interface class TicketRepository
    implements CrudRepository<Ticket, TicketQuery> {
  /// Свободный регистрационный номер — подсказка для формы создания.
  /// Выдаётся хранилищем, а не формой: только оно видит все заявки.
  Future<String> nextNumber();
}

/// Синхронные подсчёты и списки доступных записей из договора убраны:
/// по сети их не выполнить одним обращением. Число связанных записей
/// теперь приходит с сервера полем самой записи, а списки для формы
/// собирает кэш справочников. У локальной реализации эти методы
/// остались — на них стоят проверки ПР3.

/// Хранилище заявок поверх localStorage. Порядок операций такой же, как
/// на сервере: отбор, сортировка, вырезка страницы.
class PersistentTicketRepository extends StoredRepository<Ticket>
    implements TicketRepository {
  PersistentTicketRepository(FaultSwitch faults, CollectionStore store)
    : super(
        faults: faults,
        store: store,
        collection: 'tickets',
        seed: seedTickets,
        fromJson: Ticket.fromJson,
      );

  @override
  String describe(Ticket item) => 'заявка ${item.number}';

  /// Номер заявки — поле, которое заполняет пользователь, поэтому его
  /// уникальность проверяется здесь, а не подразумевается.
  @override
  void checkUnique(Ticket item) {
    final duplicate = rows.any(
      (t) =>
          t.id != item.id &&
          t.number.trim().toLowerCase() == item.number.trim().toLowerCase(),
    );
    if (duplicate) {
      throw UniqueConstraintException(
        'number',
        'Заявка с номером ${item.number} уже зарегистрирована',
      );
    }
  }

  @override
  Future<String> nextNumber() async {
    var maxNumber = 0;
    for (final ticket in rows) {
      final digits = ticket.number.replaceAll(RegExp(r'[^0-9]'), '');
      final value = int.tryParse(digits) ?? 0;
      if (value > maxNumber) maxNumber = value;
    }
    return 'SD-${(maxNumber + 1).toString().padLeft(6, '0')}';
  }

  int countByCategory(int categoryId) =>
      rows.where((t) => !t.isDeleted && t.categoryId == categoryId).length;

  int countByEmployee(int employeeId) => rows
      .where((t) => !t.isDeleted && t.involvedEmployeeIds.contains(employeeId))
      .length;

  int countByRequester(int requesterId) =>
      rows.where((t) => !t.isDeleted && t.requesterId == requesterId).length;

  @override
  Future<PageResult<Ticket>> find(TicketQuery query) async {
    await Future.delayed(StoredRepository.latency);
    faults.throwIfEnabled();

    var result = rows
        .where((t) => query.includeDeleted || !t.isDeleted)
        .toList();

    // Поиск по номеру заявки и по теме, регистр не учитывается.
    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result
          .where(
            (t) =>
                t.number.toLowerCase().contains(needle) ||
                t.subject.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.categoryId != null) {
      result = result.where((t) => t.categoryId == query.categoryId).toList();
    }
    if (query.priority != null) {
      result = result.where((t) => t.priority == query.priority).toList();
    }
    if (query.status != null) {
      result = result.where((t) => t.status == query.status).toList();
    }
    if (query.assigneeId != null) {
      // Соисполнители учитываются наравне с исполнителем: связь многие
      // ко многим тоже должна отражаться в отборе.
      result = result
          .where((t) => t.involvedEmployeeIds.contains(query.assigneeId))
          .toList();
    }
    if (query.requesterId != null) {
      result = result.where((t) => t.requesterId == query.requesterId).toList();
    }
    if (query.createdFrom != null) {
      result = result
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
      result = result.where((t) => !t.createdAt.isAfter(upperBound)).toList();
    }

    result.sort((a, b) {
      final compared = switch (query.sortField) {
        'number' => a.number.compareTo(b.number),
        'subject' => a.subject.toLowerCase().compareTo(b.subject.toLowerCase()),
        // Приоритет и статус — по заданному порядку, а не по алфавиту.
        'priority' => a.priority.sortIndex.compareTo(b.priority.sortIndex),
        'status' => a.status.sortIndex.compareTo(b.status.sortIndex),
        'dueAt' => a.dueAt.compareTo(b.dueAt),
        _ => a.createdAt.compareTo(b.createdAt),
      };
      return query.sortAscending ? compared : -compared;
    });

    return PageResult.slice(result, query.page, query.size);
  }
}
