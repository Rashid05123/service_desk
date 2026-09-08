import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/employee_query.dart';
import '../models/ticket_query.dart';
import '../repositories/app_repositories.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/detail_page.dart';

/// Карточка категории. На неё ссылаются и заявки (многие к одному),
/// и сотрудники (многие ко многим), поэтому обе стороны показаны здесь.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repositories = context.read<AppRepositories>();
    final reference = context.watch<ReferenceDataNotifier>();

    return DetailPage<TicketCategory>(
      listPath: '/categories',
      idOf: (c) => c.id,
      titleOf: (c) => c?.name ?? 'Категория',
      notFoundTitle: 'Категория не найдена',
      notFoundDescription: 'Записи с таким номером нет в справочнике.',
      content: (context, category) {
        final theme = Theme.of(context);
        final tickets = repositories.tickets.countByCategory(category.id);
        final experts = reference.allEmployees
            .where((e) => !e.isDeleted && e.categoryIds.contains(category.id))
            .toList();

        return [
          if (category.isDeleted) DeletedBanner(deletedAt: category.deletedAt!),
          Text(category.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(category.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                DetailRow('Норматив решения', '${category.slaHours} ч'),
                DetailRow(
                  'Состояние',
                  category.isActive
                      ? 'действует — предлагается в форме заявки'
                      : 'закрыта — в новых заявках не предлагается',
                ),
                DetailRow('Заявок в категории', '$tickets'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Кто обслуживает категорию',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Только эти сотрудники предлагаются исполнителями заявок '
            'данной категории.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (experts.isEmpty)
            Text(
              'Компетенция не закреплена ни за одним сотрудником.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final employee in experts)
                  ActionChip(
                    avatar: const Icon(Icons.badge_outlined, size: 16),
                    label: Text(employee.fullName),
                    onPressed: () => context.go('/employees/${employee.id}'),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => context.go(
                  Uri(
                    path: '/tickets',
                    queryParameters: TicketQuery(
                      categoryId: category.id,
                    ).toQueryParameters(),
                  ).toString(),
                ),
                icon: const Icon(Icons.list_alt),
                label: const Text('Заявки этой категории'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.go(
                  Uri(
                    path: '/employees',
                    queryParameters: EmployeeQuery(
                      categoryId: category.id,
                    ).toQueryParameters(),
                  ).toString(),
                ),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Сотрудники с этой компетенцией'),
              ),
            ],
          ),
        ];
      },
    );
  }
}
