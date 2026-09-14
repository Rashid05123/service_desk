import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:service_desk/core/api_exceptions.dart';
import 'package:service_desk/core/fault_switch.dart';
import 'package:service_desk/models/app_user.dart';
import 'package:service_desk/models/category.dart';
import 'package:service_desk/models/category_query.dart';
import 'package:service_desk/models/page_result.dart';
import 'package:service_desk/repositories/app_repositories.dart';
import 'package:service_desk/screens/category_list_screen.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:service_desk/state/connection_notifier.dart';
import 'package:service_desk/state/list_notifier.dart';
import 'package:service_desk/state/reference_data_notifier.dart';

import 'support/test_app.dart';

/// Состояния экрана списка на настоящем экране категорий: загрузка,
/// пустой результат, ошибка с повтором, пропавшая связь и кнопки,
/// скрытые от роли без права.
void main() {
  late FakeCategoryRepository repository;
  late ConnectionNotifier connection;

  setUp(() {
    repository = FakeCategoryRepository(
      (_) => Future.value(pageOf(<TicketCategory>[])),
    );
    // Опрос сервера в этих проверках не нужен: о связи сообщает сама
    // проверка, поэтому пауза заведомо длиннее проверки.
    connection = ConnectionNotifier(
      probe: () async => false,
      probeInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => connection.dispose());

  Future<void> pumpList(WidgetTester tester, AuthNotifier auth) async {
    final notifier = ListNotifier<TicketCategory, CategoryQuery>(
      repository: repository,
      idOf: (c) => c.id,
      initialQuery: const CategoryQuery(),
      failureMessage: 'Не удалось загрузить список категорий',
    );
    await tester.pumpWidget(
      buildTestApp(
        path: '/categories',
        screen: const CategoryListScreen(),
        providers: [
          Provider<FaultSwitch>.value(value: FaultSwitch()),
          ChangeNotifierProvider<AuthNotifier>.value(value: auth),
          ChangeNotifierProvider<ConnectionNotifier>.value(value: connection),
          // Справочники закрыты для чтения: запросов к серверу не будет.
          ChangeNotifierProvider(
            create: (_) => ReferenceDataNotifier(
              AppRepositories.api(Dio()),
              canRead: (_) => false,
            ),
          ),
          ChangeNotifierProvider.value(value: notifier),
        ],
      ),
    );
    // Первый кадр запускает загрузку, второй показывает её состояние.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('пока ответа нет, показан индикатор загрузки', (tester) async {
    final pending = Completer<PageResult<TicketCategory>>();
    repository.onFind = (_) => pending.future;

    await pumpList(tester, await sessionAs(Role.agent));

    expect(repository.findCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка данных…'), findsOneWidget);
    expect(find.text('Категорий не найдено'), findsNothing);
  });

  testWidgets('пустой результат — сообщение, а не индикатор', (tester) async {
    await pumpList(tester, await sessionAs(Role.agent));
    await tester.pumpAndSettle();

    expect(find.text('Категорий не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ошибка показывается с кнопкой повтора, повтор загружает', (
    tester,
  ) async {
    repository.onFind = (_) =>
        Future.error(const ServerException('Ошибка на сервере.'));

    await pumpList(tester, await sessionAs(Role.agent));
    await tester.pumpAndSettle();

    expect(find.text('Ошибка загрузки'), findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'Повторить');
    expect(retry, findsOneWidget);

    repository.onFind = (_) =>
        Future.value(pageOf([category(1, 'Печать и расходные материалы')]));
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repository.findCalls, 2);
    expect(find.text('Ошибка загрузки'), findsNothing);
    expect(find.textContaining('Печать и расходные материалы'), findsWidgets);
  });

  testWidgets('без связи — понятное сообщение, после связи список сам', (
    tester,
  ) async {
    repository.onFind = (_) => Future.error(const NetworkException());

    await pumpList(tester, await sessionAs(Role.agent));
    connection.reportFailure();
    await tester.pumpAndSettle();

    expect(find.text('Нет связи с сервером'), findsOneWidget);
    expect(find.textContaining('данные загрузятся сами'), findsOneWidget);

    // Сервер снова отвечает. Кнопку повтора никто не нажимает.
    repository.onFind = (_) =>
        Future.value(pageOf([category(2, 'Доступ и учётные записи')]));
    connection.reportSuccess();
    await tester.pumpAndSettle();

    expect(repository.findCalls, 2);
    expect(find.text('Нет связи с сервером'), findsNothing);
    expect(find.textContaining('Доступ и учётные записи'), findsWidgets);
  });

  group('кнопки скрыты от роли без права', () {
    setUp(() {
      repository.onFind = (_) =>
          Future.value(pageOf([category(3, 'Сеть и интернет')]));
    });

    testWidgets('специалист ведёт каталог, но не стирает записи', (
      tester,
    ) async {
      await pumpList(tester, await sessionAs(Role.agent));
      await tester.pumpAndSettle();

      expect(find.text('Новая категория'), findsOneWidget);
      expect(find.byTooltip('Изменить'), findsOneWidget);
      expect(find.byTooltip('Удалить безвозвратно'), findsNothing);
    });

    testWidgets('администратор стирает записи, но каталог не ведёт', (
      tester,
    ) async {
      await pumpList(tester, await sessionAs(Role.admin));
      await tester.pumpAndSettle();

      expect(find.text('Новая категория'), findsNothing);
      expect(find.byTooltip('Изменить'), findsNothing);
      expect(find.byTooltip('Удалить безвозвратно'), findsOneWidget);
    });
  });
}
