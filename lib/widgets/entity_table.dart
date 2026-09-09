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
class EntityTable<T> extends StatefulWidget {
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
  State<EntityTable<T>> createState() => _EntityTableState<T>();
}

class _EntityTableState<T> extends State<EntityTable<T>> {
  // Полосам прокрутки нужны собственные контроллеры: без них вложенные
  // Scrollbar не знают, к какой из двух областей относятся.
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void initState() {
    super.initState();
    // На первом кадре контроллер ещё не привязан к области прокрутки,
    // и постоянная полоса прокрутки не рисуется: она появлялась только
    // после первой прокрутки, о которой пользователь не догадывался.
    // Перестроение сразу после первого кадра эту полосу показывает.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = widget.columns;
    final items = widget.items;
    final idOf = widget.idOf;
    final selected = widget.selected;
    final onToggleSelect = widget.onToggleSelect;
    final onToggleSelectAll = widget.onToggleSelectAll;
    final sortField = widget.sortField;
    final sortAscending = widget.sortAscending;
    final onSort = widget.onSort;
    final actions = widget.actions;
    final isDimmed = widget.isDimmed;

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
              ? (_, _) => onSort(column.sortField!)
              : null,
        ),
      if (actions != null) const DataColumn(label: Text('Действия')),
    ];

    final rows = <DataRow>[
      for (final item in items)
        DataRow(
          selected: selected.contains(idOf(item)),
          onSelectChanged: selectable
              ? (_) => onToggleSelect(idOf(item))
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
                    children: actions(context, item),
                  ),
                ),
              ),
          ],
        ),
    ];

    // DataTable не прокручивается сам и не сжимается, поэтому прокрутка
    // по обеим осям. Горизонтальная область внешняя: её полоса прокрутки
    // остаётся прижатой к низу окна и видна всегда, а не уезжает вместе
    // с содержимым. Ширина берётся из LayoutBuilder, а не из размера
    // окна: боковая полоса навигации занимает часть ширины.
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        trackVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          // Отступ снизу оставляет место самой полосе прокрутки, иначе
          // она легла бы поверх последней строки.
          padding: const EdgeInsets.only(bottom: 14),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Scrollbar(
              controller: _vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                child: DataTable(
                  columns: dataColumns,
                  rows: rows,
                  sortColumnIndex: sortColumnIndex,
                  sortAscending: sortAscending,
                  showCheckboxColumn: selectable,
                  onSelectAll: onToggleSelectAll == null
                      ? null
                      : (_) => onToggleSelectAll(),
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
        ),
      ),
    );
  }
}
