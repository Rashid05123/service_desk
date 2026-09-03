import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Экран для адресов, не подошедших ни под один маршрут.
class NotFoundScreen extends StatelessWidget {
  final String location;

  const NotFoundScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Страница не найдена')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wrong_location_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text('Адрес не распознан', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                SelectableText(
                  location,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/tickets'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('К списку заявок'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
