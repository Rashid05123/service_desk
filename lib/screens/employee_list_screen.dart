import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/formatting.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../state/employee_list_notifier.dart';
import '../state/load_status.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/debounced_search_field.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/status_views.dart';

/// Экран списка сотрудников. Использует те же обобщённые виджеты, что и
/// экран заявок; различаются набор колонок и состав фильтров.
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  bool? _filtersExpanded;
  String? _appliedQueryString;

  void _syncFromUrl(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    if (_appliedQueryString == uri.query) return;
    _appliedQueryString = uri.query;

    final query = EmployeeQuery.fromQueryParameters(uri.queryParameters);
    _filtersExpanded ??= query.activeFilterCount > 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EmployeeListNotifier>().applyQuery(query);
    });
  }

  void _goWith(EmployeeQuery query) {
    final params = query.toQueryParameters();
    context.go(
      Uri(
        path: '/employees',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  Future<void> _confirmSoftDelete(Employee employee) async {
    final notifier = context.read<EmployeeListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить сотрудника?',
      message:
          '${employee.fullName} будет помечен как удалённый и исчезнет '
          'из списка. Запись можно вернуть.',
    );
    if (!confirmed) return;
    await notifier.softDelete(employee.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${employee.fullName} — запись удалена')),
    );
  }

  Future<void> _confirmHardDelete(Employee employee) async {
    final notifier = context.read<EmployeeListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить безвозвратно?',
      message:
          'Запись «${employee.fullName}» будет стёрта из хранилища. '
          'Это действие нельзя отменить.',
      confirmLabel: 'Стереть',
    );
    if (!confirmed) return;
    await notifier.hardDelete(employee.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${employee.fullName} — запись стёрта')),
    );
  }

  Future<void> _confirmDeleteSelected() async {
    final notifier = context.read<EmployeeListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final count = notifier.selectedCount;
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранных сотрудников?',
      message:
          'Будет удалено $count ${pluralSelected(count)}. '
          'Удаление логическое: записи можно восстановить.',
    );
    if (!confirmed) return;
    final deleted = await notifier.deleteSelected();
    messenger.showSnackBar(
      SnackBar(content: Text('Удалено $deleted ${pluralSelected(deleted)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFromUrl(context);

    final notifier = context.watch<EmployeeListNotifier>();
    final reference = context.watch<ReferenceDataNotifier>();
    final query = notifier.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сотрудники поддержки'),
        actions: [
          Tooltip(
            message: 'Обновить',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: notifier.load,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        // Без stretch полоса выделения сожмётся по ширине содержимого.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    value: query.search,
                    hintText: 'Поиск по фамилии и отделу',
                    onChanged: (text) => _goWith(query.copyWith(search: text)),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: query.activeFilterCount > 0,
                  label: Text('${query.activeFilterCount}'),
                  child: FilledButton.tonalIcon(
                    onPressed: () => setState(
                      () => _filtersExpanded = !(_filtersExpanded ?? false),
                    ),
                    icon: Icon(
                      (_filtersExpanded ?? false)
                          ? Icons.expand_less
                          : Icons.filter_alt,
                    ),
                    label: const Text('Фильтры'),
                  ),
                ),
              ],
            ),
          ),
          if (_filtersExpanded ?? false)
            _filterPanel(context, query, reference),
          if (notifier.hasSelection) _selectionBar(context, notifier),
          Expanded(child: _content(context, notifier, compact)),
          if (notifier.status != LoadStatus.error)
            PaginationBar(
              page: notifier.result.page,
              totalPages: notifier.result.totalPages,
              total: notifier.result.total,
              firstItemNumber: notifier.result.firstItemNumber,
              lastItemNumber: notifier.result.lastItemNumber,
              size: query.size,
              availableSizes: EmployeeQuery.availableSizes,
              itemsLabel: pluralEmployees(notifier.result.total),
              onPageChanged: (page) => _goWith(query.copyWith(page: page)),
              onSizeChanged: (size) => _goWith(query.copyWith(size: size)),
            ),
        ],
      ),
    );
  }

  Widget _filterPanel(
    BuildContext context,
    EmployeeQuery query,
    ReferenceDataNotifier reference,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dropdown<String>(
                  label: 'Отдел',
                  value: query.department,
                  width: 300,
                  items: [
                    for (final department in reference.departments)
                      DropdownMenuItem(
                        value: department,
                        child: Text(
                          department,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      _goWith(query.copyWith(department: value)),
                ),
                _dropdown<int>(
                  label: 'Линия поддержки',
                  value: query.supportLine,
                  width: 200,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 линия')),
                    DropdownMenuItem(value: 2, child: Text('2 линия')),
                    DropdownMenuItem(value: 3, child: Text('3 линия')),
                  ],
                  onChanged: (value) =>
                      _goWith(query.copyWith(supportLine: value)),
                ),
                _dropdown<bool>(
                  label: 'Работает',
                  value: query.onlyActive,
                  width: 180,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('да')),
                    DropdownMenuItem(value: false, child: Text('нет')),
                  ],
                  onChanged: (value) =>
                      _goWith(query.copyWith(onlyActive: value)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: query.includeDeleted,
                  onChanged: (value) =>
                      _goWith(query.copyWith(includeDeleted: value)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Показывать удалённые записи',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: query.hasAnyCondition
                      ? () => _goWith(const EmployeeQuery())
                      : null,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<V>({
    required String label,
    required V? value,
    required List<DropdownMenuItem<V>> items,
    required ValueChanged<V?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<V>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('— любой —')),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _selectionBar(BuildContext context, EmployeeListNotifier notifier) {
    final theme = Theme.of(context);
    final count = notifier.selectedCount;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Выбрано $count ${pluralSelected(count)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: notifier.clearSelection,
              icon: const Icon(Icons.close),
              label: const Text('Снять выделение'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Удалить выбранных'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    EmployeeListNotifier notifier,
    bool compact,
  ) {
    switch (notifier.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView();
      case LoadStatus.error:
        return ErrorView(
          message: notifier.error ?? 'Неизвестная ошибка',
          onRetry: notifier.load,
        );
      case LoadStatus.success:
        if (notifier.result.items.isEmpty) {
          return EmptyView(
            title: 'Сотрудников не найдено',
            description: notifier.query.hasAnyCondition
                ? 'Под заданные условия отбора не подошёл ни один сотрудник.'
                : 'Справочник сотрудников пуст.',
            onReset: notifier.query.hasAnyCondition
                ? () => _goWith(const EmployeeQuery())
                : null,
          );
        }
        return compact ? _cards(context, notifier) : _table(context, notifier);
    }
  }

  Widget _table(BuildContext context, EmployeeListNotifier notifier) {
    final query = notifier.query;

    return EntityTable<Employee>(
      items: notifier.result.items,
      idOf: (e) => e.id,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      onToggleSelectAll: notifier.toggleSelectAllOnPage,
      isDimmed: (e) => e.isDeleted,
      sortField: query.sortField,
      sortAscending: query.sortAscending,
      onSort: (field) => _goWith(
        query.copyWith(
          sortField: field,
          sortAscending: field == query.sortField ? !query.sortAscending : true,
        ),
      ),
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (context, e) => Text(e.fullName),
        ),
        TableColumnSpec(
          label: 'Должность',
          sortField: 'position',
          build: (context, e) => Text(e.position),
        ),
        TableColumnSpec(
          label: 'Отдел',
          sortField: 'department',
          build: (context, e) => Text(e.department),
        ),
        TableColumnSpec(
          label: 'Линия',
          sortField: 'supportLine',
          numeric: true,
          build: (context, e) => Text('${e.supportLine}'),
        ),
        TableColumnSpec(label: 'Почта', build: (context, e) => Text(e.email)),
        TableColumnSpec(
          label: 'Работает',
          build: (context, e) => Icon(
            e.isActive
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline,
            size: 18,
            color: e.isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
      actions: (context, e) => _rowActions(context, e),
    );
  }

  Widget _cards(BuildContext context, EmployeeListNotifier notifier) {
    return EntityCardList<Employee>(
      items: notifier.result.items,
      idOf: (e) => e.id,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      isDimmed: (e) => e.isDeleted,
      title: (e) => e.fullName,
      subtitle: (e) => '${e.position} · ${e.department}',
      chips: (context, e) => [
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('${e.supportLine} линия'),
        ),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text(e.isActive ? 'работает' : 'не работает'),
        ),
      ],
      actions: (context, e) => _rowActions(context, e),
    );
  }

  List<Widget> _rowActions(BuildContext context, Employee employee) {
    final notifier = context.read<EmployeeListNotifier>();
    final params = notifier.query.toQueryParameters();

    return [
      Tooltip(
        message: 'Открыть карточку',
        child: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.go(
            Uri(
              path: '/employees/${employee.id}',
              queryParameters: params.isEmpty ? null : params,
            ).toString(),
          ),
        ),
      ),
      if (employee.isDeleted)
        Tooltip(
          message: 'Восстановить',
          child: IconButton(
            icon: const Icon(Icons.restore_from_trash),
            onPressed: () => notifier.restore(employee.id),
          ),
        )
      else
        Tooltip(
          message: 'Удалить (логически)',
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmSoftDelete(employee),
          ),
        ),
      Tooltip(
        message: 'Удалить безвозвратно',
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _confirmHardDelete(employee),
        ),
      ),
    ];
  }
}
