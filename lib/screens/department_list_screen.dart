import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../models/department.dart';
import '../models/department_query.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';

/// Список отделов. На отдел ссылаются сотрудники и заявители, поэтому
/// в таблице видно число связанных записей — тех самых, из-за которых
/// удаление будет отклонено.
class DepartmentListScreen extends StatelessWidget {
  const DepartmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Число ссылок приходит с сервера вместе с записью: считать его
    // на клиенте пришлось бы перебором чужих коллекций, которых
    // у клиента больше нет.
    int linked(Department d) => d.employeeCount + d.requesterCount;

    return EntityListPage<Department, DepartmentQuery>(
      path: '/departments',
      title: 'Отделы',
      searchHint: 'Поиск по названию и коду отдела',
      createLabel: 'Новый отдел',
      parseQuery: DepartmentQuery.fromQueryParameters,
      availableSizes: DepartmentQuery.availableSizes,
      idOf: (d) => d.id,
      describe: (d) => d.name,
      isDeleted: (d) => d.isDeleted,
      emptyTitle: 'Отделов не найдено',
      emptyDescription: 'В справочнике пока нет ни одного отдела.',
      itemsLabel: pluralDepartments,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (context, d) => Text(d.name),
        ),
        TableColumnSpec(
          label: 'Код',
          sortField: 'code',
          build: (context, d) => Text(d.code),
        ),
        TableColumnSpec(
          label: 'Расположение',
          sortField: 'location',
          build: (context, d) => Text(d.location),
        ),
        TableColumnSpec(label: 'Телефон', build: (context, d) => Text(d.phone)),
        TableColumnSpec(
          label: 'Сотрудников',
          numeric: true,
          build: (context, d) => Text('${d.employeeCount}'),
        ),
        TableColumnSpec(
          label: 'Заявителей',
          numeric: true,
          build: (context, d) => Text('${d.requesterCount}'),
        ),
      ],
      cardTitle: (d) => '${d.name} (${d.code})',
      cardSubtitle: (d) => '${d.location} · ${d.phone}',
      cardChips: (context, d) => [
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.link, size: 16),
          label: Text('связанных записей: ${linked(d)}'),
        ),
      ],
    );
  }
}
