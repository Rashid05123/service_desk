import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/department.dart';
import '../models/employee_query.dart';
import '../models/requester_query.dart';
import '../widgets/detail_page.dart';

/// Карточка отдела. Сторона «один» связи один ко многим, поэтому здесь
/// же показаны обе стороны «многие» и переходы к ним.
class DepartmentDetailScreen extends StatelessWidget {
  const DepartmentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage<Department>(
      listPath: '/departments',
      idOf: (d) => d.id,
      titleOf: (d) => d?.name ?? 'Отдел',
      notFoundTitle: 'Отдел не найден',
      notFoundDescription: 'Записи с таким номером нет в справочнике.',
      content: (context, department) {
        final theme = Theme.of(context);
        final employees = department.employeeCount;
        final requesters = department.requesterCount;

        return [
          if (department.isDeleted)
            DeletedBanner(deletedAt: department.deletedAt!),
          Text(department.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Код ${department.code}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                DetailRow('Расположение', department.location),
                DetailRow('Телефон', department.phone),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Связанные записи', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Пока на отдел ссылается хотя бы одна запись, удалить его '
            'нельзя — приложение откажет и назовёт число ссылок.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Сотрудники поддержки'),
                  subtitle: Text('$employees записей'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    Uri(
                      path: '/employees',
                      queryParameters: EmployeeQuery(
                        departmentId: department.id,
                      ).toQueryParameters(),
                    ).toString(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Заявители'),
                  subtitle: Text('$requesters записей'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    Uri(
                      path: '/requesters',
                      queryParameters: RequesterQuery(
                        departmentId: department.id,
                      ).toQueryParameters(),
                    ).toString(),
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
