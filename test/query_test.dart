import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/models/category_query.dart';
import 'package:service_desk/models/department_query.dart';
import 'package:service_desk/models/employee_query.dart';
import 'package:service_desk/models/list_query.dart';
import 'package:service_desk/models/requester_query.dart';
import 'package:service_desk/models/ticket_query.dart';

/// Условия отбора хранятся в адресе страницы, поэтому проверяется и
/// сборка адреса, и разбор — в том числе разбор мусора: присланная
/// ссылка не должна ронять приложение.
void main() {
  group('адрес чистого списка не содержит параметров', () {
    test('у всех пяти сущностей', () {
      expect(const TicketQuery().toQueryParameters(), isEmpty);
      expect(const EmployeeQuery().toQueryParameters(), isEmpty);
      expect(const RequesterQuery().toQueryParameters(), isEmpty);
      expect(const DepartmentQuery().toQueryParameters(), isEmpty);
      expect(const CategoryQuery().toQueryParameters(), isEmpty);
    });
  });

  group('запись и разбор адреса', () {
    test('условия отбора сотрудников', () {
      const query = EmployeeQuery(
        search: 'Волков',
        departmentId: 2,
        categoryId: 3,
        supportLine: 2,
        onlyActive: true,
        sortField: 'email',
        sortAscending: false,
        page: 2,
        size: 50,
        includeDeleted: true,
      );

      expect(
        EmployeeQuery.fromQueryParameters(query.toQueryParameters()),
        query,
      );
    });

    test('условия отбора заявителей', () {
      const query = RequesterQuery(
        search: 'orlov',
        departmentId: 6,
        onlyBlocked: false,
        sortField: 'login',
        sortAscending: false,
        page: 4,
        size: 25,
      );

      expect(
        RequesterQuery.fromQueryParameters(query.toQueryParameters()),
        query,
      );
    });

    test('условия отбора отделов и категорий', () {
      const departments = DepartmentQuery(
        search: 'ITSUP',
        sortField: 'code',
        sortAscending: false,
        size: 25,
      );
      const categories = CategoryQuery(
        search: 'сеть',
        onlyActive: true,
        sortField: 'slaHours',
        page: 2,
      );

      expect(
        DepartmentQuery.fromQueryParameters(departments.toQueryParameters()),
        departments,
      );
      expect(
        CategoryQuery.fromQueryParameters(categories.toQueryParameters()),
        categories,
      );
    });
  });

  group('разбор некорректного адреса', () {
    test('неизвестное поле сортировки заменяется полем по умолчанию', () {
      final query = TicketQuery.fromQueryParameters(const {
        'sort': 'passwordHash,asc',
      });

      expect(query.sortField, 'createdAt');
    });

    test('недопустимый размер страницы заменяется значением по умолчанию', () {
      final query = TicketQuery.fromQueryParameters(const {'size': '1000'});

      expect(query.size, 10);
      expect(TicketQuery.availableSizes, kPageSizes);
    });

    test('номер страницы меньше первой поднимается до первой', () {
      expect(TicketQuery.fromQueryParameters(const {'page': '-3'}).page, 1);
    });

    test('нечисловые идентификаторы становятся незаданным фильтром', () {
      final query = TicketQuery.fromQueryParameters(const {
        'categoryId': 'все',
        'assigneeId': '',
        'priority': 'очень срочно',
      });

      expect(query.categoryId, isNull);
      expect(query.assigneeId, isNull);
      expect(query.priority, isNull);
      expect(query.activeFilterCount, 0);
    });
  });

  group('общий договор списка', () {
    test('изменение фильтра возвращает на первую страницу', () {
      const query = TicketQuery(page: 5);

      expect(query.withSearch('принтер').page, 1);
      expect(query.withSize(25).page, 1);
      expect(query.withIncludeDeleted(true).page, 1);
    });

    test('смена страницы не сбрасывает условия', () {
      const query = TicketQuery(search: 'принтер', categoryId: 3);
      final next = query.withPage(4);

      expect(next.page, 4);
      expect(next.search, 'принтер');
      expect(next.categoryId, 3);
    });

    test('сортировка не сбрасывает номер страницы', () {
      const query = EmployeeQuery(page: 3);
      final next = query.withSort('email', false);

      expect(next.page, 3);
      expect(next.sortField, 'email');
      expect(next.sortAscending, isFalse);
    });

    test('сброс возвращает условия по умолчанию', () {
      const query = CategoryQuery(search: 'сеть', onlyActive: false);

      expect(query.cleared(), const CategoryQuery());
      expect(query.cleared().hasAnyCondition, isFalse);
    });

    test('счётчик фильтров не считает поиск и сортировку', () {
      const query = TicketQuery(
        search: 'принтер',
        sortField: 'dueAt',
        categoryId: 1,
        status: null,
      );

      expect(query.activeFilterCount, 1);
      expect(query.hasAnyCondition, isTrue);
    });
  });
}
