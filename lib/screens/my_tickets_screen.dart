import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/permissions.dart';
import '../models/enums.dart';
import '../models/ticket.dart';
import '../repositories/workspace_api.dart';
import '../state/auth_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/async_view.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_views.dart';
import '../widgets/ticket_summary_card.dart';

/// Собственные заявки заявителя. Экран есть только у этой роли: сервер
/// отбирает заявки по карточке заявителя, связанной с учётной записью,
/// и чужих не отдаёт.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _view = GlobalKey<AsyncViewState<List<Ticket>>>();

  Future<List<Ticket>> _load() async {
    // Названия категорий берутся из кэша справочников.
    context.read<ReferenceDataNotifier>().warmUp();
    return context.read<WorkspaceApi>().myTickets();
  }

  Future<void> _reopen(Ticket ticket) async {
    final api = context.read<WorkspaceApi>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: 'Вернуть заявку в работу?',
      message:
          'Заявка ${ticket.number} отмечена решённой. Если проблема '
          'осталась, её вернут исполнителю со статусом «В работе».',
      confirmLabel: 'Вернуть в работу',
    );
    if (!confirmed) return;
    try {
      await api.reopen(ticket.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Заявка ${ticket.number} возвращена в работу')),
      );
      _view.currentState?.reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final reference = context.watch<ReferenceDataNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заявки'),
        actions: [
          if (auth.can(Permission.createOwnTicket))
            FilledButton.icon(
              onPressed: () => context.go('/my/new'),
              icon: const Icon(Icons.add),
              label: const Text('Новое обращение'),
            ),
          const SizedBox(width: 8),
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
              title: 'Обращений пока нет',
              description:
                  'Здесь появятся заявки, поданные от вашего имени, '
                  'с текущим статусом и сроком решения.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final ticket in tickets)
                TicketSummaryCard(
                  ticket: ticket,
                  categoryName: reference.categoryName(ticket.categoryId),
                  actions: [
                    if (ticket.status == TicketStatus.resolved &&
                        auth.can(Permission.reopenOwnTicket))
                      OutlinedButton.icon(
                        onPressed: () => _reopen(ticket),
                        icon: const Icon(Icons.replay),
                        label: const Text('Проблема осталась'),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
