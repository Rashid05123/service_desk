import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../state/connection_notifier.dart';
import 'api_exceptions.dart';
import 'config.dart';
import 'fault_switch.dart';

/// Настроенный клиент HTTP: базовый адрес, таймауты и цепочка
/// интерсепторов. Всё, что относится к сети, собрано здесь, поэтому
/// репозиторию остаются только адреса и разбор тела.
Dio buildDio({
  FaultSwitch? faults,
  AuthSession Function()? session,
  ConnectionNotifier? connection,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Коды 4xx не считаются исключением: их разбирает интерсептор ниже,
      // иначе тело ответа с описанием ошибок полей до нас не дойдёт.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Порядок важен. Разбор ошибок стоит раньше журнала: иначе ответ
  // с кодом 4xx попал бы в журнал дважды — сначала как ответ, потом
  // как отказ, отправленный по ветке ошибок. Обновление токена стоит
  // после журнала, чтобы ответ 401 в журнал попал. Повтор стоит
  // последним: он должен видеть уже разобранный отказ. Состояние связи
  // стоит первым: ему нужен каждый ответ, в том числе с кодом 4xx,
  // до того как разбор ошибок отправит его по ветке отказов.
  if (connection != null) {
    dio.interceptors.add(_ConnectionInterceptor(connection));
  }
  dio.interceptors.add(_AuthInterceptor(session));
  if (faults != null) dio.interceptors.add(_FaultInterceptor(faults));
  dio.interceptors.add(_ErrorInterceptor());
  dio.interceptors.add(_LogInterceptor());
  if (session != null) dio.interceptors.add(_RefreshInterceptor(dio, session));
  dio.interceptors.add(_RetryInterceptor(dio));

  return dio;
}

/// Сессия с точки зрения сетевого слоя: текущий токен, его обновление
/// и завершение сессии. Реализует её `AuthNotifier`; сетевой слой знает
/// только этот договор и ничего не знает о виджетах и хранилище.
abstract interface class AuthSession {
  String? get accessToken;

  /// true — токены обновлены, false — сервер в обновлении отказал.
  Future<bool> refreshTokens();

  /// Завершение сессии после отказа в обновлении.
  Future<void> expire();
}

/// Сообщение о связи с сервером. Любой ответ сервера, даже с кодом
/// ошибки, означает, что связь есть; «связи нет» — только когда ответа
/// не было вовсе.
class _ConnectionInterceptor extends Interceptor {
  _ConnectionInterceptor(this._connection);

  final ConnectionNotifier _connection;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _connection.reportSuccess();
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    if (error.response != null) {
      _connection.reportSuccess();
    } else if (switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    }) {
      _connection.reportFailure();
    }
    handler.next(error);
  }
}

/// Заголовок авторизации на каждый запрос. Сессия передаётся функцией:
/// клиент HTTP создаётся раньше сессии, а сессия сама пользуется им
/// для входа и обновления токена.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._session);

  final AuthSession Function()? _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session?.call().accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

/// Обновление токена при ответе 401 и повтор исходного запроса —
/// прозрачно для экрана, который этот запрос отправил.
///
/// Три условия защищают от бесконечного цикла:
/// * адреса /auth/ не обновляются: неудачный вход с кодом 401 иначе
///   вызвал бы обновление, оно тоже вернуло бы 401, и так без конца;
/// * запрос, уже повторённый после обновления, второй раз не
///   обновляется: если сервер отвечает 401 и на свежий токен, дело
///   не в сроке токена;
/// * отказ в обновлении завершает сессию, а не запускает новую попытку.
class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor(this._dio, this._session);

  final Dio _dio;
  final AuthSession Function() _session;

  static const _afterRefresh = '__afterRefresh';

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final session = _session();

    if (error.response?.statusCode != 401 ||
        options.path.contains('/auth/') ||
        options.extra[_afterRefresh] == true ||
        session.accessToken == null) {
      return handler.next(error);
    }

    // Пока этот запрос шёл, токен мог обновить соседний запрос. Тогда
    // обновлять второй раз незачем — достаточно повторить с новым.
    final sentWith = options.headers['Authorization'];
    final alreadyRefreshed = sentWith != 'Bearer ${session.accessToken}';

    if (!alreadyRefreshed) {
      final bool refreshed;
      try {
        refreshed = await session.refreshTokens();
      } on ApiException {
        // Сеть пропала посреди обновления. Сессия не завершается:
        // экран покажет ошибку, а повтор станет возможен, когда сеть
        // вернётся.
        return handler.next(error);
      }
      if (!refreshed) {
        if (kDebugMode) {
          debugPrint('[API] обновление токена отклонено, сессия завершена');
        }
        await session.expire();
        return handler.next(error);
      }
    }

    options.extra[_afterRefresh] = true;
    if (kDebugMode) debugPrint('[API] повтор после обновления ${options.uri}');
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Учебные переключатели: принудительная ошибка и задержка ответа.
/// Параметры понимает сервер, поэтому приложение получает настоящий
/// ответ с кодом 500, а не подделанное исключение.
class _FaultInterceptor extends Interceptor {
  _FaultInterceptor(this._faults);

  final FaultSwitch _faults;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.queryParameters.addAll(_faults.queryParameters);
    handler.next(options);
  }
}

/// Журнал запросов в режиме отладки: метод, адрес, код ответа
/// и длительность. По нему видно и то, что запрос вообще ушёл,
/// и то, сколько сервер думал.
class _LogInterceptor extends Interceptor {
  static const _startedAt = '__startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAt] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _log(
      error.requestOptions,
      error.response?.statusCode,
      note: error.response == null ? error.type.name : null,
    );
    handler.next(error);
  }

  void _log(RequestOptions options, int? status, {String? note}) {
    if (!kDebugMode) return;
    final startedAt = options.extra[_startedAt];
    final elapsed = startedAt is DateTime
        ? DateTime.now().difference(startedAt).inMilliseconds
        : null;
    debugPrint(
      '[API] ${options.method} ${options.uri} → ${status ?? note ?? '—'}'
      '${elapsed == null ? '' : ' ($elapsed мс)'}',
    );
  }
}

/// Общая обработка ошибок. Коды 4xx приходят сюда в `onResponse` из-за
/// `validateStatus`, а не в `onError`.
class _ErrorInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final status = response.statusCode ?? 0;
    if (status < 400) return handler.next(response);

    // Просто бросить исключение здесь нельзя: Dio перехватит любое
    // исключение из интерсептора и завернёт его в DioException с типом
    // unknown, а разобранное исключение окажется спрятано внутри поля
    // error. Поэтому ответ отправляется по ветке ошибок вручную, вместе
    // с уже готовым исключением предметной области.
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: mapHttpError(status, response.data),
      ),
      true,
    );
  }
}

/// Повтор при сетевом сбое: не более трёх попыток с нарастающей паузой.
///
/// Повторяется только чтение. Повторить создание записи нельзя: первый
/// запрос мог дойти до сервера и быть выполнен, а ответ потеряться —
/// тогда повтор создаст вторую запись.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;

  static const int maxAttempts = 3;
  static const List<Duration> pauses = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 900),
    Duration(milliseconds: 2700),
  ];

  static const _attempt = '__attempt';

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final attempt = (options.extra[_attempt] as int? ?? 0) + 1;

    if (!_isRetryable(error) || attempt >= maxAttempts) {
      return handler.next(error);
    }

    await Future<void>.delayed(pauses[attempt - 1]);
    if (kDebugMode) {
      debugPrint('[API] повтор ${attempt + 1}/$maxAttempts ${options.uri}');
    }

    options.extra[_attempt] = attempt;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isRetryable(DioException error) {
    if (error.requestOptions.method.toUpperCase() != 'GET') return false;
    if (CancelToken.isCancel(error)) return false;

    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      // Пятисотые Dio отдаёт как badResponse: сбой на стороне сервера
      // может быть временным, повторить его безопасно.
      DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }
}
