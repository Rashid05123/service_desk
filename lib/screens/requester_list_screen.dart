import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/requester.dart';
import '../models/requester_query.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_fields.dart';

/// Список заявителей. Поля учётной записи показаны прямо в таблице:
/// связь один к одному отдельной сущностью для пользователя не выглядит.
class RequesterListScreen extends StatelessWidget {
  const RequesterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return EntityListPage<Requester, RequesterQuery>(
      path: '/requesters',
      title: 'Заявители',
      searchHint: 'Поиск по фамилии и логину',
      createLabel: 'Новый заявитель',
      parseQuery: RequesterQuery.fromQueryParameters,
      availableSizes: RequesterQuery.availableSizes,
      idOf: (r) => r.id,
      describe: (r) => r.fullName,
      isDeleted: (r) => r.isDeleted,
      emptyTitle: 'Заявителей не найдено',
      emptyDescription: 'В справочнике пока нет ни одной записи.',
      itemsLabel: pluralRequesters,
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (context, r) => Text(r.fullName),
        ),
        TableColumnSpec(
          label: 'Должность',
          sortField: 'position',
          build: (context, r) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(r.position, overflow: TextOverflow.ellipsis),
          ),
        ),
        TableColumnSpec(
          label: 'Отдел',
          build: (context, r) => Text(reference.departmentName(r.departmentId)),
        ),
        TableColumnSpec(
          label: 'Логин',
          sortField: 'login',
          build: (context, r) => Text(r.account.login),
        ),
        TableColumnSpec(
          label: 'Почта',
          build: (context, r) => Text(r.account.email),
        ),
        TableColumnSpec(
          label: 'Кабинет',
          build: (context, r) => Text(r.account.office),
        ),
        TableColumnSpec(
          label: 'Учётная запись',
          build: (context, r) => Text(
            r.account.isBlocked ? 'заблокирована' : 'активна',
            style: r.account.isBlocked
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ],
      cardTitle: (r) => r.fullName,
      cardSubtitle: (r) =>
          '${r.position} · ${reference.departmentName(r.departmentId)}',
      cardChips: (context, r) => [
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.account_circle_outlined, size: 16),
          label: Text(r.account.login),
        ),
        if (r.account.isBlocked)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              Icons.lock_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            label: const Text('заблокирована'),
          ),
      ],
      filters: (context, query, onChanged) => FilterRow(
        children: [
          FilterDropdown<int>(
            label: 'Отдел',
            value: query.departmentId,
            width: 300,
            items: [
              for (final department in reference.allDepartments)
                DropdownMenuItem(
                  value: department.id,
                  child: Text(department.name),
                ),
            ],
            onChanged: (value) =>
                onChanged(query.copyWith(departmentId: value)),
          ),
          FilterDropdown<bool>(
            label: 'Учётная запись',
            value: query.onlyBlocked,
            width: 220,
            items: const [
              DropdownMenuItem(value: true, child: Text('заблокирована')),
              DropdownMenuItem(value: false, child: Text('активна')),
            ],
            onChanged: (value) => onChanged(query.copyWith(onlyBlocked: value)),
          ),
        ],
      ),
    );
  }
}
