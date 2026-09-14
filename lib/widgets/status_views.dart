import 'package:flutter/material.dart';

/// Состояние «идёт загрузка».
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загрузка данных…'),
        ],
      ),
    );
  }
}

/// Загрузка прошла, но записей нет. В отличие от ошибки, предлагается
/// сбросить условия отбора, а не повторить запрос.
class EmptyView extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onReset;

  const EmptyView({
    super.key,
    required this.title,
    required this.description,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onReset != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить условия отбора'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Запрос завершился ошибкой. Условия отбора ни при чём, поэтому
/// предлагается повторить запрос.
///
/// Отказ сервера по правам с кодом 403 показывается иначе: повтор его
/// не исправит, и кнопки повтора нет.
///
/// Пропавшая связь тоже показывается отдельно: это не сбой приложения,
/// и экран обновится сам, когда сервер снова ответит.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool forbidden;
  final bool offline;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.forbidden = false,
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                forbidden
                    ? Icons.gpp_bad_outlined
                    : (offline
                          ? Icons.cloud_off_outlined
                          : Icons.error_outline),
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                forbidden
                    ? 'Сервер отказал в доступе'
                    : (offline ? 'Нет связи с сервером' : 'Ошибка загрузки'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (forbidden)
                Text(
                  'Код ответа 403: у вашей роли нет права на эту операцию. '
                  'Права проверяет сервер, и повтор запроса ответа не изменит.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
                if (offline) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Когда связь восстановится, данные загрузятся сами — '
                    'перезагружать страницу не нужно.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
