import 'package:flutter/material.dart';

/// Список карточек: замена таблицы на узком окне. Обобщён по той же
/// причине, что и EntityTable.
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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: chips!(context, item),
                  ),
                ],
                if (actions != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!(context, item),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
