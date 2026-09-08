import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/ticket.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/detail_page.dart';
import 'ticket_list_screen.dart';

/// Карточка заявки. Идентификатор берётся из адреса, поэтому /tickets/12
/// открывается напрямую; условия отбора списка тоже остаются в адресе.
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return DetailPage<Ticket>(
      listPath: '/tickets',
      idOf: (t) => t.id,
      titleOf: (t) => t?.number ?? 'Заявка',
      notFoundTitle: 'Заявка не найдена',
      notFoundDescription:
          'Записи с таким номером нет в журнале. Возможно, она была '
          'удалена безвозвратно.',
      content: (context, ticket) => _content(context, ticket, reference),
    );
  }

  List<Widget> _content(
    BuildContext context,
    Ticket ticket,
    ReferenceDataNotifier reference,
  ) {
    final theme = Theme.of(context);
    final assignee = reference.employeeById(ticket.assigneeId);
    final requester = reference.requesterById(ticket.requesterId);
    final coworkers = ticket.coworkerIds
        .map(reference.employeeById)
        .nonNulls
        .toList();

    return [
      if (ticket.isDeleted)
        DeletedBanner(
          deletedAt: ticket.deletedAt!,
          title: 'Заявка удалена логически',
        ),
      Text(ticket.subject, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          priorityChip(context, ticket.priority),
          statusChip(context, ticket.status),
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
            DetailRow('Номер', ticket.number),
            DetailRow(
              'Исполнитель',
              assignee == null
                  ? 'не назначен'
                  : '${assignee.fullName} · ${assignee.position}',
            ),
            DetailRow('Создана', formatDateTime(ticket.createdAt)),
            DetailRow(
              'Срок решения',
              formatDateTime(ticket.dueAt),
              valueColor: ticket.isOverdue ? theme.colorScheme.error : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Связь многие ко многим: соисполнители показываются списком меток
      // со ссылками на карточки сотрудников.
      Text('Соисполнители', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (coworkers.isEmpty)
        Text(
          'Дополнительные исполнители не назначены.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final employee in coworkers)
              ActionChip(
                avatar: const Icon(Icons.badge_outlined, size: 16),
                label: Text(employee.fullName),
                onPressed: () => context.go('/employees/${employee.id}'),
              ),
          ],
        ),
      const SizedBox(height: 20),
      // Связь многие к одному: заявитель показан карточкой со ссылкой.
      Text('Заявитель', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: requester == null
            ? const ListTile(
                leading: Icon(Icons.person_off_outlined),
                title: Text('Заявитель не найден'),
                subtitle: Text('Запись могла быть стёрта безвозвратно.'),
              )
            : ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(requester.fullName),
                subtitle: Text(
                  '${requester.position} · '
                  '${reference.departmentName(requester.departmentId)}\n'
                  'Учётная запись: ${requester.account.login}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/requesters/${requester.id}'),
              ),
      ),
    ];
  }
}
