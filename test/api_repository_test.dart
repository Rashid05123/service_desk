import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/api_client.dart';
import 'package:service_desk/core/api_exceptions.dart';
import 'package:service_desk/models/department.dart';
import 'package:service_desk/models/department_query.dart';
import 'package:service_desk/models/enums.dart';
import 'package:service_desk/models/ticket.dart';
import 'package:service_desk/models/ticket_query.dart';
import 'package:service_desk/repositories/api_repositories.dart';

/// Репозитории поверх API с подменённым транспортом.
///
/// Сервер здесь не участвует: подменяется `httpClientAdapter`, и Dio
/// получает ровно тот ответ, который нужен проверке. Так проверяются
/// разбор ответа, сборка запроса и превращение кодов ошибок
/// в исключения предметной области — без запуска сервера и браузера.
void main() {
  late _FakeAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _FakeAdapter();
    dio = buildDio();
    dio.httpClientAdapter = adapter;
  });

  group('разбор ответа', () {
    test(
      'оболочка списка разбирается, ссылки берутся из вложенных объектов',
      () async {
        adapter.reply(200, {
          'items': [
            {
              'id': 7,
              'number': 'SD-000007',
              'subject': 'Не печатает принтер',
              'description': 'Очередь печати не двигается',
              // Сервер отдаёт развёрнутые объекты, а модель хранит числа.
              'category': {'id': 3, 'name': 'Печать'},
              'priority': 'high',
              'status': 'in_progress',
              'assignee': {'id': 5, 'fullName': 'Дорохов А. В.'},
              'coworkers': [
                {'id': 4, 'fullName': 'Гордеева М. И.'},
                {'id': 9, 'fullName': 'Титов С. С.'},
              ],
              'requester': {'id': 2, 'fullName': 'Ковалёва И. П.'},
              'createdAt': '2026-08-03T09:12:00Z',
              'dueAt': '2026-08-05T18:00:00Z',
              'deletedAt': null,
            },
          ],
          'page': 2,
          'size': 10,
          'total': 137,
          'totalPages': 14,
        });

        final page = await ApiTicketRepository(dio).find(const TicketQuery());

        expect(page.total, 137);
        expect(page.page, 2);
        expect(page.totalPages, 14);

        final ticket = page.items.single;
        expect(ticket.categoryId, 3);
        expect(ticket.assigneeId, 5);
        expect(ticket.coworkerIds, [4, 9]);
        expect(ticket.requesterId, 2);
      },
    );

    test(
      'счётчик связей приходит с записью, а не считается на клиенте',
      () async {
        adapter.reply(200, {
          'items': [
            {
              'id': 1,
              'name': 'Отдел технической поддержки',
              'code': 'ITSUP',
              'location': 'Корпус А, каб. 104',
              'phone': '+7 495 000-10-00',
              'deletedAt': null,
              'employeeCount': 6,
              'requesterCount': 2,
            },
          ],
          'page': 1,
          'size': 10,
          'total': 1,
        });

        final page = await ApiDepartmentRepository(dio)
            .find(const DepartmentQuery());

        final department = page.items.single;
        expect(department.employeeCount, 6);
        expect(department.requesterCount, 2);
      },
    );

    test('пропущенные поля ответа не роняют разбор', () async {
      // Оболочка без items, page и total: ответ приходит из внешнего
      // источника, и его состав гарантировать нельзя.
      adapter.reply(200, <String, dynamic>{});

      final page = await ApiDepartmentRepository(dio)
          .find(const DepartmentQuery(size: 25));

      expect(page.items, isEmpty);
      expect(page.page, 1);
      expect(page.size, 25);
      expect(page.total, 0);
    });
  });

  group('сборка запроса', () {
    test('условия отбора уходят параметрами строки запроса', () async {
      adapter.reply(200, {'items': [], 'page': 3, 'size': 25, 'total': 0});

      await ApiTicketRepository(dio).find(
        const TicketQuery(
          search: 'принтер',
          categoryId: 3,
          page: 3,
          size: 25,
          sortField: 'dueAt',
          sortAscending: false,
        ),
      );

      final sent = adapter.lastRequest!;
      expect(sent.path, '/tickets');
      expect(sent.queryParameters['search'], 'принтер');
      expect(sent.queryParameters['categoryId'], '3');
      // Страница, её размер и сортировка передаются всегда, даже когда
      // совпадают со значениями по умолчанию.
      expect(sent.queryParameters['page'], 3);
      expect(sent.queryParameters['size'], 25);
      expect(sent.queryParameters['sort'], 'dueAt,desc');
    });

    test(
      'на запись уходят идентификаторы связей, а не развёрнутые объекты',
      () async {
        adapter.reply(201, {'id': 27, 'number': 'SD-000027'});

        await ApiTicketRepository(dio).create(
          Ticket(
            id: 0,
            number: 'SD-000027',
            subject: 'Тема обращения',
            description: 'Описание обращения',
            categoryId: 3,
            priority: TicketPriority.high,
            status: TicketStatus.newly,
            assigneeId: 5,
            coworkerIds: const [4, 9],
            requesterId: 2,
            createdAt: DateTime(2026, 8, 3),
            dueAt: DateTime(2026, 8, 5),
          ),
        );

        final body = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(body['categoryId'], 3);
        expect(body['assigneeId'], 5);
        expect(body['coworkerIds'], [4, 9]);
        expect(body['requesterId'], 2);
        expect(body.containsKey('category'), isFalse);
      },
    );
  });

  group('коды ошибок превращаются в исключения предметной области', () {
    test('422 — ошибки по именам полей формы, включая вложенные', () async {
      adapter.reply(422, {
        'message': 'Ошибка валидации',
        'errors': {
          'number': 'Заявка с номером SD-000001 уже зарегистрирована',
          'account.login': 'Логин уже занят',
        },
      });

      await expectLater(
        ApiTicketRepository(dio).find(const TicketQuery()),
        throwsA(
          isA<ValidationException>()
              .having(
                (e) => e.errors['number'],
                'ошибка поля номера',
                'Заявка с номером SD-000001 уже зарегистрирована',
              )
              .having(
                (e) => e.errors['account.login'],
                'ошибка вложенного поля',
                'Логин уже занят',
              ),
        ),
      );
    });

    test('409 — конфликт с сообщением сервера', () async {
      adapter.reply(409, {
        'message':
            'Нельзя удалить: отдел «Отдел технической поддержки». '
            'Связанные записи: 6 сотрудников',
      });

      await expectLater(
        ApiDepartmentRepository(dio).softDelete(1),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'сообщение',
            contains('6 сотрудников'),
          ),
        ),
      );
    });

    test('404 при чтении записи — это null, а не состояние ошибки', () async {
      adapter.reply(404, {'message': 'Запись 999 не найдена'});

      final found = await ApiDepartmentRepository(dio).findById(999);

      expect(found, isNull);
    });

    test('сервер недоступен — сообщение с подсказкой про CORS', () async {
      adapter.failWith(
        (options) => DioException.connectionError(
          requestOptions: options,
          reason: 'соединение не установлено',
        ),
      );

      await expectLater(
        ApiDepartmentRepository(dio).find(const DepartmentQuery()),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'сообщение',
            contains('CORS'),
          ),
        ),
      );
    });

    test('DioException наружу не выходит ни в одном случае', () async {
      adapter.reply(500, {'message': 'Внутренняя ошибка сервера'});

      Object? thrown;
      try {
        await ApiDepartmentRepository(dio).create(
          const Department(
            id: 0,
            name: 'Новый отдел',
            code: 'NEW',
            location: 'Корпус Б',
            phone: '+7 495 000-00-00',
          ),
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<ApiException>());
      expect(thrown, isNot(isA<DioException>()));
    });
  });

  group('повтор и отмена', () {
    test('чтение повторяется при сетевом сбое, запись — никогда', () async {
      adapter.failWith(
        (options) => DioException.connectionError(
          requestOptions: options,
          reason: 'соединение не установлено',
        ),
      );

      await expectLater(
        ApiDepartmentRepository(dio).find(const DepartmentQuery()),
        throwsA(isA<NetworkException>()),
      );
      // Три попытки: исходная и два повтора.
      expect(adapter.callCount, 3);

      adapter.callCount = 0;
      await expectLater(
        ApiDepartmentRepository(dio).create(
          const Department(
            id: 0,
            name: 'Новый отдел',
            code: 'NEW',
            location: 'Корпус Б',
            phone: '+7 495 000-00-00',
          ),
        ),
        throwsA(isA<NetworkException>()),
      );
      // Повтор создания записи создал бы вторую: первый запрос мог дойти
      // до сервера, а потеряться мог именно ответ.
      expect(adapter.callCount, 1);
    });

    test('устаревшая выборка отменяется и результата не приносит', () async {
      adapter.reply(200, {
        'items': [],
        'page': 1,
        'size': 10,
        'total': 0,
      }, delay: const Duration(milliseconds: 200));

      final repository = ApiDepartmentRepository(dio);
      final stale = repository.find(const DepartmentQuery(search: 'при'));

      repository.cancelPendingFind();

      await expectLater(stale, throwsA(isA<CancelledException>()));
    });
  });
}

/// Подменённый транспорт Dio: отвечает заготовленным ответом и запоминает
/// последний запрос.
class _FakeAdapter implements HttpClientAdapter {
  int _status = 200;
  Object? _payload;
  Duration _delay = Duration.zero;
  DioException Function(RequestOptions options)? _failure;

  RequestOptions? lastRequest;
  int callCount = 0;

  void reply(int status, Object payload, {Duration delay = Duration.zero}) {
    _status = status;
    _payload = payload;
    _delay = delay;
    _failure = null;
  }

  void failWith(DioException Function(RequestOptions options) failure) {
    _failure = failure;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    callCount++;

    if (_delay > Duration.zero) await Future<void>.delayed(_delay);

    final failure = _failure;
    if (failure != null) throw failure(options);

    return ResponseBody.fromString(
      jsonEncode(_payload),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
