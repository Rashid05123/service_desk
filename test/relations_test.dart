import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/exceptions.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/data/collection_store.dart';
import 'package:service_desk/models/department.dart';
import 'package:service_desk/models/employee.dart';
import 'package:service_desk/models/requester.dart';
import 'package:service_desk/models/service_account.dart';
import 'package:service_desk/repositories/app_repositories.dart';

/// Связи между сущностями: запрет удаления записи, на которую ссылаются,
/// и согласованность начального набора.
void main() {
  late LocalRepositories repositories;

  setUp(() {
    repositories = LocalRepositories(FaultSwitch(), MemoryCollectionStore());
  });

  group('запрет удаления записи, на которую ссылаются', () {
    test('отдел с сотрудниками удалить нельзя, и сказано сколько их', () async {
      // Отдел технической поддержки — тот, где больше всего сотрудников.
      const departmentId = 1;
      final employees = repositories.employees.countByDepartment(departmentId);

      expect(employees, greaterThan(0));
      await expectLater(
        repositories.departments.softDelete(departmentId),
        throwsA(
          isA<ReferenceConstraintException>()
              .having(
                (e) => e.dependents['сотрудников'],
                'сотрудников',
                employees,
              )
              .having((e) => e.total, 'всего ссылок', greaterThan(0)),
        ),
      );
    });

    test('запрет действует и на физическое удаление', () async {
      await expectLater(
        repositories.departments.hardDelete(1),
        throwsA(isA<ReferenceConstraintException>()),
      );
    });

    test('отдел без ссылок удаляется', () async {
      final created = await repositories.departments.create(
        const Department(
          id: 0,
          name: 'Отдел без сотрудников',
          code: 'EMPTY',
          location: 'Корпус Г',
          phone: '+7 495 000-99-99',
        ),
      );

      await repositories.departments.softDelete(created.id);

      expect(
        (await repositories.departments.findById(created.id))!.isDeleted,
        isTrue,
      );
    });

    test('удалённые ссылки не считаются', () async {
      final created = await repositories.departments.create(
        const Department(
          id: 0,
          name: 'Временный отдел',
          code: 'TMP',
          location: 'Корпус Г',
          phone: '+7 495 000-98-98',
        ),
      );
      final requester = await repositories.requesters.create(
        Requester(
          id: 0,
          fullName: 'Тестов Тест Тестович',
          position: 'Специалист',
          departmentId: created.id,
          account: const ServiceAccount(
            login: 'testov.tt',
            email: 'testov@corp.local',
            phone: '+7 495 000-97-97',
            office: 'Корпус Г, каб. 1',
            isBlocked: false,
          ),
          note: '',
        ),
      );

      // Пока заявитель на месте, отдел не удалить.
      await expectLater(
        repositories.departments.softDelete(created.id),
        throwsA(isA<ReferenceConstraintException>()),
      );

      // После удаления заявителя ссылка перестаёт считаться.
      await repositories.requesters.softDelete(requester.id);
      await repositories.departments.softDelete(created.id);

      expect(
        (await repositories.departments.findById(created.id))!.isDeleted,
        isTrue,
      );
    });

    test('категория с заявками и компетенциями удалению не подлежит', () async {
      await expectLater(
        repositories.categories.softDelete(1),
        throwsA(
          isA<ReferenceConstraintException>().having(
            (e) => e.dependents.keys,
            'виды ссылок',
            containsAll(<String>['заявок', 'сотрудников']),
          ),
        ),
      );
    });

    test('сотрудник, участвующий в заявках, удалению не подлежит', () async {
      await expectLater(
        repositories.employees.softDelete(1),
        throwsA(isA<ReferenceConstraintException>()),
      );
    });

    test(
      'множественное удаление отклоняется целиком, а не наполовину',
      () async {
        final before = repositories.departments.rows
            .where((d) => !d.isDeleted)
            .length;

        await expectLater(
          // Отдел 10 (Канцелярия) ссылок не имеет, отдел 1 — имеет.
          repositories.departments.deleteMany([10, 1]),
          throwsA(isA<ReferenceConstraintException>()),
        );

        final after = repositories.departments.rows
            .where((d) => !d.isDeleted)
            .length;
        expect(after, before);
      },
    );
  });

  group('уникальность', () {
    test('адрес почты сотрудника уникален', () async {
      expect(
        () => repositories.employees.create(
          const Employee(
            id: 0,
            fullName: 'Новиков Пётр Ильич',
            position: 'Специалист поддержки',
            departmentId: 1,
            email: 'abramov@sd.local',
            phone: '+7 495 000-10-99',
            supportLine: 1,
            categoryIds: [1],
            isActive: true,
          ),
        ),
        throwsA(
          isA<UniqueConstraintException>().having(
            (e) => e.field,
            'field',
            'email',
          ),
        ),
      );
    });

    test(
      'логин заявителя уникален, и имя поля указывает на вложенное поле',
      () async {
        expect(
          () => repositories.requesters.create(
            Requester(
              id: 0,
              fullName: 'Новиков Пётр Ильич',
              position: 'Специалист',
              departmentId: 5,
              account: const ServiceAccount(
                login: 'semenov.av',
                email: 'novikov@corp.local',
                phone: '+7 495 000-30-99',
                office: 'Корпус Б, каб. 203',
                isBlocked: false,
              ),
              note: '',
            ),
          ),
          throwsA(
            isA<UniqueConstraintException>().having(
              (e) => e.field,
              'field',
              'account.login',
            ),
          ),
        );
      },
    );

    test('код отдела уникален независимо от регистра', () async {
      expect(
        () => repositories.departments.create(
          const Department(
            id: 0,
            name: 'Другой отдел',
            code: 'itsup',
            location: 'Корпус Г',
            phone: '+7 495 000-96-96',
          ),
        ),
        throwsA(
          isA<UniqueConstraintException>().having(
            (e) => e.field,
            'field',
            'code',
          ),
        ),
      );
    });
  });

  group('согласованность начального набора', () {
    test('исполнитель каждой заявки обслуживает её категорию', () {
      for (final ticket in repositories.tickets.rows) {
        final assigneeId = ticket.assigneeId;
        if (assigneeId == null) continue;
        final assignee = repositories.employees.rows.firstWhere(
          (e) => e.id == assigneeId,
        );
        expect(
          assignee.categoryIds,
          contains(ticket.categoryId),
          reason:
              'Заявка ${ticket.number}: исполнитель ${assignee.fullName} '
              'не обслуживает категорию ${ticket.categoryId}',
        );
      }
    });

    test('все ссылки заявок разрешимы', () {
      final categories = repositories.categories.rows.map((c) => c.id).toSet();
      final employees = repositories.employees.rows.map((e) => e.id).toSet();
      final requesters = repositories.requesters.rows.map((r) => r.id).toSet();

      for (final ticket in repositories.tickets.rows) {
        expect(categories, contains(ticket.categoryId));
        expect(requesters, contains(ticket.requesterId));
        for (final id in ticket.involvedEmployeeIds) {
          expect(employees, contains(id));
        }
      }
    });

    test('все сотрудники и заявители привязаны к существующим отделам', () {
      final departments = repositories.departments.rows
          .map((d) => d.id)
          .toSet();

      for (final employee in repositories.employees.rows) {
        expect(departments, contains(employee.departmentId));
      }
      for (final requester in repositories.requesters.rows) {
        expect(departments, contains(requester.departmentId));
      }
    });
  });
}
