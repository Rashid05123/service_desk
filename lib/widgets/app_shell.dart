import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../state/auth_notifier.dart';

typedef AppDestination = ({
  IconData icon,
  String label,
  String path,
  String description,
});

/// Все разделы приложения. Каждой роли показываются только те, что
/// ей можно открыть: список фильтруется той же матрицей прав, которой
/// проверяются маршруты, и расходиться им не с чего.
const List<AppDestination> appDestinations = [
  (
    icon: Icons.home_outlined,
    label: 'Главная',
    path: '/',
    description: 'Сводка по роли и доступным разделам',
  ),
  (
    icon: Icons.inbox_outlined,
    label: 'Мои заявки',
    path: '/my',
    description: 'Поданные обращения, их статус и сроки',
  ),
  (
    icon: Icons.add_comment_outlined,
    label: 'Обращение',
    path: '/my/new',
    description: 'Подать новое обращение в службу поддержки',
  ),
  (
    icon: Icons.assignment_ind_outlined,
    label: 'Очередь',
    path: '/queue',
    description: 'Незакрытые заявки, где вы исполнитель или соисполнитель',
  ),
  (
    icon: Icons.confirmation_number_outlined,
    label: 'Заявки',
    path: '/tickets',
    description: 'Журнал всех заявок',
  ),
  (
    icon: Icons.person_outline,
    label: 'Заявители',
    path: '/requesters',
    description: 'Карточки заявителей и учётные записи',
  ),
  (
    icon: Icons.badge_outlined,
    label: 'Сотрудники',
    path: '/employees',
    description: 'Сотрудники поддержки и их компетенции',
  ),
  (
    icon: Icons.domain_outlined,
    label: 'Отделы',
    path: '/departments',
    description: 'Справочник отделов',
  ),
  (
    icon: Icons.category_outlined,
    label: 'Категории',
    path: '/categories',
    description: 'Каталог категорий обращений и нормативы',
  ),
  (
    icon: Icons.manage_accounts_outlined,
    label: 'Пользователи',
    path: '/admin/users',
    description: 'Учётные записи и роли',
  ),
  (
    icon: Icons.insights_outlined,
    label: 'Статистика',
    path: '/admin/stats',
    description: 'Заявки по статусам и категориям, удалённые записи',
  ),
];

/// Каркас: шапка с пользователем и навигация по разделам роли.
/// До 600 навигация стоит внизу, до 1200 — боковая полоса с подписями
/// под значками, шире полоса раскрывается, а содержимое ограничено
/// по ширине.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  /// Раздел определяется по адресу, а не по внутреннему состоянию.
  /// Выбирается самый длинный подходящий путь: '/my/new' точнее '/my'.
  static int? _indexOf(String location, List<AppDestination> items) {
    int? best;
    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;
      final matches = path == '/'
          ? location == '/'
          : location == path || location.startsWith('$path/');
      if (matches && (best == null || path.length > items[best].path.length)) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final size = screenSizeOf(context);
    final location = GoRouterState.of(context).uri.path;

    final items = [
      for (final d in appDestinations)
        if (canOpen(auth.role, d.path)) d,
    ];
    final selectedIndex = _indexOf(location, items);

    // context.go, а не Navigator.push: адрес в браузере должен смениться.
    void select(int index) => context.go(items[index].path);

    if (size == ScreenSize.compact) {
      return _BottomNavigationShell(
        items: items,
        selectedIndex: selectedIndex,
        onSelect: select,
        child: child,
      );
    }

    final extended = size == ScreenSize.expanded;

    return Scaffold(
      body: Column(
        children: [
          const _SessionHeader(compact: false),
          Expanded(
            child: Row(
              children: [
                _ScrollableRail(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: select,
                    extended: extended,
                    minExtendedWidth: kExtendedRailWidth,
                    // extended: true и labelType, отличный от none, вместе
                    // задать нельзя: будет исключение при сборке.
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      for (final d in items)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ContentBoundary(
                    child: extended ? _WidthLimit(child: child) : child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Навигация телефона: разделы в нижней панели, лишние — в пункте «Ещё».
///
/// Выдвижная панель ПР5 прятала разделы за кнопкой меню: чтобы перейти
/// из заявок в очередь, нужно было два нажатия и знание, что меню есть.
/// Нижняя панель видна всегда и лежит под большим пальцем.
class _BottomNavigationShell extends StatelessWidget {
  const _BottomNavigationShell({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
  });

  final List<AppDestination> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  Future<void> _showMore(BuildContext context, int firstOverflowIndex) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = firstOverflowIndex; i < items.length; i++)
              ListTile(
                leading: Icon(items[i].icon),
                title: Text(items[i].label),
                subtitle: Text(
                  items[i].description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: i == selectedIndex,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSelect(i);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final split = splitBottomDestinations(items);
    final primary = split.primary;
    final hasMore = split.overflow.isNotEmpty;

    // Раздел из «Ещё» подсвечивает сам пункт «Ещё»: иначе на экране
    // статистики в панели не был бы выбран ни один пункт.
    final selected = selectedIndex;
    final barIndex = selected == null
        ? null
        : (selected < primary.length ? selected : primary.length);

    return Scaffold(
      body: Column(
        children: [
          const _SessionHeader(compact: true),
          Expanded(child: _ContentBoundary(child: child)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        // Выбранного раздела может не быть — например, на экране отказа.
        // Панель без выбора не бывает, поэтому подсветка там прозрачная.
        selectedIndex: barIndex ?? 0,
        indicatorColor: barIndex == null ? Colors.transparent : null,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (hasMore && index == primary.length) {
            _showMore(context, primary.length);
          } else {
            onSelect(index);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              label: d.label,
              tooltip: d.description,
            ),
          if (hasMore)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Ещё',
              tooltip: 'Остальные разделы',
            ),
        ],
      ),
    );
  }
}

/// Прокрутка полосы навигации по вертикали.
///
/// NavigationRail сам не прокручивается: у администратора девять
/// разделов, и в окне высотой 600 нижние пункты уходили за край
/// с полосой переполнения.
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

/// Ограничение ширины содержимого на широком мониторе.
class _WidthLimit extends StatelessWidget {
  const _WidthLimit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );
  }
}

/// Граница доступности вокруг содержимого раздела.
///
/// Экран раздела живёт во вложенном навигаторе ShellRoute, а страница
/// навигатора ставит под собой барьер с BlockSemantics. Такой барьер
/// скрывает от экранного чтеца всё, что нарисовано раньше него внутри той
/// же границы, — то есть шапку и полосу навигации: человек с экранным
/// чтецом не мог бы ни перейти в другой раздел, ни выйти из системы.
/// Собственная граница ограничивает действие барьера содержимым раздела.
class _ContentBoundary extends StatelessWidget {
  const _ContentBoundary({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, explicitChildNodes: true, child: child);
  }
}

/// Шапка приложения: название, вошедший пользователь, его роль и выход.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;

    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(width: compact ? 16 : 20),
            Icon(Icons.support_agent, color: scheme.primary),
            const SizedBox(width: 10),
            if (!compact)
              Text('Служба поддержки', style: theme.textTheme.titleMedium),
            // Всё свободное место отдаётся блоку пользователя, и он
            // прижимается к правому краю. Длинное ФИО на узком окне
            // обрезается многоточием, а не выталкивает кнопку выхода.
            Expanded(
              child: user == null
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          user.fullName,
                          style: theme.textTheme.labelLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.role.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
            if (user != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Выйти',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await auth.logout();
                  router.go('/login');
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
