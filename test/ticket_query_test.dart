import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/ticket_query.dart';

/// Проверки перевода условий отбора в адрес и обратно.
///
/// Это ключевое свойство работы: ссылку на отфильтрованный список должно быть
/// можно отправить коллеге, и у него должен открыться тот же список.
void main() {
  group('TicketQuery — адрес страницы', () {
    test('условия по умолчанию не попадают в адрес', () {
      expect(const TicketQuery().toQueryParameters(), isEmpty);
    });

    test('заданные условия записываются в адрес', () {
      const query = TicketQuery(
        search: 'принтер',
        categoryId: 5,
        priority: TicketPriority.high,
        status: TicketStatus.inProgress,
        sortField: 'dueAt',
        sortAscending: true,
        page: 3,
        size: 25,
        includeDeleted: true,
      );

      expect(query.toQueryParameters(), {
        'search': 'принтер',
        'categoryId': '5',
        'priority': 'high',
        'status': 'in_progress',
        'sort': 'dueAt,asc',
        'page': '3',
        'size': '25',
        'includeDeleted': 'true',
      });
    });

    test('разбор адреса восстанавливает те же условия', () {
      const original = TicketQuery(
        search: 'сеть',
        categoryId: 3,
        priority: TicketPriority.critical,
        assigneeId: 5,
        sortField: 'priority',
        sortAscending: true,
        page: 2,
        size: 50,
      );

      final restored = TicketQuery.fromQueryParameters(
        original.toQueryParameters(),
      );

      expect(restored, original);
    });

    test('дата в адресе переживает разбор', () {
      final original = TicketQuery(createdFrom: DateTime(2026, 8, 5));
      final restored = TicketQuery.fromQueryParameters(
        original.toQueryParameters(),
      );

      expect(restored.createdFrom, DateTime(2026, 8, 5));
    });

    test('неизвестное поле сортировки заменяется значением по умолчанию', () {
      final query = TicketQuery.fromQueryParameters({
        'sort': 'passwordHash,asc',
      });

      expect(query.sortField, 'createdAt');
    });

    test('недопустимый размер страницы заменяется значением по умолчанию', () {
      final query = TicketQuery.fromQueryParameters({'size': '1000'});

      expect(query.size, 10);
    });

    test('нечисловой номер страницы не приводит к исключению', () {
      final query = TicketQuery.fromQueryParameters({'page': 'abc'});

      expect(query.page, 1);
    });

    test('неизвестный код приоритета считается незаданным фильтром', () {
      final query = TicketQuery.fromQueryParameters({'priority': 'urgent'});

      expect(query.priority, isNull);
    });
  });

  group('TicketQuery — copyWith', () {
    test('смена условий отбора возвращает на первую страницу', () {
      const query = TicketQuery(page: 7);

      expect(query.copyWith(search: 'принтер').page, 1);
    });

    test('явный номер страницы сохраняется', () {
      const query = TicketQuery(page: 1);

      expect(query.copyWith(page: 4).page, 4);
    });

    test('передача null сбрасывает фильтр', () {
      const query = TicketQuery(categoryId: 3);

      expect(query.copyWith(categoryId: null).categoryId, isNull);
    });

    test('непереданный параметр остаётся прежним', () {
      const query = TicketQuery(categoryId: 3);

      expect(query.copyWith(search: 'сеть').categoryId, 3);
    });
  });
}
