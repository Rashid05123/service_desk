import 'package:flutter/widgets.dart';

/// Классы ширины окна по Material 3, сокращённые до трёх.
///
/// * compact — телефон: одна колонка, навигация внизу, списки карточками;
/// * medium — планшет: боковая полоса навигации, карточки в две колонки;
/// * expanded — ноутбук и монитор: таблицы, полоса раскрыта с подписями.
enum ScreenSize { compact, medium, expanded }

/// Граница, до которой навигация уходит в нижнюю панель, а записи
/// показываются карточками в одну колонку.
const double kCompactWidth = 600;

/// Граница, с которой таблица сменяет карточки, а боковая полоса
/// навигации раскрывается вместе с подписями.
///
/// В ПР5 полоса раскрывалась только с 1800: раскрытая полоса занимала
/// 256 пикселей, и таблице заявок не хватало ширины. Задание ПР6 требует
/// развёрнутую навигацию уже на 1280, поэтому полоса сужена до
/// [kExtendedRailWidth], а таблица при нехватке места прокручивается по
/// горизонтали и прячет второстепенные колонки.
const double kExpandedWidth = 1200;

/// Ширина раскрытой полосы навигации.
const double kExtendedRailWidth = 208;

/// Предельная ширина содержимого раздела. На мониторе 1920 строка
/// таблицы или форма во всю ширину читается хуже, чем в колонке:
/// взгляд теряет строку при переводе с левого края на правый.
const double kMaxContentWidth = 1440;

ScreenSize screenSizeForWidth(double width) {
  if (width < kCompactWidth) return ScreenSize.compact;
  if (width < kExpandedWidth) return ScreenSize.medium;
  return ScreenSize.expanded;
}

ScreenSize screenSizeOf(BuildContext context) =>
    screenSizeForWidth(MediaQuery.sizeOf(context).width);

/// Возвращает значение, соответствующее текущей ширине окна.
T byScreen<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  return switch (screenSizeOf(context)) {
    ScreenSize.compact => compact,
    ScreenSize.medium => medium ?? compact,
    ScreenSize.expanded => expanded ?? medium ?? compact,
  };
}

/// Разбиение разделов для нижней панели навигации.
///
/// Нижняя панель вмещает не больше пяти пунктов: у шестого подпись уже
/// не помещается в 360 пикселей. Если разделов больше, первые четыре
/// остаются в панели, а остальные уходят в пятый пункт «Ещё».
({List<E> primary, List<E> overflow}) splitBottomDestinations<E>(
  List<E> items, {
  int slots = 5,
}) {
  if (items.length <= slots) return (primary: items, overflow: const []);
  return (
    primary: items.sublist(0, slots - 1),
    overflow: items.sublist(slots - 1),
  );
}
