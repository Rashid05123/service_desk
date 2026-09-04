import 'package:flutter/material.dart';

/// Описание колонки обобщённой таблицы: название, поле сортировки и способ
/// построить ячейку для элемента типа T.
class TableColumnSpec<T> {
  final String label;

  /// Поле сортировки; null означает несортируемую колонку.
  final String? sortField;

  /// Числовая колонка выравнивается по правому краю.
  final bool numeric;

  final Widget Function(BuildContext context, T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

/// Таблица, пригодная для любой сущности. Выделение строк, сортировка,
/// прокрутка и подсветка удалённых записей одинаковы для заявок
/// и для сотрудников, различается только набор колонок.
class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;

  /// Идентификатор элемента: по нему ведётся набор выделенных строк.
  final int Function(T item) idOf;

  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final VoidCallback? onToggleSelectAll;

  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;

  final List<Widget> Function(BuildContext context, T item)? actions;

  /// Признак логически удалённой записи — такая строка показывается бледнее.
  final bool Function(T item)? isDimmed;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.isDimmed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectable = onToggleSelect != null;

    // По этому индексу DataTable рисует стрелку направления.
    int? sortColumnIndex;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].sortField != null && columns[i].sortField == sortField) {
        sortColumnIndex = i;
        break;
      }
    }

    final dataColumns = <DataColumn>[
      for (final column in columns)
        DataColumn(
          label: Text(column.label),
          numeric: column.numeric,
          onSort: (column.sortField != null && onSort != null)
              ? (_, _) => onSort!(column.sortField!)
              : null,
        ),
      if (actions != null) const DataColumn(label: Text('Действия')),
    ];

    final rows = <DataRow>[
      for (final item in items)
        DataRow(
          selected: selected.contains(idOf(item)),
          onSelectChanged: selectable
              ? (_) => onToggleSelect!(idOf(item))
              : null,
          color: (isDimmed?.call(item) ?? false)
              ? WidgetStatePropertyAll(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                )
              : null,
          cells: [
            for (final column in columns) DataCell(column.build(context, item)),
            if (actions != null)
              DataCell(
                // Кнопки действий уплотнены: три обычных занимают почти
                // 150 пикселей, из-за чего таблица не помещается в окно
                // шириной около 1500 и последняя кнопка уезжает.
                IconButtonTheme(
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!(context, item),
                  ),
                ),
              ),
          ],
        ),
    ];

    // DataTable не прокручивается сам и не сжимается, поэтому прокрутка
    // по обеим осям. ConstrainedBox растягивает таблицу на ширину окна.
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 200,
            ),
            child: DataTable(
              columns: dataColumns,
              rows: rows,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              showCheckboxColumn: selectable,
              onSelectAll: onToggleSelectAll == null
                  ? null
                  : (_) => onToggleSelectAll!(),
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHigh,
              ),
              columnSpacing: 8,
              horizontalMargin: 10,
              headingTextStyle: theme.textTheme.labelLarge,
            ),
          ),
        ),
      ),
    );
  }
}
