import 'package:flutter/material.dart';

/// Список карточек: замена таблицы на узком окне. Обобщён по той же
/// причине, что и EntityTable.
///
/// На телефоне карточки идут в одну колонку, на планшете — в две:
/// карточка во всю ширину окна 768 наполовину пуста, а таблица из десяти
/// колонок в эту ширину не помещается.
class EntityCardList<T> extends StatelessWidget {
  final List<T> items;
  final int Function(T item) idOf;

  final String Function(T item) title;
  final String Function(T item) subtitle;

  /// Строка метк под заголовком: приоритет, статус, срок и тому подобное.
  final List<Widget> Function(BuildContext context, T item)? chips;

  final List<Widget> Function(BuildContext context, T item)? actions;

  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final bool Function(T item)? isDimmed;

  /// Число колонок сетки.
  final int columns;

  const EntityCardList({
    super.key,
    required this.items,
    required this.idOf,
    required this.title,
    required this.subtitle,
    this.chips,
    this.actions,
    this.selected = const {},
    this.onToggleSelect,
    this.isDimmed,
    this.columns = 1,
  });

  @override
  Widget build(BuildContext context) {
    final rows = (items.length / columns).ceil();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rows,
      itemBuilder: (context, row) {
        if (columns == 1) return _card(context, items[row]);

        // Ряд из нескольких карточек. Недостающая карточка последнего
        // ряда заменяется пустым местом той же ширины, иначе одинокая
        // карточка растянулась бы на весь ряд.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: 8),
              Expanded(
                child: row * columns + column < items.length
                    ? _card(context, items[row * columns + column])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, T item) {
    final theme = Theme.of(context);
    final id = idOf(item);
    final isSelected = selected.contains(id);
    final dimmed = isDimmed?.call(item) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: dimmed
          ? theme.colorScheme.surfaceContainerHighest
          : (isSelected ? theme.colorScheme.secondaryContainer : null),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onToggleSelect != null)
                  Checkbox(
                    value: isSelected,
                    semanticLabel: 'Выбрать: ${title(item)}',
                    onChanged: (_) => onToggleSelect!(id),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title(item),
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle(item),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (chips != null) ...[
              const SizedBox(height: 8),
              // Wrap вместо Row: на узком окне метки переносятся.
              Wrap(spacing: 6, runSpacing: 4, children: chips!(context, item)),
            ],
            if (actions != null) ...[
              const SizedBox(height: 4),
              // Wrap, а не Row: у администратора в карточке пять кнопок,
              // и в половину окна 768 они в строку не помещаются.
              Wrap(
                alignment: WrapAlignment.end,
                children: actions!(context, item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
