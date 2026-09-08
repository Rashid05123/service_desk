import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Дата и время в виде `18.08.2026 10:30`.
String formatDateTime(DateTime value) =>
    '${formatDate(value)} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

/// Дата в виде `18.08.2026` — так её читает пользователь.
String formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year}';

/// ФИО в виде «Абрамов К. С.» — полное имя не помещается в колонку таблицы.
String shortName(String fullName) {
  final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return fullName;
  final initials = parts.skip(1).map((p) => '${p.characters.first}.').join(' ');
  return '${parts.first} $initials';
}

/// Цвет метки приоритета: роль из схемы темы, а не постоянный цвет.
Color priorityColor(BuildContext context, TicketPriority priority) {
  final scheme = Theme.of(context).colorScheme;
  return switch (priority) {
    TicketPriority.critical => scheme.error,
    TicketPriority.high => scheme.tertiary,
    TicketPriority.normal => scheme.primary,
    TicketPriority.low => scheme.outline,
  };
}

Color statusColor(BuildContext context, TicketStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    TicketStatus.newly => scheme.primary,
    TicketStatus.inProgress => scheme.tertiary,
    TicketStatus.waiting => scheme.secondary,
    TicketStatus.resolved => scheme.outline,
    TicketStatus.closed => scheme.outline,
  };
}

/// Слово «заявка» в правильной форме: 1 заявка, 2 заявки, 5 заявок.
String pluralTickets(int count) => _plural(count, 'заявка', 'заявки', 'заявок');

String pluralSelected(int count) =>
    _plural(count, 'запись', 'записи', 'записей');

String pluralEmployees(int count) =>
    _plural(count, 'сотрудник', 'сотрудника', 'сотрудников');

String pluralDepartments(int count) => _plural(count, 'отдел', 'отдела', 'отделов');

String pluralCategories(int count) =>
    _plural(count, 'категория', 'категории', 'категорий');

String pluralRequesters(int count) =>
    _plural(count, 'заявитель', 'заявителя', 'заявителей');

String _plural(int count, String one, String few, String many) {
  final mod100 = count % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  return switch (count % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}
