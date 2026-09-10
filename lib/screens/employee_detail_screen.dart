import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../models/ticket_query.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/detail_page.dart';

/// Карточка сотрудника поддержки.
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return DetailPage<Employee>(
      listPath: '/employees',
      idOf: (e) => e.id,
      titleOf: (e) => e?.lastName ?? 'Сотрудник',
      notFoundTitle: 'Сотрудник не найден',
      notFoundDescription: 'Записи с таким номером нет в справочнике.',
      content: (context, employee) => _content(context, employee, reference),
    );
  }

  List<Widget> _content(
    BuildContext context,
    Employee employee,
    ReferenceDataNotifier reference,
  ) {
    final theme = Theme.of(context);
    final department = reference.departmentById(employee.departmentId);

    return [
      if (employee.isDeleted) DeletedBanner(deletedAt: employee.deletedAt!),
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
            DetailRow('Линия поддержки', '${employee.supportLine}'),
            DetailRow('Электронная почта', employee.email),
            DetailRow('Телефон', employee.phone),
            DetailRow('Статус', employee.isActive ? 'работает' : 'не работает'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Многие к одному: отдел показан ссылкой на свою карточку.
      Text('Отдел', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: department == null
            ? const ListTile(
                leading: Icon(Icons.domain_disabled_outlined),
                title: Text('Отдел не найден'),
              )
            : ListTile(
                leading: const Icon(Icons.domain_outlined),
                title: Text(department.name),
                subtitle: Text('${department.code} · ${department.location}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/departments/${department.id}'),
              ),
      ),
      const SizedBox(height: 16),
      // Многие ко многим: обслуживаемые категории.
      Text('Обслуживаемые категории', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (employee.categoryIds.isEmpty)
        Text(
          'Компетенции не заданы: назначить сотрудника исполнителем '
          'нельзя ни по одной категории.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final categoryId in employee.categoryIds)
              ActionChip(
                avatar: const Icon(Icons.category_outlined, size: 16),
                label: Text(reference.categoryName(categoryId)),
                onPressed: () => context.go('/categories/$categoryId'),
              ),
          ],
        ),
      const SizedBox(height: 20),
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
    ];
  }
}
