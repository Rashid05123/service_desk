import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/enums.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_fields.dart';

/// Список заявок. Экран задаёт только колонки, карточки и фильтры —
/// поиск, сортировка, страницы и удаление берутся из EntityListPage.
class TicketListScreen extends StatelessWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return EntityListPage<Ticket, TicketQuery>(
      path: '/tickets',
      title: 'Заявки в техподдержку',
      searchHint: 'Поиск по номеру и теме заявки',
      createLabel: 'Новая заявка',
      parseQuery: TicketQuery.fromQueryParameters,
      availableSizes: TicketQuery.availableSizes,
      idOf: (t) => t.id,
      describe: (t) => '${t.number} · ${t.subject}',
      isDeleted: (t) => t.isDeleted,
      emptyTitle: 'Заявок не найдено',
      emptyDescription: 'В журнале пока нет ни одной заявки.',
      itemsLabel: pluralTickets,
      columns: [
        TableColumnSpec(
          label: 'Номер',
          sortField: 'number',
          build: (context, t) => Text(t.number),
        ),
        TableColumnSpec(
          label: 'Тема',
          sortField: 'subject',
          build: (context, t) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(t.subject, overflow: TextOverflow.ellipsis),
          ),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (context, t) => Text(reference.categoryName(t.categoryId)),
        ),
        TableColumnSpec(
          label: 'Приоритет',
          sortField: 'priority',
          build: (context, t) => priorityChip(context, t.priority),
        ),
        TableColumnSpec(
          label: 'Статус',
          sortField: 'status',
          build: (context, t) => statusChip(context, t.status),
        ),
        TableColumnSpec(
          label: 'Исполнитель',
          build: (context, t) {
            final assignee = reference.employeeById(t.assigneeId);
            return Text(
              assignee == null
                  ? '— не назначен —'
                  : shortName(assignee.fullName),
            );
          },
        ),
        TableColumnSpec(
          // Связь многие ко многим: в таблице она видна числом.
          label: 'Соисп.',
          numeric: true,
          build: (context, t) => Text('${t.coworkerIds.length}'),
        ),
        TableColumnSpec(
          label: 'Заявитель',
          build: (context, t) =>
              Text(shortName(reference.requesterName(t.requesterId))),
        ),
        TableColumnSpec(
          label: 'Создана',
          sortField: 'createdAt',
          build: (context, t) => Text(formatDate(t.createdAt)),
        ),
        TableColumnSpec(
          label: 'Срок',
          sortField: 'dueAt',
          build: (context, t) => Text(
            formatDate(t.dueAt),
            style: t.isOverdue
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ],
      cardTitle: (t) => '${t.number} · ${t.subject}',
      cardSubtitle: (t) =>
          '${reference.categoryName(t.categoryId)} · '
          '${reference.employeeName(t.assigneeId)}',
      cardChips: (context, t) => [
        priorityChip(context, t.priority),
        statusChip(context, t.status),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('до ${formatDate(t.dueAt)}'),
          avatar: Icon(
            t.isOverdue ? Icons.warning_amber : Icons.schedule,
            size: 16,
            color: t.isOverdue ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ],
      filters: (context, query, onChanged) => FilterRow(
        children: [
          FilterDropdown<int>(
            label: 'Категория',
            value: query.categoryId,
            width: 240,
            items: [
              for (final category in reference.allCategories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => onChanged(query.copyWith(categoryId: value)),
          ),
          FilterDropdown<TicketPriority>(
            label: 'Приоритет',
            value: query.priority,
            width: 180,
            items: [
              for (final priority in TicketPriority.values)
                DropdownMenuItem(value: priority, child: Text(priority.label)),
            ],
            onChanged: (value) => onChanged(query.copyWith(priority: value)),
          ),
          FilterDropdown<TicketStatus>(
            label: 'Статус',
            value: query.status,
            width: 190,
            items: [
              for (final status in TicketStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => onChanged(query.copyWith(status: value)),
          ),
          FilterDropdown<int>(
            label: 'Исполнитель или соисполнитель',
            value: query.assigneeId,
            width: 300,
            items: [
              for (final employee in reference.allEmployees)
                DropdownMenuItem(
                  value: employee.id,
                  child: Text(employee.fullName),
                ),
            ],
            onChanged: (value) => onChanged(query.copyWith(assigneeId: value)),
          ),
          FilterDropdown<int>(
            label: 'Заявитель',
            value: query.requesterId,
            width: 280,
            items: [
              for (final requester in reference.allRequesters)
                DropdownMenuItem(
                  value: requester.id,
                  child: Text(requester.fullName),
                ),
            ],
            onChanged: (value) => onChanged(query.copyWith(requesterId: value)),
          ),
          FilterDateField(
            label: 'Создана с',
            value: query.createdFrom,
            onChanged: (value) => onChanged(query.copyWith(createdFrom: value)),
          ),
          FilterDateField(
            label: 'Создана по',
            value: query.createdTo,
            onChanged: (value) => onChanged(query.copyWith(createdTo: value)),
          ),
        ],
      ),
    );
  }
}

/// Метка приоритета. Цвет — роль из схемы темы, а не постоянный цвет.
Widget priorityChip(BuildContext context, TicketPriority priority) {
  final color = priorityColor(context, priority);
  return Chip(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide(color: color),
    backgroundColor: color.withValues(alpha: 0.12),
    label: Text(priority.label, style: TextStyle(color: color)),
  );
}

Widget statusChip(BuildContext context, TicketStatus status) {
  final color = statusColor(context, status);
  return Chip(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    side: BorderSide(color: color),
    label: Text(status.label, style: TextStyle(color: color)),
  );
}
