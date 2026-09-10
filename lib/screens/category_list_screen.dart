import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_fields.dart';

/// Список категорий заявок.
class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListPage<TicketCategory, CategoryQuery>(
      path: '/categories',
      title: 'Категории заявок',
      searchHint: 'Поиск по названию и описанию',
      createLabel: 'Новая категория',
      parseQuery: CategoryQuery.fromQueryParameters,
      availableSizes: CategoryQuery.availableSizes,
      idOf: (c) => c.id,
      describe: (c) => c.name,
      isDeleted: (c) => c.isDeleted,
      emptyTitle: 'Категорий не найдено',
      emptyDescription: 'В справочнике пока нет ни одной категории.',
      itemsLabel: pluralCategories,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (context, c) => Text(c.name),
        ),
        TableColumnSpec(
          label: 'Описание',
          build: (context, c) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(c.description, overflow: TextOverflow.ellipsis),
          ),
        ),
        TableColumnSpec(
          label: 'Норматив, ч',
          sortField: 'slaHours',
          numeric: true,
          build: (context, c) => Text('${c.slaHours}'),
        ),
        TableColumnSpec(
          label: 'Заявок',
          numeric: true,
          build: (context, c) => Text('${c.ticketCount}'),
        ),
        TableColumnSpec(
          label: 'Сотрудников',
          numeric: true,
          build: (context, c) => Text('${c.employeeCount}'),
        ),
        TableColumnSpec(
          label: 'Действует',
          build: (context, c) => Icon(
            c.isActive
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline,
            size: 18,
            color: c.isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
      cardTitle: (c) => c.name,
      cardSubtitle: (c) => c.description,
      cardChips: (context, c) => [
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('норматив ${c.slaHours} ч'),
        ),
        Chip(
          visualDensity: VisualDensity.compact,
          label: Text('заявок: ${c.ticketCount}'),
        ),
      ],
      filters: (context, query, onChanged) => FilterRow(
        children: [
          FilterDropdown<bool>(
            label: 'Действует',
            value: query.onlyActive,
            width: 180,
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
