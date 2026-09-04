import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/breakpoints.dart';

/// Каркас с адаптивной навигацией: до 600 нижняя панель, шире боковая
/// полоса, с 1800 она раскрывается вместе с подписями.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _destinations = [
    (
      icon: Icons.confirmation_number_outlined,
      label: 'Заявки',
      path: '/tickets',
    ),
    (icon: Icons.badge_outlined, label: 'Сотрудники', path: '/employees'),
  ];

  /// Раздел определяется по адресу, а не по внутреннему состоянию.
  int _indexOf(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  void _onSelected(BuildContext context, int index) {
    // context.go, а не Navigator.push: адрес в браузере должен смениться.
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final selectedIndex = _indexOf(context);

    if (size == ScreenSize.compact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onSelected(context, index),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    final extended = size == ScreenSize.expanded;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onSelected(context, index),
            extended: extended,
            // extended: true и labelType, отличный от none, вместе
            // задать нельзя: будет исключение при сборке.
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(
                Icons.support_agent,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            destinations: [
              for (final d in _destinations)
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
    );
  }
}
