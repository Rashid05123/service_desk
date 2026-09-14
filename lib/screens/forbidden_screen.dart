import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

/// Экран отказа: адрес существует, но роли его открывать нельзя.
///
/// Отличается от «страница не найдена» намеренно. Человек, открывший
/// присланную ссылку, должен понять, что дело в правах, а не в опечатке.
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.from});

  /// Адрес, который пытались открыть.
  final String? from;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = context.watch<AuthNotifier>().role;

    return Scaffold(
      appBar: AppBar(title: const Text('Нет доступа')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Раздел недоступен вашей роли',
                  style: theme.textTheme.titleLarge,
                ),
                if (from != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    from!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Роль «${role?.label ?? '—'}» не может открыть этот адрес. '
                  'Ссылки на него в интерфейсе для неё скрыты, поэтому, '
                  'скорее всего, адрес набран вручную или получен от коллеги. '
                  'Если доступ нужен по работе, обратитесь к администратору.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
