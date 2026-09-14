import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/ticket.dart';
import '../repositories/workspace_api.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/async_view.dart';
import '../widgets/status_views.dart';
import '../widgets/ticket_summary_card.dart';

/// Личная очередь специалиста: незакрытые заявки, где он исполнитель
/// или соисполнитель, по возрастанию срока. Экран есть только у этой
/// роли — у администратора нет своего сотрудника поддержки.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _view = GlobalKey<AsyncViewState<List<Ticket>>>();

  Future<List<Ticket>> _load() {
    context.read<ReferenceDataNotifier>().warmUp();
    return context.read<WorkspaceApi>().queue();
  }

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя очередь'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => _view.currentState?.reload(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView<List<Ticket>>(
        key: _view,
        load: _load,
        builder: (context, tickets) {
          if (tickets.isEmpty) {
            return const EmptyView(
              title: 'Очередь пуста',
              description: 'Незакрытых заявок, назначенных на вас, нет.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final ticket in tickets)
                TicketSummaryCard(
                  ticket: ticket,
                  categoryName: reference.categoryName(ticket.categoryId),
                  onTap: () => context.go('/tickets/${ticket.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
