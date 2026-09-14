import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/ru_localizations.dart';

/// Собственные делегаты русского языка: переводы и форматы дат те же,
/// что давали стандартные делегаты всех языков.
void main() {
  late MaterialLocalizations material;

  Future<void> pumpRu(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: ruLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            material = MaterialLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('подписи Material на русском', (tester) async {
    await pumpRu(tester);

    expect(material.cancelButtonLabel, 'Отмена');
    expect(material.okButtonLabel, 'ОК');
  });

  testWidgets('месяц и дата выбора даты в русском формате', (tester) async {
    await pumpRu(tester);

    expect(material.formatMonthYear(DateTime(2026, 9)), 'сентябрь 2026 г.');
    expect(material.formatCompactDate(DateTime(2026, 9, 15)), '15.09.2026');
    // Неделя начинается с понедельника.
    expect(material.firstDayOfWeekIndex, 1);
  });
}
