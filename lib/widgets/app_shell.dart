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
/// До 600 навигация уходит в выдвижную панель, шире — боковая полоса,
/// с 1800 полоса раскрывается вместе с подписями.
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
      return Scaffold(
        drawer: NavigationDrawer(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            Navigator.of(context).pop();
            select(index);
          },
          children: [
            const SizedBox(height: 16),
            for (final d in items)
              NavigationDrawerDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
              ),
          ],
        ),
        body: Column(
          children: [
            const _SessionHeader(compact: true),
            Expanded(child: child),
          ],
        ),
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
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: select,
                  extended: extended,
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
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
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
            if (compact)
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Разделы',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            else
              const SizedBox(width: 20),
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
