import 'package:flutter/material.dart';

import '../status_views.dart';

/// Загрузка записи перед построением формы.
///
/// Форма изменения строится только после того, как запись получена:
/// если создать поля раньше, контроллеры заполнятся пустыми значениями
/// и такими и останутся — это и есть «форма редактирования открывается
/// пустой». При создании записи загрузки нет, и builder получает null.
class FormLoader<T> extends StatefulWidget {
  const FormLoader({
    super.key,
    required this.id,
    required this.load,
    required this.builder,
    required this.notFoundTitle,
    required this.notFoundDescription,
  });

  /// Идентификатор изменяемой записи; null — создание новой.
  final int? id;

  final Future<T?> Function(int id) load;

  final Widget Function(BuildContext context, T? item) builder;

  final String notFoundTitle;
  final String notFoundDescription;

  @override
  State<FormLoader<T>> createState() => _FormLoaderState<T>();
}

class _FormLoaderState<T> extends State<FormLoader<T>> {
  late Future<T?>? _future = widget.id == null ? null : widget.load(widget.id!);

  @override
  void didUpdateWidget(covariant FormLoader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _future = widget.id == null ? null : widget.load(widget.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return widget.builder(context, null);

    return FutureBuilder<T?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorView(
              message: 'Не удалось загрузить запись: ${snapshot.error}',
              onRetry: () =>
                  setState(() => _future = widget.load(widget.id!)),
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            body: EmptyView(
              title: widget.notFoundTitle,
              description: widget.notFoundDescription,
            ),
          );
        }
        return widget.builder(context, item);
      },
    );
  }
}
