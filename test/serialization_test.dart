import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/data/seed_data.dart';
import 'package:service_desk/models/category.dart';
import 'package:service_desk/models/department.dart';
import 'package:service_desk/models/employee.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/requester.dart';
import 'package:service_desk/models/ticket.dart';

/// Сериализация — то, чем в ПР4 будет разбираться ответ сервера. Проверок
/// две: значение переживает запись и чтение, и разбор не падает
/// на неполных данных.
void main() {
  group('запись и чтение возвращают ту же запись', () {
    test('заявка', () {
      final original = seedTickets.first;
      final restored = Ticket.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.number, original.number);
      expect(restored.subject, original.subject);
      expect(restored.categoryId, original.categoryId);
      expect(restored.priority, original.priority);
      expect(restored.status, original.status);
      expect(restored.assigneeId, original.assigneeId);
      expect(restored.coworkerIds, original.coworkerIds);
      expect(restored.requesterId, original.requesterId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.dueAt, original.dueAt);
    });

    test('логически удалённая заявка сохраняет отметку удаления', () {
      final deleted = seedTickets.firstWhere((t) => t.isDeleted);
      final restored = Ticket.fromJson(deleted.toJson());

      expect(restored.deletedAt, deleted.deletedAt);
      expect(restored.isDeleted, isTrue);
    });

    test('сотрудник вместе со списком компетенций', () {
      final original = seedEmployees.first;
      final restored = Employee.fromJson(original.toJson());

      expect(restored.fullName, original.fullName);
      expect(restored.departmentId, original.departmentId);
      expect(restored.categoryIds, original.categoryIds);
      expect(restored.isActive, original.isActive);
    });

    test('заявитель вместе с вложенной учётной записью', () {
      final original = seedRequesters.first;
      final restored = Requester.fromJson(original.toJson());

      expect(restored.fullName, original.fullName);
      expect(restored.departmentId, original.departmentId);
      expect(restored.account.login, original.account.login);
      expect(restored.account.email, original.account.email);
      expect(restored.account.isBlocked, original.account.isBlocked);
    });

    test('отдел и категория', () {
      final department = Department.fromJson(seedDepartments.first.toJson());
      final category = TicketCategory.fromJson(seedCategories.first.toJson());

      expect(department.code, seedDepartments.first.code);
      expect(category.slaHours, seedCategories.first.slaHours);
    });
  });

  group('разбор не падает на неполных данных', () {
    test('пустая карта даёт запись со значениями по умолчанию', () {
      final ticket = Ticket.fromJson(const {});

      expect(ticket.id, 0);
      expect(ticket.number, '');
      expect(ticket.priority, TicketPriority.normal);
      expect(ticket.status, TicketStatus.newly);
      expect(ticket.assigneeId, isNull);
      expect(ticket.coworkerIds, isEmpty);
      expect(ticket.deletedAt, isNull);
    });

    test('поля со значением null не роняют разбор', () {
      final employee = Employee.fromJson(const {
        'id': 7,
        'fullName': null,
        'departmentId': null,
        'categoryIds': null,
        'isActive': null,
      });

      expect(employee.id, 7);
      expect(employee.fullName, '');
      expect(employee.departmentId, 0);
      expect(employee.categoryIds, isEmpty);
      expect(employee.isActive, isTrue);
    });

    test('поле другого типа заменяется значением по умолчанию', () {
      // Так выглядит запись, сохранённая прошлой версией модели.
      final ticket = Ticket.fromJson(const {
        'id': '12',
        'categoryId': '3',
        'priority': 2,
        'status': ['closed'],
        'coworkerIds': 'нет',
        'createdAt': 'вчера',
      });

      expect(ticket.id, 12);
      expect(ticket.categoryId, 3);
      expect(ticket.priority, TicketPriority.normal);
      expect(ticket.status, TicketStatus.newly);
      expect(ticket.coworkerIds, isEmpty);
      expect(ticket.createdAt, DateTime(2026));
    });

    test('отсутствующая учётная запись заменяется пустой', () {
      final requester = Requester.fromJson(const {'id': 3});

      expect(requester.account.login, '');
      expect(requester.account.isBlocked, isFalse);
    });
  });
}
