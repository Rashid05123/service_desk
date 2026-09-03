import 'package:flutter/widgets.dart';

/// Классы ширины окна по Material 3, сокращённые до трёх.
enum ScreenSize { compact, medium, expanded }

/// Граница, на которой таблица заменяется списком карточек.
const double kCompactWidth = 600;

/// Граница, на которой боковая полоса навигации раскрывается с подписями.
const double kExpandedWidth = 1200;

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < kCompactWidth) return ScreenSize.compact;
  if (width < kExpandedWidth) return ScreenSize.medium;
  return ScreenSize.expanded;
}

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
