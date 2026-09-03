import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/fault_switch.dart';
import '../core/formatting.dart';
import '../models/enums.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import '../state/load_status.dart';
import '../state/reference_data_notifier.dart';
import '../state/ticket_list_notifier.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/debounced_search_field.dart';
import '../widgets/entity_card_list.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/status_views.dart';
import '../widgets/ticket_filter_panel.dart';

/// Экран списка заявок. Условия отбора хранятся только в адресе страницы:
/// экран читает их оттуда, а действия пользователя переписывают адрес.
class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  /// Раскрытие панели фильтров: локальное состояние виджета. Панель
  /// раскрывается сама, если в адресе уже заданы фильтры.
  bool? _filtersExpanded;

  /// Уже применённая строка запроса. Сравнение с ней не даёт зациклиться.
  String? _appliedQueryString;

  /// Чтение условий отбора из адреса и передача их в notifier.
  void _syncFromUrl(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    if (_appliedQueryString == uri.query) return;
    _appliedQueryString = uri.query;

    final query = TicketQuery.fromQueryParameters(uri.queryParameters);
    _filtersExpanded ??= query.activeFilterCount > 0;
    // notifyListeners внутри build вызывает исключение.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketListNotifier>().applyQuery(query);
    });
  }

  /// Запись условий отбора в адрес: единственный путь изменения списка.
  void _goWith(TicketQuery query) {
    final uri = Uri(
      path: '/tickets',
      queryParameters: query.toQueryParameters().isEmpty
          ? null
          : query.toQueryParameters(),
    );
    context.go(uri.toString());
  }

  Future<void> _confirmSoftDelete(Ticket ticket) async {
    final notifier = context.read<TicketListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить заявку?',
      message:
          'Заявка ${ticket.number} будет помечена как удалённая и исчезнет '
          'из списка. Её можно вернуть, включив показ удалённых.',
    );
    if (!confirmed) return;
    await notifier.softDelete(ticket.id);
    messenger.showSnackBar(
      SnackBar(content: Text('Заявка ${ticket.number} удалена')),
    );
  }

  Future<void> _confirmHardDelete(Ticket ticket) async {
    final notifier = context.read<TicketListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить безвозвратно?',
      message:
          'Заявка ${ticket.number} будет стёрта из хранилища. '
          'Это действие нельзя отменить.',
      confirmLabel: 'Стереть',
    );
    if (!confirmed) return;
    await notifier.hardDelete(ticket.id);
    messenger.showSnackBar(
      SnackBar(content: Text('Заявка ${ticket.number} стёрта безвозвратно')),
    );
  }

  Future<void> _confirmDeleteSelected() async {
    final notifier = context.read<TicketListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final count = notifier.selectedCount;
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранные заявки?',
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

    final notifier = context.watch<TicketListNotifier>();
    final reference = context.watch<ReferenceDataNotifier>();
    final query = notifier.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки в техподдержку'),
        actions: [
          Tooltip(
            message: 'Обновить',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: notifier.load,
            ),
          ),
          _FaultToggle(onChanged: notifier.load),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        // Без stretch полоса выделения сожмётся по ширине содержимого.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, notifier, query),
          if (_filtersExpanded ?? false)
            TicketFilterPanel(
              query: query,
              reference: reference,
              onChanged: _goWith,
            ),
          if (notifier.hasSelection) _selectionBar(context, notifier),
          Expanded(child: _content(context, notifier, reference, compact)),
          if (notifier.status != LoadStatus.error)
            PaginationBar(
              page: notifier.result.page,
              totalPages: notifier.result.totalPages,
              total: notifier.result.total,
              firstItemNumber: notifier.result.firstItemNumber,
              lastItemNumber: notifier.result.lastItemNumber,
              size: query.size,
              availableSizes: TicketQuery.availableSizes,
              itemsLabel: pluralTickets(notifier.result.total),
              onPageChanged: (page) => _goWith(query.copyWith(page: page)),
              // Номер страницы сбрасывает сам copyWith.
              onSizeChanged: (size) => _goWith(query.copyWith(size: size)),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    TicketListNotifier notifier,
    TicketQuery query,
  ) {
    final filterCount = query.activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DebouncedSearchField(
              value: query.search,
              hintText: 'Поиск по номеру и теме заявки',
              onChanged: (text) => _goWith(query.copyWith(search: text)),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
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
    );
  }

  Widget _selectionBar(BuildContext context, TicketListNotifier notifier) {
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
              label: const Text('Удалить выбранные'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    TicketListNotifier notifier,
    ReferenceDataNotifier reference,
    bool compact,
  ) {
    // Сначала загрузка и ошибка, затем «успех с пустым списком»: иначе
    // при пустом результате останется индикатор загрузки.
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
            title: 'Заявок не найдено',
            description: notifier.query.hasAnyCondition
                ? 'Под заданные условия отбора не подошла ни одна заявка. '
                      'Попробуйте изменить их или сбросить.'
                : 'В журнале пока нет ни одной заявки.',
            onReset: notifier.query.hasAnyCondition
                ? () => _goWith(const TicketQuery())
                : null,
          );
        }
        return compact
            ? _cards(context, notifier, reference)
            : _table(context, notifier, reference);
    }
  }

  Widget _table(
    BuildContext context,
    TicketListNotifier notifier,
    ReferenceDataNotifier reference,
  ) {
    final query = notifier.query;

    return EntityTable<Ticket>(
      items: notifier.result.items,
      idOf: (t) => t.id,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      onToggleSelectAll: notifier.toggleSelectAllOnPage,
      isDimmed: (t) => t.isDeleted,
      sortField: query.sortField,
      sortAscending: query.sortAscending,
      onSort: (field) => _goWith(
        query.copyWith(
          sortField: field,
          // Повторный щелчок по колонке переключает направление.
          sortAscending: field == query.sortField ? !query.sortAscending : true,
        ),
      ),
      columns: [
        TableColumnSpec(
          label: 'Номер',
          sortField: 'number',
          build: (context, t) => Text(t.number),
        ),
        TableColumnSpec(
          label: 'Тема',
          sortField: 'subject',
          build: (context, t) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(t.subject, overflow: TextOverflow.ellipsis),
          ),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (context, t) => Text(reference.categoryName(t.categoryId)),
        ),
        TableColumnSpec(
          label: 'Приоритет',
          sortField: 'priority',
          build: (context, t) => _priorityChip(context, t.priority),
        ),
        TableColumnSpec(
          label: 'Статус',
          sortField: 'status',
          build: (context, t) => _statusChip(context, t.status),
        ),
        TableColumnSpec(
          label: 'Исполнитель',
          build: (context, t) {
            final assignee = reference.employeeById(t.assigneeId);
            return Text(
              assignee == null
                  ? '— не назначен —'
                  : shortName(assignee.fullName),
            );
          },
        ),
        TableColumnSpec(
          label: 'Создана',
          sortField: 'createdAt',
          build: (context, t) => Text(formatDate(t.createdAt)),
        ),
        TableColumnSpec(
          label: 'Срок',
          sortField: 'dueAt',
          build: (context, t) => Text(
            formatDate(t.dueAt),
            style: t.isOverdue
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ],
      actions: (context, t) => _rowActions(context, t),
    );
  }

  Widget _cards(
    BuildContext context,
    TicketListNotifier notifier,
    ReferenceDataNotifier reference,
  ) {
    return EntityCardList<Ticket>(
      items: notifier.result.items,
      idOf: (t) => t.id,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      isDimmed: (t) => t.isDeleted,
      title: (t) => '${t.number} · ${t.subject}',
      subtitle: (t) =>
          '${reference.categoryName(t.categoryId)} · '
          '${reference.employeeById(t.assigneeId)?.fullName ?? 'не назначен'}',
      chips: (context, t) => [
        _priorityChip(context, t.priority),
        _statusChip(context, t.status),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('до ${formatDate(t.dueAt)}'),
          avatar: Icon(
            t.isOverdue ? Icons.warning_amber : Icons.schedule,
            size: 16,
            color: t.isOverdue ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ],
      actions: (context, t) => _rowActions(context, t),
    );
  }

  List<Widget> _rowActions(BuildContext context, Ticket ticket) {
    final notifier = context.read<TicketListNotifier>();
    return [
      Tooltip(
        message: 'Открыть карточку',
        child: IconButton(
          icon: const Icon(Icons.open_in_new),
          // Условия отбора переносятся в адрес карточки для кнопки возврата.
          onPressed: () => context.go(
            Uri(
              path: '/tickets/${ticket.id}',
              queryParameters: notifier.query.toQueryParameters().isEmpty
                  ? null
                  : notifier.query.toQueryParameters(),
            ).toString(),
          ),
        ),
      ),
      if (ticket.isDeleted)
        Tooltip(
          message: 'Восстановить',
          child: IconButton(
            icon: const Icon(Icons.restore_from_trash),
            onPressed: () => notifier.restore(ticket.id),
          ),
        )
      else
        Tooltip(
          message: 'Удалить (логически)',
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmSoftDelete(ticket),
          ),
        ),
      Tooltip(
        message: 'Удалить безвозвратно',
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _confirmHardDelete(ticket),
        ),
      ),
    ];
  }
}

Widget _priorityChip(BuildContext context, TicketPriority priority) {
  final color = priorityColor(context, priority);
  return Chip(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide(color: color),
    backgroundColor: color.withValues(alpha: 0.12),
    label: Text(priority.label, style: TextStyle(color: color)),
  );
}

Widget _statusChip(BuildContext context, TicketStatus status) {
  final color = statusColor(context, status);
  return Chip(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide(color: color),
    label: Text(status.label, style: TextStyle(color: color)),
  );
}

/// Кнопка, включающая учебный отказ хранилища.
class _FaultToggle extends StatefulWidget {
  final VoidCallback onChanged;

  const _FaultToggle({required this.onChanged});

  @override
  State<_FaultToggle> createState() => _FaultToggleState();
}

class _FaultToggleState extends State<_FaultToggle> {
  @override
  Widget build(BuildContext context) {
    final faults = context.read<FaultSwitch>();
    return Tooltip(
      message: faults.enabled
          ? 'Отключить учебный сбой хранилища'
          : 'Включить учебный сбой хранилища',
      child: IconButton(
        icon: Icon(
          faults.enabled ? Icons.bug_report : Icons.bug_report_outlined,
        ),
        color: faults.enabled ? Theme.of(context).colorScheme.error : null,
        onPressed: () {
          setState(faults.toggle);
          widget.onChanged();
        },
      ),
    );
  }
}
