import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';

/// Пара токенов и пользователь — ответ на вход и на обновление токена.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;

  /// Срок жизни токена доступа в секундах.
  final int expiresIn;

  final AppUser user;

  static AuthResult parse(Object? data) {
    if (data is Map &&
        data['accessToken'] is String &&
        data['refreshToken'] is String) {
      final user = AppUser.tryParse(data['user']);
      if (user != null) {
        return AuthResult(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          expiresIn: data['expiresIn'] as int? ?? 0,
          user: user,
        );
      }
    }
    throw const ServerException('Сервер вернул ответ неизвестного вида.');
  }
}

/// Адреса /api/auth/*.
///
/// Пароль уходит на сервер как есть. Хешировать его на клиенте
/// бессмысленно: хеш просто стал бы новым паролем, и перехватившему
/// его хватило бы отправить именно хеш. Хеширует сервер.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResult> login(String username, String password) => guard(() async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return AuthResult.parse(response.data);
  });

  Future<AppUser> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
  }) => guard(() async {
    final response = await _dio.post<dynamic>(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'email': email,
      },
    );
    final user = AppUser.tryParse(response.data);
    if (user == null) {
      throw const ServerException('Сервер вернул ответ неизвестного вида.');
    }
    return user;
  });

  Future<AuthResult> refresh(String refreshToken) => guard(() async {
    final response = await _dio.post<dynamic>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResult.parse(response.data);
  });

  Future<AppUser> me() => guard(() async {
    final response = await _dio.get<dynamic>('/auth/me');
    final user = AppUser.tryParse(response.data);
    if (user == null) {
      throw const ServerException('Сервер вернул ответ неизвестного вида.');
    }
    return user;
  });

  /// Отзыв токена обновления на сервере. Токен доступа отозвать нельзя,
  /// он доживает свой короткий срок, поэтому клиент стирает его сам.
  Future<void> logout(String refreshToken) => guard(
    () => _dio.post<dynamic>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    ),
  );
}
