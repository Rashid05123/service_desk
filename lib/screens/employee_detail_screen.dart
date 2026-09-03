import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/employee.dart';
import '../models/ticket_query.dart';
import '../state/detail_notifier.dart';
import '../state/load_status.dart';
import '../widgets/status_views.dart';

/// Карточка сотрудника поддержки.
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DetailNotifier<Employee>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    return Scaffold(
      appBar: AppBar(
        title: Text(notifier.item?.lastName ?? 'Сотрудник'),
        leading: Tooltip(
          message: 'К списку сотрудников',
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(
              Uri(
                path: '/employees',
                queryParameters: listParams.isEmpty ? null : listParams,
              ).toString(),
            ),
          ),
        ),
      ),
      body: switch (notifier.status) {
        LoadStatus.idle || LoadStatus.loading => const LoadingView(),
        LoadStatus.error => ErrorView(
          message: notifier.error ?? 'Неизвестная ошибка',
          onRetry: notifier.reload,
        ),
        LoadStatus.success =>
          notifier.item == null
              ? const EmptyView(
                  title: 'Сотрудник не найден',
                  description: 'Записи с таким номером нет в справочнике.',
                )
              : _details(context, notifier.item!),
      },
    );
  }

  Widget _details(BuildContext context, Employee employee) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (employee.isDeleted)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Запись удалена логически'),
                    subtitle: Text(
                      'Отметка удаления: '
                      '${formatDateTime(employee.deletedAt!)}',
                    ),
                  ),
                ),
              Text(employee.fullName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                employee.position,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _row(context, 'Отдел', employee.department),
                    _row(context, 'Линия поддержки', '${employee.supportLine}'),
                    _row(context, 'Электронная почта', employee.email),
                    _row(context, 'Телефон', employee.phone),
                    _row(
                      context,
                      'Статус',
                      employee.isActive ? 'работает' : 'не работает',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Переход на список с уже подставленным фильтром.
              FilledButton.tonalIcon(
                onPressed: () => context.go(
                  Uri(
                    path: '/tickets',
                    queryParameters: TicketQuery(assigneeId: employee.id)
                        .toQueryParameters(),
                  ).toString(),
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Показать заявки этого сотрудника'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
