import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:service_desk/core/api_exceptions.dart';
import 'package:service_desk/screens/login_screen.dart';
import 'package:service_desk/state/auth_notifier.dart';

import 'support/test_app.dart';

/// Проверка формы входа на виджете: пустая форма не уходит на сервер,
/// отказ сервера показывается над формой.
void main() {
  Future<void> pumpLogin(WidgetTester tester, FakeAuthApi api) async {
    final auth = await sessionAs(null, api: api);
    await tester.pumpWidget(
      buildTestApp(
        path: '/login',
        screen: const LoginScreen(),
        providers: [ChangeNotifierProvider<AuthNotifier>.value(value: auth)],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('пустая форма не отправляется, у полей появляются ошибки', (
    tester,
  ) async {
    final api = FakeAuthApi();
    await pumpLogin(tester, api);

    expect(find.text('Укажите логин'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pump();

    expect(find.text('Укажите логин'), findsOneWidget);
    expect(find.text('Укажите пароль'), findsOneWidget);
    expect(api.loginCalls, 0);
  });

  testWidgets('отказ сервера показан над формой, пароль стёрт', (tester) async {
    final api = FakeAuthApi(
      loginError: const UnauthorizedException('Неверный логин или пароль.'),
    );
    await pumpLogin(tester, api);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Логин'),
      'grigorev',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      'neverno-123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(api.loginCalls, 1);
    expect(find.text('Неверный логин или пароль.'), findsOneWidget);
    expect(find.text('neverno-123'), findsNothing);
    expect(find.text('grigorev'), findsOneWidget);
  });
}
