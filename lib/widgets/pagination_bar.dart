import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

/// Панель постраничного вывода. PaginatedDataTable не подошёл: он листает
/// уже загруженный список, а здесь на клиенте только текущая страница.
class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final int firstItemNumber;
  final int lastItemNumber;

  final int size;
  final List<int> availableSizes;

  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSizeChanged;

  /// Подпись единицы измерения: «заявок», «сотрудников».
  final String itemsLabel;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.firstItemNumber,
    required this.lastItemNumber,
    required this.size,
    required this.availableSizes,
    required this.onPageChanged,
    required this.onSizeChanged,
    required this.itemsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrevious = page > 1;
    final hasNext = page < totalPages;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    final counter = Text(
      total == 0
          ? 'Ничего не найдено'
          : 'Показаны $firstItemNumber–$lastItemNumber из $total $itemsLabel',
      style: theme.textTheme.bodySmall,
    );

    final sizeSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('На странице:', style: theme.textTheme.bodySmall),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: size,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final value in availableSizes)
              DropdownMenuItem(value: value, child: Text('$value')),
          ],
          onChanged: (value) {
            if (value != null) onSizeChanged(value);
          },
        ),
      ],
    );

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Первая страница',
          child: IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: hasPrevious ? () => onPageChanged(1) : null,
          ),
        ),
        Tooltip(
          message: 'Предыдущая страница',
          child: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Стр. $page из $totalPages',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Tooltip(
          message: 'Следующая страница',
          child: IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: hasNext ? () => onPageChanged(page + 1) : null,
          ),
        ),
        Tooltip(
          message: 'Последняя страница',
          child: IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: hasNext ? () => onPageChanged(totalPages) : null,
          ),
        ),
      ],
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: compact
            // На узком окне счётчик уходит на отдельную строку.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: counter,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      sizeSelector,
                      Flexible(child: pager),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  counter,
                  const Spacer(),
                  sizeSelector,
                  const SizedBox(width: 16),
                  pager,
                ],
              ),
      ),
    );
  }
}
