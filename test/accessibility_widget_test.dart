import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:service_desk/screens/login_screen.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:service_desk/state/connection_notifier.dart';
import 'package:service_desk/widgets/connection_banner.dart';
import 'package:service_desk/widgets/entity_table.dart';

import 'support/test_app.dart';

/// Доступность: подписи значков для экранного чтеца и управление
/// с клавиатуры.
void main() {
  testWidgets('у каждой кнопки в строке таблицы своя подпись', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityTable<int>(
            items: const [1],
            idOf: (i) => i,
            // С выделением строк ячейка становится нажимаемой и забирает
            // себе подпись вложенной обёртки Tooltip — ровно тот случай,
            // который нашёлся в браузере.
            onToggleSelect: (_) {},
            columns: [
              TableColumnSpec(label: 'Номер', build: (c, i) => Text('SD-$i')),
            ],
            actions: (context, i) => [
              IconButton(
                tooltip: 'Открыть карточку',
                icon: const Icon(Icons.open_in_new),
                onPressed: () {},
              ),
              IconButton(
                tooltip: 'Изменить',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {},
              ),
              IconButton(
                tooltip: 'Удалить (логически)',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final (icon, label) in [
      (Icons.open_in_new, 'Открыть карточку'),
      (Icons.edit_outlined, 'Изменить'),
      (Icons.delete_outline, 'Удалить (логически)'),
    ]) {
      expect(
        tester.getSemantics(find.byIcon(icon)),
        isSemantics(tooltip: label, isButton: true),
        reason: label,
      );
    }
    semantics.dispose();
  });

  testWidgets('полоса о пропаже связи видна экранному чтецу', (tester) async {
    final semantics = tester.ensureSemantics();
    final connection = ConnectionNotifier(
      probe: () async => false,
      probeInterval: const Duration(hours: 1),
    );
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionNotifier>.value(
        value: connection,
        child: MaterialApp(
          builder: (context, child) => ConnectionBanner(child: child!),
          home: const Scaffold(body: Text('Экран раздела')),
        ),
      ),
    );
    connection.reportFailure();
    await tester.pump();

    // Полоса стоит над навигатором; барьер страницы не должен её скрывать.
    expect(
      find.bySemanticsLabel(RegExp('Нет связи с сервером')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Экран раздела'), findsOneWidget);

    connection.reportSuccess();
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('Связь с сервером восстановлена')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('форма входа проходится клавишей Tab по порядку', (tester) async {
    final auth = await sessionAs(null);
    await tester.pumpWidget(
      buildTestApp(
        path: '/login',
        screen: const LoginScreen(),
        providers: [ChangeNotifierProvider<AuthNotifier>.value(value: auth)],
      ),
    );
    await tester.pumpAndSettle();

    bool focusedWithin(Finder finder) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return false;
      final target = finder.evaluate().single;
      if (focused == target) return true;
      var found = false;
      focused.visitAncestorElements((element) {
        found = element == target;
        return !found;
      });
      return found;
    }

    // Поле логина получает фокус само, дальше — порядок чтения формы.
    final order = [
      find.widgetWithText(TextFormField, 'Логин'),
      find.widgetWithText(TextFormField, 'Пароль'),
      find.byTooltip('Показать пароль'),
      find.widgetWithText(FilledButton, 'Войти'),
      find.widgetWithText(TextButton, 'Нет учётной записи? Зарегистрироваться'),
    ];
    expect(focusedWithin(order.first), isTrue);
    for (final next in order.skip(1)) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedWithin(next), isTrue, reason: '$next');
    }

    // Возврат к кнопке «Войти» и нажатие Enter отправляют форму.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Укажите логин'), findsOneWidget);
  });
}
