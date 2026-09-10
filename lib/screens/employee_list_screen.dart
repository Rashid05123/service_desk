import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_fields.dart';

/// Список сотрудников поддержки.
class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reference = context.watch<ReferenceDataNotifier>();

    return EntityListPage<Employee, EmployeeQuery>(
      path: '/employees',
      title: 'Сотрудники поддержки',
      searchHint: 'Поиск по фамилии и должности',
      createLabel: 'Новый сотрудник',
      parseQuery: EmployeeQuery.fromQueryParameters,
      availableSizes: EmployeeQuery.availableSizes,
      idOf: (e) => e.id,
      describe: (e) => e.fullName,
      isDeleted: (e) => e.isDeleted,
      emptyTitle: 'Сотрудников не найдено',
      emptyDescription: 'В справочнике пока нет ни одной записи.',
      itemsLabel: pluralEmployees,
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (context, e) => Text(e.fullName),
        ),
        TableColumnSpec(
          label: 'Должность',
          sortField: 'position',
          build: (context, e) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(e.position, overflow: TextOverflow.ellipsis),
          ),
        ),
        TableColumnSpec(
          label: 'Отдел',
          build: (context, e) => Text(reference.departmentName(e.departmentId)),
        ),
        TableColumnSpec(
          label: 'Линия',
          sortField: 'supportLine',
          numeric: true,
          build: (context, e) => Text('${e.supportLine}'),
        ),
        TableColumnSpec(
          // Связь многие ко многим: компетенции сотрудника.
          label: 'Компетенции',
          build: (context, e) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              e.categoryIds.isEmpty
                  ? '—'
                  : e.categoryIds.map(reference.categoryName).join(', '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (context, e) => Text(e.email),
        ),
        TableColumnSpec(
          label: 'Работает',
          build: (context, e) => Icon(
            e.isActive
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline,
            size: 18,
            color: e.isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
      cardTitle: (e) => e.fullName,
      cardSubtitle: (e) =>
          '${e.position} · ${reference.departmentName(e.departmentId)}',
      cardChips: (context, e) => [
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('Линия ${e.supportLine}'),
        ),
        for (final categoryId in e.categoryIds)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(reference.categoryName(categoryId)),
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
          FilterDropdown<int>(
            label: 'Компетенция',
            value: query.categoryId,
            width: 260,
            items: [
              for (final category in reference.allCategories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => onChanged(query.copyWith(categoryId: value)),
          ),
          FilterDropdown<int>(
            label: 'Линия поддержки',
            value: query.supportLine,
            width: 180,
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 — приём обращений')),
              DropdownMenuItem(value: 2, child: Text('2 — специалисты')),
              DropdownMenuItem(value: 3, child: Text('3 — эксперты')),
            ],
            onChanged: (value) => onChanged(query.copyWith(supportLine: value)),
          ),
          FilterDropdown<bool>(
            label: 'Работает',
            value: query.onlyActive,
            width: 170,
            items: const [
              DropdownMenuItem(value: true, child: Text('да')),
              DropdownMenuItem(value: false, child: Text('нет')),
            ],
            onChanged: (value) => onChanged(query.copyWith(onlyActive: value)),
          ),
        ],
      ),
    );
  }
}
