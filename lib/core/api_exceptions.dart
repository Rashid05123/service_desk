/// Исключения предметной области, в которые превращается всё, что
/// приходит из сети.
///
/// Виджеты не должны знать о существовании Dio: смена сетевой библиотеки
/// не обязана трогать экраны. Поэтому между сетевым слоем и остальным
/// приложением стоит этот набор типов, а `DioException` дальше
/// репозитория не выходит.
library;

import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен либо ответ заблокирован
/// политикой доступа с другого источника.
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

/// 401 — не аутентифицирован либо срок действия токена истёк.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

/// 404 — записи нет либо она удалена.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности: на запись ссылаются другие.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — проверка полей на сервере не пройдена.
///
/// Ключи [errors] совпадают с именами полей формы, включая вложенные
/// («account.login»), поэтому сообщение раскладывается по полям без
/// сопоставления вручную.
class ValidationException extends ApiException {
  final Map<String, String> errors;

  const ValidationException(super.message, this.errors);
}

/// 5xx и всё, что не удалось опознать.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

/// Отменённый запрос. Не ошибка: устаревший запрос отменяет само
/// приложение, когда пользователь продолжил набирать в поле поиска.
class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

/// Разбор ответа с кодом ошибки в исключение предметной области.
ApiException mapHttpError(int status, Object? body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;

  return switch (status) {
    400 => ServerException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(message ?? 'Ошибка валидации', {
      if (body is Map && body['errors'] is Map)
        for (final entry in (body['errors'] as Map).entries)
          '${entry.key}': '${entry.value}',
    }),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

/// Разбор отказа Dio.
ApiException mapDioError(DioException e) {
  // Ошибку с кодом 4xx уже разобрал интерсептор и положил в поле error.
  // Без этой проверки ответ 422 придёт в приложение как ServerException,
  // и обработчик `on ValidationException` никогда не сработает.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя.',
    ),

    // Со стороны Dart отказ по политике доступа с другого источника
    // неотличим от выключенного сервера: браузер не отдаёт подробностей.
    // Поэтому подсказка вынесена прямо в текст ошибки.
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. Если сервер запущен, откройте '
      'консоль браузера и проверьте, нет ли там сообщения о CORS.',
    ),

    DioExceptionType.cancel => const CancelledException(),

    DioExceptionType.badResponse => mapHttpError(
      e.response?.statusCode ?? 500,
      e.response?.data,
    ),

    _ => const ServerException(),
  };
}

/// Обёртка обращения к сети: наружу не выходит ни один `DioException`.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
