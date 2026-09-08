import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/requester.dart';
import '../models/ticket_query.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/detail_page.dart';

/// Карточка заявителя вместе с учётной записью — стороной связи
/// один к одному.
class RequesterDetailScreen extends StatelessWidget {
  const RequesterDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return DetailPage<Requester>(
      listPath: '/requesters',
      idOf: (r) => r.id,
      titleOf: (r) => r?.lastName ?? 'Заявитель',
      notFoundTitle: 'Заявитель не найден',
      notFoundDescription: 'Записи с таким номером нет в справочнике.',
      content: (context, requester) {
        final theme = Theme.of(context);
        final department = reference.departmentById(requester.departmentId);
        final account = requester.account;

        return [
          if (requester.isDeleted) DeletedBanner(deletedAt: requester.deletedAt!),
          Text(requester.fullName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            requester.position,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                DetailRow(
                  'Отдел',
                  department?.name ?? '— отдел не найден —',
                ),
                if (requester.note.isNotEmpty)
                  DetailRow('Примечание', requester.note),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Учётная запись', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Связь один к одному: запись принадлежит только этому '
            'заявителю и редактируется в его же форме.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: account.isBlocked
                ? theme.colorScheme.errorContainer
                : null,
            child: Column(
              children: [
                DetailRow('Логин', account.login),
                DetailRow('Электронная почта', account.email),
                DetailRow('Телефон', account.phone),
                DetailRow('Рабочее место', account.office),
                DetailRow(
                  'Состояние',
                  account.isBlocked ? 'заблокирована' : 'активна',
                  valueColor: account.isBlocked
                      ? theme.colorScheme.error
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => context.go(
              Uri(
                path: '/tickets',
                queryParameters: TicketQuery(
                  requesterId: requester.id,
                ).toQueryParameters(),
              ).toString(),
            ),
            icon: const Icon(Icons.list_alt),
            label: const Text('Показать заявки этого заявителя'),
          ),
        ];
      },
    );
  }
}
