import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';
import 'fault_switch.dart';

/// Настроенный клиент HTTP: базовый адрес, таймауты и цепочка
/// интерсепторов. Всё, что относится к сети, собрано здесь, поэтому
/// репозиторию остаются только адреса и разбор тела.
Dio buildDio({FaultSwitch? faults, String? Function()? tokenProvider}) {
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
  // как отказ, отправленный по ветке ошибок. Повтор стоит последним:
  // он должен видеть уже разобранный отказ.
  dio.interceptors.add(_AuthInterceptor(tokenProvider));
  if (faults != null) dio.interceptors.add(_FaultInterceptor(faults));
  dio.interceptors.add(_ErrorInterceptor());
  dio.interceptors.add(_LogInterceptor());
  dio.interceptors.add(_RetryInterceptor(dio));

  return dio;
}

/// Заголовок авторизации. Вход в систему — тема ПР5, поэтому поставщик
/// токена сейчас не задан; место для него подготовлено, чтобы добавление
/// аутентификации не потребовало трогать репозитории.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider);

  final String? Function()? _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider?.call();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
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
