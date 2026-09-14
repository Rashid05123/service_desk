import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:service_desk/core/api_exceptions.dart';
import 'package:service_desk/models/app_user.dart';
import 'package:service_desk/models/category.dart';
import 'package:service_desk/models/category_query.dart';
import 'package:service_desk/models/page_result.dart';
import 'package:service_desk/repositories/auth_api.dart';
import 'package:service_desk/repositories/category_repository.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Общее для проверок виджетов: сессия нужной роли без сервера,
/// подменный репозиторий и приложение с маршрутизатором вокруг экрана.

/// Сессия, восстановленная из хранилища. `null` — никто не вошёл.
Future<AuthNotifier> sessionAs(Role? role, {AuthApi? api}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (role != null) {
    await prefs.setString(AuthNotifier.kAccess, 'access');
    await prefs.setString(AuthNotifier.kRefresh, 'refresh');
    await prefs.setString(
      AuthNotifier.kUser,
      jsonEncode({
        'id': 1,
        'username': role.code,
        'fullName': 'Проверочный пользователь',
        'email': '${role.code}@corp.local',
        'role': role.code,
      }),
    );
  }
  final auth = AuthNotifier(prefs, api ?? FakeAuthApi());
  await auth.restore();
  return auth;
}

/// Вход без сети: отказ задаётся заранее, число попыток считается.
class FakeAuthApi extends AuthApi {
  FakeAuthApi({this.loginError}) : super(Dio());

  final ApiException? loginError;
  int loginCalls = 0;

  @override
  Future<AuthResult> login(String username, String password) async {
    loginCalls++;
    final error = loginError;
    if (error != null) throw error;
    throw UnimplementedError('успешный вход в этих проверках не нужен');
  }

  @override
  Future<void> logout(String refreshToken) async {}
}

/// Репозиторий категорий, ответ которого задаёт сама проверка:
/// готовая страница, отказ или ответ, который так и не пришёл.
class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository(this.onFind);

  Future<PageResult<TicketCategory>> Function(CategoryQuery query) onFind;

  int findCalls = 0;

  @override
  Future<PageResult<TicketCategory>> find(CategoryQuery query) {
    findCalls++;
    return onFind(query);
  }

  @override
  void cancelPendingFind() {}

  @override
  Future<TicketCategory?> findById(int id) => throw UnimplementedError();

  @override
  Future<TicketCategory> create(TicketCategory item) =>
      throw UnimplementedError();

  @override
  Future<TicketCategory> update(TicketCategory item) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(int id) => throw UnimplementedError();

  @override
  Future<void> hardDelete(int id) => throw UnimplementedError();

  @override
  Future<void> restore(int id) => throw UnimplementedError();

  @override
  Future<int> deleteMany(List<int> ids) => throw UnimplementedError();
}

TicketCategory category(int id, String name) => TicketCategory(
  id: id,
  name: name,
  description: 'Описание категории $name',
  slaHours: 8,
  isActive: true,
);

PageResult<T> pageOf<T>(List<T> items) =>
    PageResult(items: items, page: 1, size: 10, total: items.length);

/// Экран внутри настоящего маршрутизатора: экраны читают адрес через
/// GoRouterState и без маршрутизатора не строятся.
Widget buildTestApp({
  required String path,
  required Widget screen,
  required List<SingleChildWidget> providers,
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );
  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(routerConfig: router),
  );
}
