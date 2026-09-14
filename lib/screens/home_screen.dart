import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_shell.dart';

/// Главный экран. У каждой роли свой: разделы и перечень прав строятся
/// по матрице прав, поэтому различия ролей видны прямо на нём.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _roleSummary(Role role) => switch (role) {
    Role.requester =>
      'Подаёте обращения в службу поддержки и следите за их решением.',
    Role.agent =>
      'Принимаете заявки в работу, ведёте справочники и карточки заявителей.',
    Role.admin =>
      'Управляете пользователями и ролями, восстанавливаете и окончательно '
          'удаляете записи, следите за статистикой.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final sections = [
      for (final d in appDestinations)
        if (d.path != '/' && canOpen(user.role, d.path)) d,
    ];
    final granted = [
      for (final p in Permission.values)
        if (auth.can(p)) p,
    ];
    final denied = [
      for (final p in Permission.values)
        if (!auth.can(p)) p,
    ];
    final started = auth.sessionStartedAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Главная')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Здравствуйте, ${user.fullName}',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${user.role.label}. ${_roleSummary(user.role)}',
                  style: theme.textTheme.bodyLarge,
                ),
                if (started != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Вход выполнен ${formatDateTime(started)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Разделы', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final d in sections)
                        ListTile(
                          leading: Icon(d.icon),
                          title: Text(d.label),
                          subtitle: Text(d.description),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(d.path),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Права роли', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final allowedCard = _PermissionList(
                      title: 'Разрешено',
                      permissions: granted,
                      allowed: true,
                    );
                    final deniedCard = _PermissionList(
                      title: 'Недоступно роли',
                      permissions: denied,
                      allowed: false,
                    );
                    if (constraints.maxWidth < 640) {
                      return Column(children: [allowedCard, deniedCard]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: allowedCard),
                        const SizedBox(width: 12),
                        Expanded(child: deniedCard),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionList extends StatelessWidget {
  const _PermissionList({
    required this.title,
    required this.permissions,
    required this.allowed,
  });

  final String title;
  final List<Permission> permissions;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = allowed ? scheme.primary : scheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title · ${permissions.length}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            for (final p in permissions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      allowed ? Icons.check : Icons.lock_outline,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: allowed ? null : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
