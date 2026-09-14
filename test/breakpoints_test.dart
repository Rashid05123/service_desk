import 'package:flutter_test/flutter_test.dart';
import 'package:service_desk/core/breakpoints.dart';

/// Классы ширины окна для четырёх ширин из задания и разбиение
/// разделов для нижней панели навигации.
void main() {
  group('класс ширины окна', () {
    test('четыре ширины из задания', () {
      expect(screenSizeForWidth(360), ScreenSize.compact);
      expect(screenSizeForWidth(768), ScreenSize.medium);
      expect(screenSizeForWidth(1280), ScreenSize.expanded);
      expect(screenSizeForWidth(1920), ScreenSize.expanded);
    });

    test('границы относятся к следующему классу', () {
      expect(screenSizeForWidth(kCompactWidth - 1), ScreenSize.compact);
      expect(screenSizeForWidth(kCompactWidth), ScreenSize.medium);
      expect(screenSizeForWidth(kExpandedWidth - 1), ScreenSize.medium);
      expect(screenSizeForWidth(kExpandedWidth), ScreenSize.expanded);
    });
  });

  group('нижняя панель навигации', () {
    test('пять разделов и меньше помещаются целиком', () {
      final split = splitBottomDestinations(['a', 'b', 'c', 'd', 'e']);

      expect(split.primary, ['a', 'b', 'c', 'd', 'e']);
      expect(split.overflow, isEmpty);
    });

    test('шестой раздел уводит в «Ещё» всё начиная с пятого', () {
      final split = splitBottomDestinations([1, 2, 3, 4, 5, 6, 7]);

      expect(split.primary, [1, 2, 3, 4]);
      expect(split.overflow, [5, 6, 7]);
    });
  });
}
