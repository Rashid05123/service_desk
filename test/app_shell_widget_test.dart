import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:service_desk/models/app_user.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:service_desk/widgets/app_shell.dart';

import 'support/test_app.dart';

/// Каркас на трёх ширинах окна из задания и пункты навигации по ролям.
void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required Role role,
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = await sessionAs(role);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Text('Экран главной')),
            ),
            GoRoute(
              path: '/departments',
              builder: (context, state) =>
                  const Scaffold(body: Text('Экран отделов')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthNotifier>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('360: навигация внизу, лишние разделы в «Ещё»', (tester) async {
    await pumpShell(tester, role: Role.agent, width: 360);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    // У специалиста семь разделов: четыре в панели и пункт «Ещё».
    expect(find.byType(NavigationDestination), findsNWidgets(5));

    await tester.tap(find.text('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отделы'));
    await tester.pumpAndSettle();

    expect(find.text('Экран отделов'), findsOneWidget);
  });

  testWidgets('768: боковая полоса с подписями под значками', (tester) async {
    await pumpShell(tester, role: Role.agent, width: 768);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('1280: полоса раскрыта, раздел администратора скрыт', (
    tester,
  ) async {
    await pumpShell(tester, role: Role.agent, width: 1280);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('Очередь'), findsOneWidget);
    expect(find.text('Пользователи'), findsNothing);
  });

  testWidgets('1280: администратор видит свои разделы', (tester) async {
    await pumpShell(tester, role: Role.admin, width: 1280);

    expect(find.text('Пользователи'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Очередь'), findsNothing);
  });
}
