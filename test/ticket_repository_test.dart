import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/ticket_query.dart';
import 'package:service_desk/repositories/in_memory_ticket_repository.dart';

/// Проверки отбора, сортировки и постраничного вывода.
///
/// Логика вынесена в репозиторий, поэтому её можно проверить без запуска
/// интерфейса — так же, как проверялась бы реализация поверх сервера.
void main() {
  late InMemoryTicketRepository repository;

  setUp(() => repository = InMemoryTicketRepository(FaultSwitch()));

  group('Отбор', () {
    test('по умолчанию удалённые записи в выборку не попадают', () async {
      final page = await repository.find(const TicketQuery(size: 50));

      expect(page.items.any((t) => t.isDeleted), isFalse);
    });

    test('переключатель показывает удалённые записи', () async {
      final without = await repository.find(const TicketQuery(size: 50));
      final with_ = await repository.find(
        const TicketQuery(size: 50, includeDeleted: true),
      );

      expect(with_.total, greaterThan(without.total));
    });

    test('поиск работает по номеру заявки', () async {
      final page = await repository.find(
        const TicketQuery(search: 'SD-000002'),
      );

      expect(page.total, 1);
      expect(page.items.single.number, 'SD-000002');
    });

    test('поиск работает по теме и не учитывает регистр', () async {
      final page = await repository.find(const TicketQuery(search: 'ПРИНТЕР'));

      expect(page.total, greaterThan(0));
      expect(
        page.items.every((t) => t.subject.toLowerCase().contains('принтер')),
        isTrue,
      );
    });

    test('фильтры комбинируются между собой и с поиском', () async {
      final page = await repository.find(
        const TicketQuery(
          search: 'не',
          categoryId: 2,
          priority: TicketPriority.high,
          size: 50,
        ),
      );

      expect(
        page.items.every(
          (t) =>
              t.categoryId == 2 &&
              t.priority == TicketPriority.high &&
              t.subject.toLowerCase().contains('не'),
        ),
        isTrue,
      );
    });

    test('фильтр по диапазону дат включает верхнюю границу', () async {
      final page = await repository.find(
        TicketQuery(
          createdFrom: DateTime(2026, 8, 5),
          createdTo: DateTime(2026, 8, 5),
          size: 50,
        ),
      );

      // 5 августа созданы SD-000004 (09:30) и SD-000005 (14:20).
      expect(page.total, 2);
    });

    test('несовпадающие условия дают пустой результат, а не ошибку', () async {
      final page = await repository.find(
        const TicketQuery(search: 'такой темы не существует'),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.totalPages, 1);
    });
  });

  group('Сортировка', () {
    test('по приоритету — в порядке важности, а не по алфавиту', () async {
      final page = await repository.find(
        const TicketQuery(
          sortField: 'priority',
          sortAscending: false,
          size: 50,
        ),
      );

      expect(page.items.first.priority, TicketPriority.critical);
      expect(page.items.last.priority, TicketPriority.low);
    });

    test('направление переключается', () async {
      final asc = await repository.find(
        const TicketQuery(sortField: 'number', sortAscending: true, size: 50),
      );
      final desc = await repository.find(
        const TicketQuery(sortField: 'number', sortAscending: false, size: 50),
      );

      expect(asc.items.first.number, desc.items.last.number);
    });
  });

  group('Постраничный вывод', () {
    test(
      'размер страницы соблюдается, общее число не зависит от страницы',
      () async {
        final first = await repository.find(const TicketQuery(size: 10));

        expect(first.items.length, 10);
        expect(first.page, 1);
        expect(first.totalPages, (first.total / 10).ceil());
      },
    );

    test('страницы не пересекаются', () async {
      final first = await repository.find(const TicketQuery(size: 10, page: 1));
      final second = await repository.find(
        const TicketQuery(size: 10, page: 2),
      );

      final firstIds = first.items.map((t) => t.id).toSet();
      final secondIds = second.items.map((t) => t.id).toSet();

      expect(firstIds.intersection(secondIds), isEmpty);
    });

    test(
      'номер страницы больше последней даёт пустой список без исключения',
      () async {
        final page = await repository.find(const TicketQuery(page: 99));

        expect(page.items, isEmpty);
        expect(page.total, greaterThan(0));
      },
    );
  });

  group('Удаление', () {
    test('логическое удаление убирает запись из выборки', () async {
      final before = await repository.find(const TicketQuery(size: 50));

      await repository.softDelete(1);

      final after = await repository.find(const TicketQuery(size: 50));
      expect(after.total, before.total - 1);
      expect(after.items.any((t) => t.id == 1), isFalse);
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

    // Проверка исправления ошибки из раздела 2.4 методических указаний.
    test('deleteMany удаляет все переданные записи', () async {
      final deleted = await repository.deleteMany([1, 2, 3]);

      expect(deleted, 3);

      final page = await repository.find(const TicketQuery(size: 50));
      expect(page.items.any((t) => [1, 2, 3].contains(t.id)), isFalse);
    });

    test('deleteMany не считает уже удалённые записи', () async {
      await repository.softDelete(1);

      final deleted = await repository.deleteMany([1, 2]);

      expect(deleted, 1);
    });

    test('deleteMany пропускает несуществующие идентификаторы', () async {
      final deleted = await repository.deleteMany([1, 9999]);

      expect(deleted, 1);
    });
  });

  group('Отказ хранилища', () {
    test('включённый сбой приводит к исключению', () async {
      final faults = FaultSwitch()..toggle();
      final failing = InMemoryTicketRepository(faults);

      expect(
        () => failing.find(const TicketQuery()),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
