import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/exceptions.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/data/collection_store.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/ticket.dart';
import 'package:service_desk/models/ticket_query.dart';
import 'package:service_desk/repositories/ticket_repository.dart';

/// Отбор, сортировка, постраничный вывод, оба вида удаления
/// и уникальность номера заявки.
void main() {
  late PersistentTicketRepository repository;

  setUp(() {
    repository = PersistentTicketRepository(
      FaultSwitch(),
      MemoryCollectionStore(),
    );
  });

  Ticket sample({String number = 'SD-100001', int categoryId = 1}) => Ticket(
    id: 0,
    number: number,
    subject: 'Проверочная заявка',
    description: 'Создана в тесте',
    categoryId: categoryId,
    priority: TicketPriority.normal,
    status: TicketStatus.newly,
    assigneeId: null,
    coworkerIds: const [],
    requesterId: 1,
    createdAt: DateTime(2026, 9, 1),
    dueAt: DateTime(2026, 9, 2),
  );

  group('выборка', () {
    test('по умолчанию удалённые записи не показываются', () async {
      final page = await repository.find(const TicketQuery(size: 50));

      expect(page.items.every((t) => !t.isDeleted), isTrue);
      expect(page.total, lessThan(repository.rows.length));
    });

    test('includeDeleted возвращает и удалённые', () async {
      final page = await repository.find(
        const TicketQuery(size: 50, includeDeleted: true),
      );

      expect(page.items.any((t) => t.isDeleted), isTrue);
    });

    test('поиск идёт по номеру и по теме', () async {
      final byNumber = await repository.find(
        const TicketQuery(search: 'SD-000002'),
      );
      final bySubject = await repository.find(
        const TicketQuery(search: 'принтер', size: 50),
      );

      expect(byNumber.total, 1);
      expect(bySubject.total, greaterThan(0));
      expect(
        bySubject.items.every(
          (t) => t.subject.toLowerCase().contains('принтер'),
        ),
        isTrue,
      );
    });

    test('фильтры сочетаются между собой', () async {
      final page = await repository.find(
        const TicketQuery(
          categoryId: 1,
          priority: TicketPriority.high,
          size: 50,
        ),
      );

      expect(
        page.items.every(
          (t) => t.categoryId == 1 && t.priority == TicketPriority.high,
        ),
        isTrue,
      );
    });

    test('фильтр по исполнителю учитывает и соисполнителей', () async {
      final page = await repository.find(
        const TicketQuery(assigneeId: 4, size: 50),
      );

      expect(page.total, greaterThan(0));
      expect(
        page.items.every((t) => t.involvedEmployeeIds.contains(4)),
        isTrue,
      );
      // Часть найденного — именно соисполнительство, а не назначение.
      expect(page.items.any((t) => t.assigneeId != 4), isTrue);
    });

    test('диапазон дат включает верхнюю границу целиком', () async {
      final page = await repository.find(
        TicketQuery(
          createdFrom: DateTime(2026, 8, 3),
          createdTo: DateTime(2026, 8, 4),
          size: 50,
        ),
      );

      expect(page.total, 3);
    });

    test('сортировка по убыванию обратна сортировке по возрастанию',
        () async {
      final asc = await repository.find(
        const TicketQuery(sortField: 'number', sortAscending: true, size: 50),
      );
      final desc = await repository.find(
        const TicketQuery(sortField: 'number', sortAscending: false, size: 50),
      );

      expect(asc.items.first.id, desc.items.last.id);
    });

    test('приоритет сортируется по порядку, а не по алфавиту', () async {
      final page = await repository.find(
        const TicketQuery(sortField: 'priority', sortAscending: true, size: 50),
      );

      expect(page.items.first.priority, TicketPriority.low);
      expect(page.items.last.priority, TicketPriority.critical);
    });

    test('страницы не пересекаются и покрывают выборку', () async {
      final first = await repository.find(const TicketQuery(size: 10));
      final second = await repository.find(
        const TicketQuery(size: 10, page: 2),
      );

      expect(first.items.length, 10);
      expect(first.page, 1);
      expect(second.page, 2);
      expect(
        first.items.map((t) => t.id).toSet().intersection(
          second.items.map((t) => t.id).toSet(),
        ),
        isEmpty,
      );
      expect(first.total, second.total);
    });

    test('страница за пределами выборки пуста, но не роняет запрос',
        () async {
      final page = await repository.find(const TicketQuery(page: 99));

      expect(page.items, isEmpty);
      expect(page.total, greaterThan(0));
    });
  });

  group('изменение', () {
    test('создание выдаёт новый идентификатор', () async {
      final before = await repository.find(const TicketQuery(size: 50));
      final created = await repository.create(sample());
      final after = await repository.find(const TicketQuery(size: 50));

      expect(created.id, greaterThan(0));
      expect(after.total, before.total + 1);
    });

    test('повтор номера заявки отклоняется с указанием поля', () async {
      await repository.create(sample(number: 'SD-100001'));

      expect(
        () => repository.create(sample(number: 'SD-100001')),
        throwsA(
          isA<UniqueConstraintException>().having(
            (e) => e.field,
            'field',
            'number',
          ),
        ),
      );
    });

    test('запись сама с собой не конфликтует при изменении', () async {
      final created = await repository.create(sample(number: 'SD-100002'));
      final updated = await repository.update(
        created.copyWith(subject: 'Изменённая тема'),
      );

      expect(updated.subject, 'Изменённая тема');
    });

    test('следующий номер не занят', () async {
      final next = repository.nextNumber();

      expect(repository.rows.any((t) => t.number == next), isFalse);
    });
  });

  group('удаление', () {
    test('логическое удаление убирает запись из выборки, но не из хранилища',
        () async {
      final before = await repository.find(const TicketQuery(size: 50));
      await repository.softDelete(1);
      final after = await repository.find(const TicketQuery(size: 50));
      final withDeleted = await repository.find(
        const TicketQuery(size: 50, includeDeleted: true),
      );

      expect(after.total, before.total - 1);
      expect(withDeleted.items.any((t) => t.id == 1), isTrue);
    });

    test('восстановление возвращает запись в выборку', () async {
      await repository.softDelete(1);
      await repository.restore(1);
      final page = await repository.find(const TicketQuery(size: 50));

      expect(page.items.any((t) => t.id == 1), isTrue);
    });

    test('физическое удаление стирает запись насовсем', () async {
      await repository.hardDelete(1);
      final page = await repository.find(
        const TicketQuery(size: 50, includeDeleted: true),
      );

      expect(page.items.any((t) => t.id == 1), isFalse);
      expect(await repository.findById(1), isNull);
    });

    test('множественное удаление считает только фактически удалённые',
        () async {
      // Заявка 26 удалена в начальном наборе, второй раз не считается.
      final deleted = await repository.deleteMany([1, 2, 26]);

      expect(deleted, 2);
    });
  });

  test('включённый учебный сбой роняет любой запрос', () async {
    final faults = FaultSwitch();
    final faulty = PersistentTicketRepository(faults, MemoryCollectionStore());
    faults.toggle();

    expect(
      () => faulty.find(const TicketQuery()),
      throwsA(isA<StorageException>()),
    );
  });
}
