import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/detail_notifier.dart';
import '../state/load_status.dart';
import 'status_views.dart';

/// Карточка записи, общая для всех пяти сущностей: загрузка по адресу,
/// четыре состояния экрана, возврат к списку с сохранёнными условиями
/// отбора и переход к форме изменения.
class DetailPage<T> extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.listPath,
    required this.titleOf,
    required this.notFoundTitle,
    required this.notFoundDescription,
    required this.idOf,
    required this.content,
  });

  final String listPath;

  /// Заголовок панели. Запись может быть ещё не загружена.
  final String Function(T? item) titleOf;

  final String notFoundTitle;
  final String notFoundDescription;

  final int Function(T item) idOf;

  /// Содержимое карточки: набор блоков, выкладываемых в столбец.
  final List<Widget> Function(BuildContext context, T item) content;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DetailNotifier<T>>();
    // Условия отбора списка остались в адресе карточки — по ним
    // работает возврат.
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: listPath,
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    final item = notifier.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleOf(item)),
        leading: Tooltip(
          message: 'Вернуться к списку',
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(listUri()),
          ),
        ),
        actions: [
          if (item != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.go(
                  Uri(
                    path: '$listPath/${idOf(item)}/edit',
                    queryParameters: listParams.isEmpty ? null : listParams,
                  ).toString(),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить'),
              ),
            ),
        ],
      ),
      body: switch (notifier.status) {
        LoadStatus.idle || LoadStatus.loading => const LoadingView(),
        LoadStatus.error => ErrorView(
          message: notifier.error ?? 'Неизвестная ошибка',
          onRetry: notifier.reload,
        ),
        LoadStatus.success =>
          item == null
              ? EmptyView(
                  title: notFoundTitle,
                  description: notFoundDescription,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    // Содержимое ограничено по ширине и не растягивается
                    // на весь монитор.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: content(context, item),
                      ),
                    ),
                  ),
                ),
      },
    );
  }
}

/// Строка «название — значение» в карточке.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Без Expanded длинное значение переполнит Row.
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка «запись удалена логически» — одинакова во всех карточках.
class DeletedBanner extends StatelessWidget {
  const DeletedBanner({super.key, required this.deletedAt, this.title});

  final DateTime deletedAt;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.delete_outline),
        title: Text(title ?? 'Запись удалена логически'),
        subtitle: Text(
          'Отметка удаления: '
          '${deletedAt.day.toString().padLeft(2, '0')}.'
          '${deletedAt.month.toString().padLeft(2, '0')}.${deletedAt.year}',
        ),
      ),
    );
  }
}
