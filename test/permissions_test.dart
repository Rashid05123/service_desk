import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/permissions.dart';
import 'package:service_desk/core/route_guard.dart';
import 'package:service_desk/models/app_user.dart';

/// Логика разграничения прав: матрица ролей, права по адресу
/// и перенаправления маршрутизатора. Всё это чистые функции, поэтому
/// проверяется без запуска приложения.
void main() {
  group('матрица прав', () {
    test('заявитель подаёт обращения, но журнала заявок не видит', () {
      expect(can(Role.requester, Permission.viewOwnTickets), isTrue);
      expect(can(Role.requester, Permission.createOwnTicket), isTrue);
      expect(can(Role.requester, Permission.reopenOwnTicket), isTrue);
      expect(can(Role.requester, Permission.viewTickets), isFalse);
      expect(can(Role.requester, Permission.manageTickets), isFalse);
      expect(can(Role.requester, Permission.manageUsers), isFalse);
    });

    test('специалист обрабатывает заявки, но физически не удаляет', () {
      expect(can(Role.agent, Permission.manageTickets), isTrue);
      expect(can(Role.agent, Permission.manageCategories), isTrue);
      expect(can(Role.agent, Permission.manageRequesters), isTrue);
      expect(can(Role.agent, Permission.hardDelete), isFalse);
      expect(can(Role.agent, Permission.restore), isFalse);
      expect(can(Role.agent, Permission.createOwnTicket), isFalse);
    });

    test('администратор управляет пользователями, но заявки не правит', () {
      expect(can(Role.admin, Permission.manageUsers), isTrue);
      expect(can(Role.admin, Permission.viewStats), isTrue);
      expect(can(Role.admin, Permission.hardDelete), isTrue);
      expect(can(Role.admin, Permission.restore), isTrue);
      expect(can(Role.admin, Permission.manageTickets), isFalse);
      expect(can(Role.admin, Permission.viewQueue), isFalse);
    });

    test('у каждой роли есть право, которого нет ни у одной другой', () {
      for (final role in Role.values) {
        final exclusive = Permission.values.where(
          (p) =>
              can(role, p) &&
              Role.values.where((r) => r != role).every((r) => !can(r, p)),
        );
        expect(exclusive, isNotEmpty, reason: role.label);
      }
    });

    test('без роли нет ни одного права', () {
      for (final permission in Permission.values) {
        expect(can(null, permission), isFalse, reason: permission.code);
      }
      // Неизвестный код роли не превращается в роль «по умолчанию».
      expect(Role.fromCode('superuser'), isNull);
    });

    test('матрица клиента совпадает с матрицей сервера', () {
      // Расхождение означало бы, что кнопка есть, а сервер отвечает 403,
      // или наоборот: кнопки нет, хотя операция разрешена.
      final source = File('api/mock-server.js').readAsStringSync();
      final start = source.indexOf('const ROLE_PERMISSIONS = {');
      final block = source.substring(start, source.indexOf('};', start));

      for (final role in Role.values) {
        final match = RegExp('${role.code}: \\[([^\\]]*)\\]').firstMatch(block);
        expect(match, isNotNull, reason: role.code);
        final serverCodes = RegExp("'([^']+)'")
            .allMatches(match!.group(1)!)
            .map((m) => m.group(1))
            .toSet();
        final clientCodes = rolePermissions[role]!.map((p) => p.code).toSet();
        expect(serverCodes, clientCodes, reason: role.code);
      }
    });
  });

  group('права по адресу', () {
    test('форма требует права изменения, список и карточка — просмотра', () {
      expect(permissionForLocation('/tickets'), Permission.viewTickets);
      expect(permissionForLocation('/tickets/12'), Permission.viewTickets);
      expect(permissionForLocation('/tickets/new'), Permission.manageTickets);
      expect(
        permissionForLocation('/tickets/12/edit?page=2'),
        Permission.manageTickets,
      );
      expect(permissionForLocation('/my/new'), Permission.createOwnTicket);
      expect(permissionForLocation('/admin/stats'), Permission.viewStats);
      expect(permissionForLocation('/'), isNull);
    });

    test('экран каждой роли недоступен остальным ролям', () {
      const exclusive = {
        '/my': Role.requester,
        '/queue': Role.agent,
        '/admin/users': Role.admin,
      };
      exclusive.forEach((path, owner) {
        for (final role in Role.values) {
          expect(canOpen(role, path), role == owner, reason: '$role $path');
        }
      });
    });
  });

  group('перенаправления маршрутизатора', () {
    test('не вошедший уходит на вход, адрес запоминается', () {
      final target = guardRoute(
        loggedIn: false,
        role: null,
        uri: Uri.parse('/tickets/5?search=принтер'),
      );
      final uri = Uri.parse(target!);
      expect(uri.path, '/login');
      // Адрес возврата сохраняется вместе с условиями отбора.
      final from = Uri.parse(uri.queryParameters['from']!);
      expect(from.path, '/tickets/5');
      expect(from.queryParameters['search'], 'принтер');

      expect(
        guardRoute(loggedIn: false, role: null, uri: Uri.parse('/login')),
        isNull,
      );
    });

    test('после входа — на запомненный адрес, но не на чужой сайт', () {
      String? afterLogin(String from) => guardRoute(
        loggedIn: true,
        role: Role.agent,
        uri: Uri(path: '/login', queryParameters: {'from': from}),
      );

      expect(afterLogin('/tickets/5'), '/tickets/5');
      expect(afterLogin('https://evil.example/login'), '/');
      expect(afterLogin('//evil.example'), '/');
    });

    test('вошедший на чужой адрес попадает на экран отказа', () {
      final target = guardRoute(
        loggedIn: true,
        role: Role.requester,
        uri: Uri.parse('/admin/users'),
      );
      final uri = Uri.parse(target!);
      expect(uri.path, '/forbidden');
      expect(uri.queryParameters['from'], '/admin/users');

      expect(
        guardRoute(
          loggedIn: true,
          role: Role.admin,
          uri: Uri.parse('/admin/users'),
        ),
        isNull,
      );
    });
  });
}
