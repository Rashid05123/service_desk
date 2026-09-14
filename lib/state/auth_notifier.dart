import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../core/permissions.dart' as permissions;
import '../models/app_user.dart';
import '../repositories/auth_api.dart';

/// Почему сессия завершилась. Причину показывает экран входа: человек,
/// которого выбросило из системы, должен понимать, что произошло.
enum SessionEndReason {
  signedOut,
  inactivity,
  maxDuration,
  expired;

  String get message => switch (this) {
    signedOut => 'Вы вышли из системы.',
    inactivity =>
      'Сессия завершена: не было действий дольше '
          '${_duration(inactivityTimeout)}. Войдите снова.',
    maxDuration =>
      'Сессия завершена: истёк предельный срок работы без повторного '
          'входа (${_duration(sessionMaxDuration)}). Войдите снова.',
    expired =>
      'Срок действия входа истёк, обновить его не удалось. '
          'Войдите снова.',
  };

  static String _duration(Duration value) {
    if (value.inHours >= 1 && value.inMinutes % 60 == 0) {
      return '${value.inHours} ч';
    }
    if (value.inMinutes >= 1 && value.inSeconds % 60 == 0) {
      return '${value.inMinutes} мин';
    }
    return '${value.inSeconds} с';
  }
}

/// Сессия пользователя: вход, выход, хранение токенов, их обновление
/// и сроки сессии.
///
/// Токены лежат в shared_preferences, то есть в localStorage браузера,
/// и видны пользователю в DevTools. Для токенов это допустимо: токен
/// доступа и так уходит в каждом запросе и живёт недолго. Пароль сюда
/// не пишется никогда.
///
/// Пользователь тоже сохраняется — чтобы после перезагрузки страницы
/// сразу нарисовать интерфейс, не дожидаясь ответа сервера. Роль из этой
/// записи решает только то, что показать. Разрешить операцию или нет,
/// решает сервер по токену, и правка записи в DevTools этого не меняет.
class AuthNotifier extends ChangeNotifier implements AuthSession {
  AuthNotifier(this._prefs, this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const kAccess = 'auth_access_token';
  static const kRefresh = 'auth_refresh_token';
  static const kUser = 'auth_user';
  static const kStartedAt = 'auth_session_started_at';
  static const kLastActivity = 'auth_last_activity_at';

  final SharedPreferences _prefs;
  final AuthApi _api;
  final DateTime Function() _clock;

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _startedAt;
  SessionEndReason? _endReason;

  /// Незавершённое обновление токена. Пять запросов списка, получивших
  /// 401 одновременно, должны дождаться одного обновления, а не отправить
  /// пять: токен обновления одноразовый, и второе обновление тем же
  /// токеном сервер отклонит — пользователя выбросило бы из системы.
  Future<bool>? _refreshing;

  /// Время последней записи отметки активности: пишется не чаще раза
  /// в несколько секунд, иначе каждое движение мыши писало бы в хранилище.
  DateTime? _activityWrittenAt;

  AppUser? get user => _user;

  @override
  String? get accessToken => _accessToken;

  bool get isAuthenticated => _user != null && _accessToken != null;

  Role? get role => _user?.role;

  DateTime? get sessionStartedAt => _startedAt;

  /// Причина последнего завершения сессии; сбрасывается при входе.
  SessionEndReason? get endReason => _endReason;

  bool can(permissions.Permission permission) =>
      permissions.can(role, permission);

  /// Восстановление сессии при запуске приложения. Вызывается один раз
  /// до построения дерева виджетов: иначе маршрутизатор успел бы
  /// отправить вошедшего пользователя на экран входа.
  Future<void> restore() async {
    final access = _prefs.getString(kAccess);
    final refresh = _prefs.getString(kRefresh);
    if (access == null || refresh == null) return;

    // Сроки проверяются до обращения к серверу. Таймеры живут в памяти
    // вкладки и при перезагрузке обнуляются, поэтому отметки лежат
    // в хранилище: иначе перезагрузка страницы продлевала бы сессию.
    final now = _clock();
    final startedAt = _readTime(kStartedAt);
    final lastActivity = _readTime(kLastActivity);
    if (startedAt != null && now.difference(startedAt) >= sessionMaxDuration) {
      await _clear(SessionEndReason.maxDuration);
      return;
    }
    if (lastActivity != null &&
        now.difference(lastActivity) >= inactivityTimeout) {
      await _clear(SessionEndReason.inactivity);
      return;
    }

    _accessToken = access;
    _refreshToken = refresh;
    _startedAt = startedAt ?? now;

    final cached = _readUser();
    if (cached != null) {
      _user = cached;
      return;
    }

    try {
      _user = await _api.me();
      await _writeUser(_user!);
    } on UnauthorizedException {
      // Токен доступа истёк, пока вкладка была закрыта. Адрес /auth/me
      // интерсептор не обновляет, поэтому обновление вызывается здесь.
      if (await refreshTokens()) return;
      await _clear(SessionEndReason.expired);
    } on ApiException {
      // Сервер недоступен: токены не стираются, но и пользователь
      // неизвестен — приложение покажет экран входа.
      _user = null;
    }
  }

  Future<void> login(String username, String password) async {
    final result = await _api.login(username.trim(), password);
    _startedAt = _clock();
    _endReason = null;
    await _prefs.setString(kStartedAt, _startedAt!.toIso8601String());
    await _store(result);
    recordActivity(force: true);
    notifyListeners();
  }

  /// Регистрация и сразу вход: второй раз вводить только что придуманный
  /// пароль незачем.
  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    required String email,
  }) async {
    await _api.register(
      username: username.trim(),
      password: password,
      fullName: fullName.trim(),
      email: email.trim(),
    );
    await login(username, password);
  }

  Future<void> logout({
    SessionEndReason reason = SessionEndReason.signedOut,
  }) async {
    final refresh = _refreshToken;
    await _clear(reason);
    notifyListeners();
    // Отзыв токена обновления на сервере. Результат не ждётся: выйти
    // из системы пользователь должен и при недоступном сервере.
    if (refresh != null) {
      unawaited(_api.logout(refresh).catchError((Object _) {}));
    }
  }

  /// Обновление пары токенов. true — токены обновлены, false — сервер
  /// отказал и сессию нужно завершить. Сетевой сбой пробрасывается:
  /// выбрасывать человека из системы из-за пропавшей сети нельзя.
  @override
  Future<bool> refreshTokens() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final result = await _api.refresh(token);
      await _store(result);
      notifyListeners();
      return true;
    } on UnauthorizedException {
      return false;
    }
  }

  @override
  Future<void> expire() async {
    if (!isAuthenticated) return;
    await logout(reason: SessionEndReason.expired);
  }

  /// Отметка активности пользователя. Вызывается на каждое движение
  /// и нажатие, поэтому в хранилище пишется с прореживанием.
  void recordActivity({bool force = false}) {
    if (!isAuthenticated) return;
    final now = _clock();
    final written = _activityWrittenAt;
    if (!force &&
        written != null &&
        now.difference(written) < const Duration(seconds: 5)) {
      return;
    }
    _activityWrittenAt = now;
    unawaited(_prefs.setString(kLastActivity, now.toIso8601String()));
  }

  Future<void> _store(AuthResult result) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    // Роль приходит с сервера при каждом входе и обновлении токена.
    // Подменённая в хранилище роль продержится только до ближайшего
    // обновления.
    _user = result.user;
    await _prefs.setString(kAccess, result.accessToken);
    await _prefs.setString(kRefresh, result.refreshToken);
    await _writeUser(result.user);
  }

  Future<void> _clear(SessionEndReason reason) async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _startedAt = null;
    _activityWrittenAt = null;
    _endReason = reason;
    for (final key in [kAccess, kRefresh, kUser, kStartedAt, kLastActivity]) {
      await _prefs.remove(key);
    }
  }

  Future<void> _writeUser(AppUser user) =>
      _prefs.setString(kUser, jsonEncode(user.toJson()));

  AppUser? _readUser() {
    final raw = _prefs.getString(kUser);
    if (raw == null) return null;
    try {
      return AppUser.tryParse(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  DateTime? _readTime(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
