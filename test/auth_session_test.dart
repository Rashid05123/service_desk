import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/api_client.dart';
import 'package:service_desk/core/api_exceptions.dart';
import 'package:service_desk/core/config.dart';
import 'package:service_desk/models/app_user.dart';
import 'package:service_desk/repositories/auth_api.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Жизненный цикл сессии: вход, хранение токенов, их обновление
/// и выход. Сервер подменён транспортом, который отвечает заготовками
/// и записывает каждый запрос, — по записи видно, сколько запросов
/// ушло на самом деле и не зациклилось ли обновление токена.
void main() {
  late SharedPreferences prefs;
  late _FakeServer server;
  late Dio dio;
  late AuthNotifier auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = _FakeServer();
    dio = buildDio(session: () => auth);
    dio.httpClientAdapter = server;
    auth = AuthNotifier(prefs, AuthApi(dio));
  });

  Future<void> signIn() async {
    server.on('POST /auth/login', 200, _tokens('a1', 'r1'));
    await auth.login('grigorev', 'grigorev123');
    server.requests.clear();
  }

  test(
    'вход сохраняет токены, запросы уходят с заголовком Authorization',
    () async {
      await signIn();
      server.on('GET /tickets', 200, {'items': []});

      await dio.get<dynamic>('/tickets');

      expect(auth.isAuthenticated, isTrue);
      expect(auth.role, Role.requester);
      expect(prefs.getString(AuthNotifier.kAccess), 'a1');
      expect(prefs.getString(AuthNotifier.kRefresh), 'r1');
      expect(server.requests.single.authorization, 'Bearer a1');
    },
  );

  test('пароль не попадает в хранилище браузера', () async {
    await signIn();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('grigorev123')), reason: key);
    }
  });

  test('после перезагрузки сессия восстанавливается из хранилища', () async {
    await signIn();

    // Новый экземпляр поверх того же хранилища — то же, что перезагрузка.
    final reloaded = AuthNotifier(prefs, AuthApi(dio));
    await reloaded.restore();

    expect(reloaded.isAuthenticated, isTrue);
    expect(reloaded.user?.fullName, 'Григорьев Пётр Петрович');
    expect(reloaded.accessToken, 'a1');
  });

  test('истёкший токен обновляется, запрос повторяется незаметно', () async {
    await signIn();
    server
      ..on('GET /tickets', 401, {'message': 'Требуется вход в систему'})
      ..on('GET /tickets', 200, {'items': []})
      ..on('POST /auth/refresh', 200, _tokens('a2', 'r2'));

    final response = await dio.get<dynamic>('/tickets');

    expect(response.statusCode, 200);
    expect(server.requests.map((r) => r.key), [
      'GET /tickets',
      'POST /auth/refresh',
      'GET /tickets',
    ]);
    expect(server.requests.last.authorization, 'Bearer a2');
    expect(prefs.getString(AuthNotifier.kRefresh), 'r2');
    expect(auth.isAuthenticated, isTrue);
  });

  test('отказ в обновлении завершает сессию без зацикливания', () async {
    await signIn();
    // Сервер отвечает 401 на всё: и на запрос, и на обновление.
    server
      ..on('GET /tickets', 401, {'message': 'Требуется вход в систему'})
      ..on('POST /auth/refresh', 401, {'message': 'Токен недействителен'});

    await expectLater(
      dio.get<dynamic>('/tickets'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<UnauthorizedException>(),
        ),
      ),
    );

    // Ровно два запроса: исходный и одна попытка обновления.
    expect(server.requests.map((r) => r.key), [
      'GET /tickets',
      'POST /auth/refresh',
    ]);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.endReason, SessionEndReason.expired);
    expect(prefs.getString(AuthNotifier.kAccess), isNull);
  });

  test('неверный пароль при входе не запускает обновление токена', () async {
    server.on('POST /auth/login', 401, {
      'message': 'Неверный логин или пароль',
    });

    await expectLater(
      auth.login('grigorev', 'wrong'),
      throwsA(
        isA<UnauthorizedException>().having(
          (e) => e.message,
          'message',
          'Неверный логин или пароль',
        ),
      ),
    );
    expect(server.requests.map((r) => r.key), ['POST /auth/login']);
  });

  test('одновременные ответы 401 дожидаются одного обновления', () async {
    await signIn();
    server
      ..on('GET /tickets', 401, {'message': 'истёк'})
      ..on('GET /tickets', 200, {'items': []})
      ..on('GET /categories', 401, {'message': 'истёк'})
      ..on('GET /categories', 200, {'items': []})
      ..on('POST /auth/refresh', 200, _tokens('a2', 'r2'));

    await Future.wait([
      dio.get<dynamic>('/tickets'),
      dio.get<dynamic>('/categories'),
    ]);

    // Токен обновления одноразовый: второе обновление тем же токеном
    // сервер отклонил бы, и пользователя выбросило бы из системы.
    expect(
      server.requests.where((r) => r.key == 'POST /auth/refresh'),
      hasLength(1),
    );
  });

  test('выход стирает токены и отзывает токен обновления', () async {
    await signIn();
    server.on('POST /auth/logout', 204, null);

    await auth.logout();
    await pumpEventQueue();

    expect(auth.isAuthenticated, isFalse);
    expect(prefs.getString(AuthNotifier.kAccess), isNull);
    expect(prefs.getString(AuthNotifier.kUser), isNull);
    expect(server.requests.single.key, 'POST /auth/logout');
    expect(server.requests.single.body, {'refreshToken': 'r1'});
  });

  test('после долгой неактивности перезагрузка не возвращает сессию', () async {
    await signIn();
    final later = DateTime.now().add(
      inactivityTimeout + const Duration(seconds: 1),
    );

    final reloaded = AuthNotifier(prefs, AuthApi(dio), clock: () => later);
    await reloaded.restore();

    expect(reloaded.isAuthenticated, isFalse);
    expect(reloaded.endReason, SessionEndReason.inactivity);
  });

  test(
    'предельная длительность сессии действует и через перезагрузку',
    () async {
      await signIn();
      // Пользователь активен, но сессия открыта дольше предельного срока.
      final later = DateTime.now().add(sessionMaxDuration);
      await prefs.setString(
        AuthNotifier.kLastActivity,
        later.subtract(const Duration(seconds: 5)).toIso8601String(),
      );

      final reloaded = AuthNotifier(prefs, AuthApi(dio), clock: () => later);
      await reloaded.restore();

      expect(reloaded.isAuthenticated, isFalse);
      expect(reloaded.endReason, SessionEndReason.maxDuration);
    },
  );
}

Map<String, Object?> _tokens(String access, String refresh) => {
  'accessToken': access,
  'refreshToken': refresh,
  'expiresIn': 60,
  'user': {
    'id': 3,
    'username': 'grigorev',
    'fullName': 'Григорьев Пётр Петрович',
    'email': 'grigorev@corp.local',
    'role': 'requester',
    'requester': {'id': 8, 'fullName': 'Григорьев Пётр Петрович'},
  },
};

typedef _Request = ({String key, String? authorization, Object? body});

/// Подменённый сервер: на каждый адрес — очередь заготовленных ответов.
/// Последний ответ в очереди повторяется, пока не придёт новый.
class _FakeServer implements HttpClientAdapter {
  final Map<String, List<(int, Object?)>> _replies = {};
  final List<_Request> requests = [];

  void on(String key, int status, Object? body) {
    _replies.putIfAbsent(key, () => []).add((status, body));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    requests.add((
      key: key,
      authorization: options.headers['Authorization'] as String?,
      body: options.data,
    ));
    // Пауза, чтобы одновременные запросы действительно шли одновременно.
    await Future<void>.delayed(Duration.zero);

    final queue = _replies[key];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"message":"нет заготовки"}', 404);
    }
    final (status, body) = queue.length > 1 ? queue.removeAt(0) : queue.first;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
