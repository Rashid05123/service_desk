import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/ticket.dart';
import '../state/detail_notifier.dart';
import '../state/load_status.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/status_views.dart';

/// Карточка заявки. Идентификатор берётся из адреса, поэтому /tickets/12
/// открывается напрямую; условия отбора списка тоже остаются в адресе.
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DetailNotifier<Ticket>>();
    final reference = context.watch<ReferenceDataNotifier>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    return Scaffold(
      appBar: AppBar(
        title: Text(notifier.item?.number ?? 'Заявка'),
        leading: Tooltip(
          message: 'К списку заявок',
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(
              Uri(
                path: '/tickets',
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
                  title: 'Заявка не найдена',
                  description:
                      'Записи с таким номером нет в журнале. Возможно, она '
                      'была удалена безвозвратно.',
                )
              : _details(context, notifier.item!, reference),
      },
    );
  }

  Widget _details(
    BuildContext context,
    Ticket ticket,
    ReferenceDataNotifier reference,
  ) {
    final theme = Theme.of(context);
    final assignee = reference.employeeById(ticket.assigneeId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        // Содержимое ограничено по ширине и не растягивается на монитор.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ticket.isDeleted)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Заявка удалена логически'),
                    subtitle: Text(
                      'Отметка удаления: ${formatDateTime(ticket.deletedAt!)}',
                    ),
                  ),
                ),
              Text(ticket.subject, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Приоритет: ${ticket.priority.label}')),
                  Chip(label: Text('Статус: ${ticket.status.label}')),
                  Chip(
                    label: Text(
                      'Категория: ${reference.categoryName(ticket.categoryId)}',
                    ),
                  ),
                  if (ticket.isOverdue)
                    Chip(
                      avatar: Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      label: const Text('Просрочена'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Описание', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(ticket.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    _row('Номер', ticket.number),
                    _row('Заявитель', ticket.requesterName),
                    _row('Подразделение', ticket.requesterDepartment),
                    _row(
                      'Исполнитель',
                      assignee == null
                          ? 'не назначен'
                          : '${assignee.fullName} · ${assignee.position}',
                    ),
                    _row('Создана', formatDateTime(ticket.createdAt)),
                    _row('Срок решения', formatDateTime(ticket.dueAt)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 160,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Без Expanded длинное значение переполнит Row.
              Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
      },
    );
  }
}
