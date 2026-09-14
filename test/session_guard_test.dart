import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:service_desk/repositories/auth_api.dart';
import 'package:service_desk/state/auth_notifier.dart';
import 'package:service_desk/widgets/session_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сроки сессии на виджете. Время в widget-тестах подменное, поэтому
/// три минуты неактивности проверяются за миллисекунды — сроки заданы
/// короткими, а логика та же.
void main() {
  late AuthNotifier auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AuthNotifier.kAccess, 'a1');
    await prefs.setString(AuthNotifier.kRefresh, 'r1');
    await prefs.setString(
      AuthNotifier.kUser,
      jsonEncode({
        'id': 3,
        'username': 'grigorev',
        'fullName': 'Григорьев Пётр Петрович',
        'email': 'grigorev@corp.local',
        'role': 'requester',
      }),
    );
    auth = AuthNotifier(prefs, _OfflineAuthApi());
    await auth.restore();
  });

  Future<void> pumpGuard(
    WidgetTester tester, {
    Duration inactivity = const Duration(seconds: 10),
    Duration maxDuration = const Duration(hours: 1),
  }) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthNotifier>.value(
        value: auth,
        child: MaterialApp(
          home: SessionGuard(
            inactivity: inactivity,
            warningLead: const Duration(seconds: 3),
            maxDuration: maxDuration,
            child: const Scaffold(body: Center(child: Text('Рабочий экран'))),
          ),
        ),
      ),
    );
  }

  testWidgets('без действий — предупреждение, затем выход', (tester) async {
    await pumpGuard(tester);
    expect(auth.isAuthenticated, isTrue);

    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Сессия завершится'), findsNothing);

    // За три секунды до конца появляется предупреждение.
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(find.textContaining('Сессия завершится'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(auth.isAuthenticated, isFalse);
    expect(auth.endReason, SessionEndReason.inactivity);
    expect(find.textContaining('Сессия завершится'), findsNothing);
  });

  testWidgets('движение мыши и нажатие клавиши сбрасывают таймер', (
    tester,
  ) async {
    await pumpGuard(tester);

    await tester.pump(const Duration(seconds: 8));
    expect(find.textContaining('Сессия завершится'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(20, 20));
    await mouse.moveTo(const Offset(40, 40));
    await tester.pump();
    // Предупреждение исчезает от любого действия, а не только от кнопки.
    expect(find.textContaining('Сессия завершится'), findsNothing);

    await tester.pump(const Duration(seconds: 8));
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(seconds: 8));
    expect(auth.isAuthenticated, isTrue);

    await auth.logout();
    await tester.pump();
    await mouse.removePointer();
  });

  testWidgets('предельный срок завершает сессию, даже если человек работает', (
    tester,
  ) async {
    await pumpGuard(
      tester,
      inactivity: const Duration(hours: 1),
      maxDuration: const Duration(seconds: 10),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(20, 20));

    for (var i = 0; i < 6; i++) {
      await mouse.moveTo(Offset(30.0 + i, 30));
      await tester.pump(const Duration(seconds: 2));
    }

    expect(auth.isAuthenticated, isFalse);
    expect(auth.endReason, SessionEndReason.maxDuration);
    await mouse.removePointer();
  });
}

/// Сеть в этих проверках не нужна: сессия восстанавливается из
/// хранилища, а отзыв токена при выходе ни на что не влияет.
class _OfflineAuthApi extends AuthApi {
  _OfflineAuthApi() : super(Dio());

  @override
  Future<void> logout(String refreshToken) async {}
}
