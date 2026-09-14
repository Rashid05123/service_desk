import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../models/ticket.dart';
import '../screens/ticket_list_screen.dart';

/// Заявка одной карточкой: номер, тема, статус, категория и сроки.
/// Общая для «Моих заявок» заявителя и очереди специалиста.
class TicketSummaryCard extends StatelessWidget {
  const TicketSummaryCard({
    super.key,
    required this.ticket,
    required this.categoryName,
    this.onTap,
    this.actions = const [],
  });

  final Ticket ticket;
  final String categoryName;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ticket.number,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  priorityChip(context, ticket.priority),
                  const SizedBox(width: 6),
                  statusChip(context, ticket.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$categoryName · зарегистрирована '
                '${formatDate(ticket.createdAt)} · срок '
                '${formatDate(ticket.dueAt)}',
                style: muted,
              ),
              if (ticket.isOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Срок решения прошёл',
                    style: muted?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
