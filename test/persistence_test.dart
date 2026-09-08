import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/data/collection_store.dart';
import 'package:service_desk/models/category.dart';
import 'package:service_desk/models/category_query.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/ticket.dart';
import 'package:service_desk/models/ticket_query.dart';
import 'package:service_desk/repositories/category_repository.dart';
import 'package:service_desk/repositories/ticket_repository.dart';

/// Перезагрузка страницы — это создание репозитория заново поверх того же
/// хранилища. Здесь роль localStorage играет карта в памяти.
void main() {
  late MemoryCollectionStore store;
  late FaultSwitch faults;

  setUp(() {
    store = MemoryCollectionStore();
    faults = FaultSwitch();
  });

  Ticket sample(String number) => Ticket(
    id: 0,
    number: number,
    subject: 'Заявка, созданная до перезагрузки',
    description: 'Должна остаться после повторного чтения хранилища',
    categoryId: 2,
    priority: TicketPriority.high,
    status: TicketStatus.inProgress,
    assigneeId: 5,
    coworkerIds: const [2, 9],
    requesterId: 3,
    createdAt: DateTime(2026, 9, 5, 10),
    dueAt: DateTime(2026, 9, 6, 18),
  );

  test('созданная запись переживает пересоздание репозитория', () async {
    final first = PersistentTicketRepository(faults, store);
    final created = await first.create(sample('SD-900001'));

    final second = PersistentTicketRepository(faults, store);
    final restored = await second.findById(created.id);

    expect(restored, isNotNull);
    expect(restored!.number, 'SD-900001');
    expect(restored.coworkerIds, [2, 9]);
    expect(restored.assigneeId, 5);
    expect(restored.dueAt, DateTime(2026, 9, 6, 18));
  });

  test('изменение записи тоже сохраняется', () async {
    final first = PersistentTicketRepository(faults, store);
    final ticket = (await first.findById(1))!;
    await first.update(ticket.copyWith(subject: 'Тема после изменения'));

    final second = PersistentTicketRepository(faults, store);

    expect((await second.findById(1))!.subject, 'Тема после изменения');
  });

  test('логическое удаление сохраняется вместе с отметкой', () async {
    final first = PersistentTicketRepository(faults, store);
    await first.softDelete(2);

    final second = PersistentTicketRepository(faults, store);
    final restored = await second.findById(2);

    expect(restored!.isDeleted, isTrue);
    expect(restored.deletedAt, isNotNull);
  });

  test('физическое удаление сохраняется', () async {
    final first = PersistentTicketRepository(faults, store);
    await first.hardDelete(3);

    final second = PersistentTicketRepository(faults, store);

    expect(await second.findById(3), isNull);
  });

  test('идентификаторы не выдаются повторно после пересоздания', () async {
    final first = PersistentTicketRepository(faults, store);
    final a = await first.create(sample('SD-900002'));

    final second = PersistentTicketRepository(faults, store);
    final b = await second.create(sample('SD-900003'));

    expect(b.id, greaterThan(a.id));
  });

  test('испорченная запись пропускается, остальные читаются', () async {
    final first = PersistentCategoryRepository(faults, store);
    final before = await first.find(const CategoryQuery(size: 50));

    // Так выглядит запись, которую не разобрать: у неё нет ни одного
    // пригодного поля, а id вообще не число.
    final rows = store.read('categories')!;
    rows.add({'id': <String>['сломано']});
    await store.write('categories', rows);

    final second = PersistentCategoryRepository(faults, store);
    final after = await second.find(
      const CategoryQuery(size: 50, includeDeleted: true),
    );

    expect(before.total, greaterThan(0));
    expect(after.total, greaterThan(0));
  });

  test('пустое хранилище заполняется начальным набором', () async {
    final repository = PersistentCategoryRepository(faults, store);
    final page = await repository.find(
      const CategoryQuery(size: 50, includeDeleted: true),
    );

    expect(page.total, greaterThan(0));
    expect(store.read('categories'), isNotNull);
  });

  test('созданная категория сразу видна в списке для форм', () async {
    final repository = PersistentCategoryRepository(faults, store);
    await repository.create(
      const TicketCategory(
        id: 0,
        name: 'Мониторинг',
        description: 'Оповещения систем наблюдения',
        slaHours: 4,
        isActive: true,
      ),
    );

    expect(
      repository.available.any((c) => c.name == 'Мониторинг'),
      isTrue,
    );
  });

  test('условия отбора переживают запись в адрес и разбор обратно', () {
    const query = TicketQuery(
      search: 'принтер',
      categoryId: 5,
      priority: TicketPriority.high,
      status: TicketStatus.waiting,
      assigneeId: 4,
      requesterId: 8,
      sortField: 'dueAt',
      sortAscending: true,
      page: 3,
      size: 25,
      includeDeleted: true,
    );

    final restored = TicketQuery.fromQueryParameters(
      query.toQueryParameters(),
    );

    expect(restored, query);
  });
}
