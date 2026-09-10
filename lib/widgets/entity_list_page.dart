import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/fault_switch.dart';
import '../core/formatting.dart';
import '../models/list_query.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../state/load_status.dart';
import 'confirm_dialog.dart';
import 'debounced_search_field.dart';
import 'entity_card_list.dart';
import 'entity_table.dart';
import 'pagination_bar.dart';
import 'status_views.dart';

/// Экран списка, общий для всех пяти сущностей: поиск, фильтры,
/// сортировка, постраничный вывод, множественное выделение, оба вида
/// удаления и переходы к карточке и форме.
///
/// Условия отбора хранятся только в адресе страницы: экран читает их
/// оттуда, а действия пользователя переписывают адрес.
class EntityListPage<T, Q extends ListQuery<Q>> extends StatefulWidget {
  const EntityListPage({
    super.key,
    required this.path,
    required this.title,
    required this.searchHint,
    required this.parseQuery,
    required this.idOf,
    required this.describe,
    required this.isDeleted,
    required this.columns,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.itemsLabel,
    required this.availableSizes,
    required this.createLabel,
    this.cardChips,
    this.filters,
  });

  /// Адрес раздела: '/tickets'. Из него собираются адреса карточки,
  /// формы создания и формы изменения.
  final String path;

  final String title;
  final String searchHint;

  final Q Function(Map<String, String> params) parseQuery;

  final int Function(T item) idOf;

  /// Как назвать запись в вопросе об удалении: «заявку SD-000012».
  final String Function(T item) describe;

  final bool Function(T item) isDeleted;

  final List<TableColumnSpec<T>> columns;

  final String Function(T item) cardTitle;
  final String Function(T item) cardSubtitle;
  final List<Widget> Function(BuildContext context, T item)? cardChips;

  final String emptyTitle;
  final String emptyDescription;

  /// Подпись единицы измерения для счётчика: «заявок», «отделов».
  final String Function(int count) itemsLabel;

  final List<int> availableSizes;

  final String createLabel;

  /// Панель фильтров, своя у каждой сущности. Если её нет, кнопка
  /// «Фильтры» переключает только показ удалённых.
  final Widget Function(
    BuildContext context,
    Q query,
    ValueChanged<Q> onChanged,
  )?
  filters;

  @override
  State<EntityListPage<T, Q>> createState() => _EntityListPageState<T, Q>();
}

class _EntityListPageState<T, Q extends ListQuery<Q>>
    extends State<EntityListPage<T, Q>> {
  /// Раскрытие панели фильтров: локальное состояние виджета. Панель
  /// раскрывается сама, если в адресе уже заданы фильтры.
  bool? _filtersExpanded;

  /// Уже применённая строка запроса. Сравнение с ней не даёт зациклиться.
  String? _appliedQueryString;

  ListNotifier<T, Q> get _notifier => context.read<ListNotifier<T, Q>>();

  /// Чтение условий отбора из адреса и передача их в notifier.
  void _syncFromUrl(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    if (_appliedQueryString == uri.query) return;
    _appliedQueryString = uri.query;

    final query = widget.parseQuery(uri.queryParameters);
    _filtersExpanded ??= query.activeFilterCount > 0;
    // notifyListeners внутри build вызывает исключение.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.applyQuery(query);
      // Названия по ссылкам в таблице берутся из кэша справочников.
      // Он общий на всё приложение и загружается один раз.
      context.read<ReferenceDataNotifier>().warmUp();
    });
  }

  /// Запись условий отбора в адрес: единственный путь изменения списка.
  void _goWith(Q query) {
    final params = query.toQueryParameters();
    context.go(
      Uri(
        path: widget.path,
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  /// Условия отбора переносятся в адрес карточки — по ним работает
  /// кнопка возврата к списку.
  String _withCurrentQuery(String path) {
    final params = _notifier.query.toQueryParameters();
    return Uri(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  /// Отказ по ссылкам — не сбой, а объяснение: показывается всплывающей
  /// строкой, список при этом остаётся на экране.
  void _reportActionError() {
    final message = _notifier.takeActionError();
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
          content: Text(message),
        ),
      );
    });
  }

  Future<void> _confirmSoftDelete(T item) async {
    final notifier = _notifier;
    final messenger = ScaffoldMessenger.of(context);
    final name = widget.describe(item);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить запись?',
      message:
          'Запись «$name» будет помечена как удалённая и исчезнет из списка. '
          'Её можно вернуть, включив показ удалённых.',
    );
    if (!confirmed) return;
    if (await notifier.softDelete(widget.idOf(item))) {
      messenger.showSnackBar(SnackBar(content: Text('Удалено: $name')));
    }
  }

  Future<void> _confirmHardDelete(T item) async {
    final notifier = _notifier;
    final messenger = ScaffoldMessenger.of(context);
    final name = widget.describe(item);
    final confirmed = await confirmAction(
      context,
      title: 'Удалить безвозвратно?',
      message:
          'Запись «$name» будет стёрта из хранилища. '
          'Это действие нельзя отменить.',
      confirmLabel: 'Стереть',
    );
    if (!confirmed) return;
    if (await notifier.hardDelete(widget.idOf(item))) {
      messenger.showSnackBar(
        SnackBar(content: Text('Стёрто безвозвратно: $name')),
      );
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final notifier = _notifier;
    final messenger = ScaffoldMessenger.of(context);
    final count = notifier.selectedCount;
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранные записи?',
      message:
          'Будет удалено $count ${pluralSelected(count)}. '
          'Удаление логическое: записи можно восстановить.',
    );
    if (!confirmed) return;
    final deleted = await notifier.deleteSelected();
    if (deleted < 0) return; // операция отклонена, сообщение уже показано
    messenger.showSnackBar(
      SnackBar(content: Text('Удалено $deleted ${pluralSelected(deleted)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFromUrl(context);
    _reportActionError();

    final notifier = context.watch<ListNotifier<T, Q>>();
    final query = notifier.query;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Кнопка создания в панели, а не плавающая: плавающая
          // перекрывает управление постраничным выводом.
          FilledButton.icon(
            onPressed: () => context.go('${widget.path}/new'),
            icon: const Icon(Icons.add),
            label: Text(compact ? 'Создать' : widget.createLabel),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Обновить',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: notifier.load,
            ),
          ),
          FaultToggle(onChanged: notifier.load),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        // Без stretch полоса выделения сожмётся по ширине содержимого.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, query),
          if (_filtersExpanded ?? false) _filterPanel(context, query),
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
              availableSizes: widget.availableSizes,
              itemsLabel: widget.itemsLabel(notifier.result.total),
              onPageChanged: (page) => _goWith(query.withPage(page)),
              onSizeChanged: (size) => _goWith(query.withSize(size)),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, Q query) {
    final filterCount = query.activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DebouncedSearchField(
              value: query.search,
              hintText: widget.searchHint,
              onChanged: (text) => _goWith(query.withSearch(text)),
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

  /// Переключатель показа удалённых и кнопка сброса есть у всех списков,
  /// поэтому они здесь, а не в панели конкретной сущности.
  Widget _filterPanel(BuildContext context, Q query) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.filters != null) ...[
              widget.filters!(context, query, _goWith),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Switch(
                  value: query.includeDeleted,
                  onChanged: (value) =>
                      _goWith(query.withIncludeDeleted(value)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Показывать удалённые записи',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: query.hasAnyCondition
                      ? () => _goWith(query.cleared())
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

  Widget _selectionBar(BuildContext context, ListNotifier<T, Q> notifier) {
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
    ListNotifier<T, Q> notifier,
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
          final filtered = notifier.query.hasAnyCondition;
          return EmptyView(
            title: widget.emptyTitle,
            description: filtered
                ? 'Под заданные условия отбора не подошла ни одна запись. '
                      'Попробуйте изменить их или сбросить.'
                : widget.emptyDescription,
            onReset: filtered ? () => _goWith(notifier.query.cleared()) : null,
          );
        }
        return compact ? _cards(context, notifier) : _table(context, notifier);
    }
  }

  Widget _table(BuildContext context, ListNotifier<T, Q> notifier) {
    final query = notifier.query;

    return EntityTable<T>(
      items: notifier.result.items,
      idOf: widget.idOf,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      onToggleSelectAll: notifier.toggleSelectAllOnPage,
      isDimmed: widget.isDeleted,
      sortField: query.sortField,
      sortAscending: query.sortAscending,
      onSort: (field) => _goWith(
        // Повторный щелчок по колонке переключает направление.
        query.withSort(
          field,
          field == query.sortField ? !query.sortAscending : true,
        ),
      ),
      columns: widget.columns,
      actions: _rowActions,
    );
  }

  Widget _cards(BuildContext context, ListNotifier<T, Q> notifier) {
    return EntityCardList<T>(
      items: notifier.result.items,
      idOf: widget.idOf,
      selected: notifier.selected,
      onToggleSelect: notifier.toggleSelection,
      isDimmed: widget.isDeleted,
      title: widget.cardTitle,
      subtitle: widget.cardSubtitle,
      chips: widget.cardChips,
      actions: _rowActions,
    );
  }

  List<Widget> _rowActions(BuildContext context, T item) {
    final id = widget.idOf(item);
    final deleted = widget.isDeleted(item);

    return [
      Tooltip(
        message: 'Открыть карточку',
        child: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => context.go(_withCurrentQuery('${widget.path}/$id')),
        ),
      ),
      Tooltip(
        message: 'Изменить',
        child: IconButton(
          icon: const Icon(Icons.edit_outlined),
          // Удалённую запись сначала восстанавливают, потом правят.
          onPressed: deleted
              ? null
              : () => context.go(_withCurrentQuery('${widget.path}/$id/edit')),
        ),
      ),
      if (deleted)
        Tooltip(
          message: 'Восстановить',
          child: IconButton(
            icon: const Icon(Icons.restore_from_trash),
            onPressed: () => _notifier.restore(id),
          ),
        )
      else
        Tooltip(
          message: 'Удалить (логически)',
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmSoftDelete(item),
          ),
        ),
      Tooltip(
        message: 'Удалить безвозвратно',
        child: IconButton(
          icon: const Icon(Icons.delete_forever),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _confirmHardDelete(item),
        ),
      ),
    ];
  }
}

/// Учебные переключатели поведения сервера.
///
/// Оба параметра понимает сервер, поэтому приложение получает настоящий
/// ответ с кодом 500 и настоящую задержку, а не подделку внутри клиента.
/// Без них состояние загрузки на локальном сервере мелькает быстрее,
/// чем его успеваешь увидеть, а чтобы показать состояние ошибки,
/// сервер пришлось бы каждый раз останавливать.
class FaultToggle extends StatefulWidget {
  final VoidCallback onChanged;

  const FaultToggle({super.key, required this.onChanged});

  @override
  State<FaultToggle> createState() => _FaultToggleState();
}

class _FaultToggleState extends State<FaultToggle> {
  @override
  Widget build(BuildContext context) {
    final faults = context.read<FaultSwitch>();
    final scheme = Theme.of(context).colorScheme;
    final active = faults.enabled || faults.slow;

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(
            faults.enabled ? Icons.check_box : Icons.check_box_outline_blank,
          ),
          onPressed: () {
            setState(faults.toggle);
            widget.onChanged();
          },
          child: Text('Сбой сервера (код ${FaultSwitch.failStatus})'),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            faults.slow ? Icons.check_box : Icons.check_box_outline_blank,
          ),
          onPressed: () {
            setState(faults.toggleSlow);
            widget.onChanged();
          },
          child: Text('Медленный ответ (${FaultSwitch.delayMs} мс)'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Учебные переключатели сервера',
        child: IconButton(
          icon: Icon(active ? Icons.bug_report : Icons.bug_report_outlined),
          color: active ? scheme.error : null,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
