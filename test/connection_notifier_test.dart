import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/api_client.dart';
import 'package:service_desk/state/connection_notifier.dart';

/// Состояние связи с сервером: кто его меняет и как оно возвращается.
void main() {
  group('состояние связи', () {
    test('отказ переводит в «нет связи» и уведомляет один раз', () {
      final connection = ConnectionNotifier(probe: () async => false);
      addTearDown(connection.dispose);
      var notified = 0;
      connection.addListener(() => notified++);

      expect(connection.isOnline, isTrue);
      connection.reportFailure();
      connection.reportFailure();

      expect(connection.isOnline, isFalse);
      expect(notified, 1);
    });

    test(
      'без связи сервер опрашивается, первый ответ возвращает связь',
      () async {
        var probes = 0;
        final connection = ConnectionNotifier(
          probe: () async => ++probes >= 3,
          probeInterval: const Duration(milliseconds: 10),
        );
        addTearDown(connection.dispose);

        connection.reportFailure();
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(connection.isOnline, isTrue);
        // После возвращения связи опрос прекращается.
        final after = probes;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(probes, after);
      },
    );

    test('на связи проверка по кнопке сервер не беспокоит', () async {
      var probes = 0;
      final connection = ConnectionNotifier(
        probe: () async {
          probes++;
          return true;
        },
      );
      addTearDown(connection.dispose);

      await connection.checkNow();

      expect(probes, 0);
    });
  });

  group('интерсептор связи', () {
    late _ScriptedAdapter adapter;
    late ConnectionNotifier connection;
    late Dio dio;

    setUp(() {
      adapter = _ScriptedAdapter();
      connection = ConnectionNotifier(
        probe: () async => false,
        probeInterval: const Duration(hours: 1),
      );
      dio = buildDio(connection: connection)..httpClientAdapter = adapter;
    });

    tearDown(() => connection.dispose());

    // POST, а не GET: чтение при сетевом сбое повторяется с паузами,
    // а здесь нужен ровно один запрос.
    test('запрос, не дошедший до сервера, — это «нет связи»', () async {
      adapter.offline = true;

      await expectLater(dio.post<dynamic>('/tickets'), throwsA(anything));

      expect(connection.isOnline, isFalse);
    });

    test('ответ с кодом ошибки — это связь, а не её отсутствие', () async {
      connection.reportFailure();
      adapter.offline = false;

      await expectLater(dio.post<dynamic>('/tickets'), throwsA(anything));

      expect(connection.isOnline, isTrue);
    });
  });
}

/// Транспорт, который либо «не дозванивается», либо отвечает 404.
class _ScriptedAdapter implements HttpClientAdapter {
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'сервер выключен',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'Запись не найдена.'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
