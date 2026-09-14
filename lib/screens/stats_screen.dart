import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/app_user.dart';
import '../repositories/workspace_api.dart';
import '../widgets/async_view.dart';

/// Статистика службы поддержки. Экран только администратора.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _view = GlobalKey<AsyncViewState<ServiceStats>>();

  static const _collectionLabels = {
    'tickets': 'Заявки',
    'employees': 'Сотрудники',
    'requesters': 'Заявители',
    'departments': 'Отделы',
    'categories': 'Категории',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => _view.currentState?.reload(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView<ServiceStats>(
        key: _view,
        load: () => context.read<WorkspaceApi>().stats(),
        builder: (context, stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Figure('Заявок в работе и в журнале', stats.total),
                      _Figure('Просрочено', stats.overdue, alert: true),
                      _Figure('Без исполнителя', stats.unassigned),
                      _Figure('Активных сессий', stats.activeSessions),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Bars(
                    title: 'По статусам',
                    rows: [
                      for (final e in stats.byStatus.entries)
                        (
                          label: e.key.label,
                          value: e.value,
                          color: statusColor(context, e.key),
                        ),
                    ],
                  ),
                  _Bars(
                    title: 'По приоритетам',
                    rows: [
                      for (final e in stats.byPriority.entries)
                        (
                          label: e.key.label,
                          value: e.value,
                          color: priorityColor(context, e.key),
                        ),
                    ],
                  ),
                  _Bars(
                    title: 'По категориям',
                    rows: [
                      for (final c in stats.byCategory)
                        (label: c.name, value: c.count, color: null),
                    ],
                  ),
                  _Bars(
                    title: 'Логически удалённые записи',
                    rows: [
                      for (final e in stats.deleted.entries)
                        (
                          label: _collectionLabels[e.key] ?? e.key,
                          value: e.value,
                          color: null,
                        ),
                    ],
                  ),
                  _Bars(
                    title: 'Пользователи по ролям',
                    rows: [
                      for (final role in Role.values)
                        (
                          label: role.label,
                          value: stats.usersByRole[role] ?? 0,
                          color: null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.alert = false});

  final String label;
  final int value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: alert && value > 0 ? scheme.error : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.title, required this.rows});

  final String title;
  final List<({String label, int value, Color? color})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rows.fold<int>(0, (m, r) => r.value > m ? r.value : m);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text(
                        row.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : row.value / max,
                          minHeight: 10,
                          color: row.color ?? theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${row.value}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
