import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/ticket_query.dart';
import '../state/reference_data_notifier.dart';

/// Панель фильтров. Состояния отбора не хранит: получает текущий [query]
/// и сообщает наружу новый через [onChanged].
class TicketFilterPanel extends StatelessWidget {
  final TicketQuery query;
  final ValueChanged<TicketQuery> onChanged;
  final ReferenceDataNotifier reference;

  const TicketFilterPanel({
    super.key,
    required this.query,
    required this.onChanged,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap вместо Row: на узком окне поля переносятся.
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dropdown<int>(
                  context,
                  label: 'Категория',
                  value: query.categoryId,
                  items: [
                    for (final category in reference.categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) =>
                      onChanged(query.copyWith(categoryId: value)),
                  width: 240,
                ),
                _dropdown<TicketPriority>(
                  context,
                  label: 'Приоритет',
                  value: query.priority,
                  items: [
                    for (final priority in TicketPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                  ],
                  onChanged: (value) =>
                      onChanged(query.copyWith(priority: value)),
                  width: 180,
                ),
                _dropdown<TicketStatus>(
                  context,
                  label: 'Статус',
                  value: query.status,
                  items: [
                    for (final status in TicketStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) =>
                      onChanged(query.copyWith(status: value)),
                  width: 190,
                ),
                _dropdown<int>(
                  context,
                  label: 'Исполнитель',
                  value: query.assigneeId,
                  items: [
                    for (final employee in reference.employees)
                      DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.fullName),
                      ),
                  ],
                  onChanged: (value) =>
                      onChanged(query.copyWith(assigneeId: value)),
                  width: 260,
                ),
                _dateField(
                  context,
                  label: 'Создана с',
                  value: query.createdFrom,
                  onChanged: (value) =>
                      onChanged(query.copyWith(createdFrom: value)),
                ),
                _dateField(
                  context,
                  label: 'Создана по',
                  value: query.createdTo,
                  onChanged: (value) =>
                      onChanged(query.copyWith(createdTo: value)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: query.includeDeleted,
                  onChanged: (value) =>
                      onChanged(query.copyWith(includeDeleted: value)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Показывать удалённые заявки',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: query.hasAnyCondition
                      ? () => onChanged(const TicketQuery())
                      : null,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Обычный DropdownButton, а не DropdownButtonFormField: второй
  /// принимает значение только при первом построении, а здесь оно
  /// приходит из адреса и может измениться в любой момент.
  Widget _dropdown<V>(
    BuildContext context, {
    required String label,
    required V? value,
    required List<DropdownMenuItem<V>> items,
    required ValueChanged<V?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<V>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('— любой —')),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime(2026, 8, 15),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            locale: const Locale('ru'),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(
            value == null
                ? '— не задано —'
                : '${value.day.toString().padLeft(2, '0')}.'
                      '${value.month.toString().padLeft(2, '0')}.'
                      '${value.year}',
          ),
        ),
      ),
    );
  }
}
