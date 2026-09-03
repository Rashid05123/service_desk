import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/models/employee_query.dart';
import 'package:service_desk/repositories/in_memory_employee_repository.dart';

/// Проверки второй сущности. Набор намеренно повторяет проверки заявок:
/// оба репозитория обязаны вести себя одинаково.
void main() {
  late InMemoryEmployeeRepository repository;

  setUp(() => repository = InMemoryEmployeeRepository(FaultSwitch()));

  test('в справочнике не менее восьми записей', () async {
    final page = await repository.find(const EmployeeQuery(size: 50));

    expect(page.total, greaterThanOrEqualTo(8));
  });

  test('поиск работает по фамилии', () async {
    final page = await repository.find(const EmployeeQuery(search: 'Волков'));

    expect(page.total, 1);
    expect(page.items.single.fullName, contains('Волков'));
  });

  test('поиск работает по отделу', () async {
    final page = await repository.find(
      const EmployeeQuery(search: 'разработки', size: 50),
    );

    expect(page.total, greaterThan(0));
    expect(
      page.items.every((e) => e.department.contains('разработки')),
      isTrue,
    );
  });

  test('фильтр по линии поддержки сочетается с фильтром по отделу', () async {
    final page = await repository.find(
      const EmployeeQuery(
        department: 'Отдел технической поддержки',
        supportLine: 1,
        size: 50,
      ),
    );

    expect(
      page.items.every(
        (e) =>
            e.department == 'Отдел технической поддержки' && e.supportLine == 1,
      ),
      isTrue,
    );
    expect(page.total, greaterThan(0));
  });

  test('сортировка по ФИО по убыванию обратна возрастанию', () async {
    final asc = await repository.find(const EmployeeQuery(size: 50));
    final desc = await repository.find(
      const EmployeeQuery(size: 50, sortAscending: false),
    );

    expect(asc.items.first.id, desc.items.last.id);
  });

  test('список отделов не содержит повторов', () async {
    final departments = await repository.departments();

    expect(departments.length, departments.toSet().length);
  });

  test('deleteMany удаляет все переданные записи', () async {
    final deleted = await repository.deleteMany([1, 2]);

    expect(deleted, 2);
  });
}
