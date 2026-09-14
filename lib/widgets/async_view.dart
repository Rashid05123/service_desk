import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import 'status_views.dart';

/// Загрузка данных экрана с тремя состояниями: загрузка, ошибка, данные.
///
/// Нужна рабочим местам ролей, которым не подходит общий экран списка:
/// у них нет ни поиска, ни страниц, но загрузка и отказ те же.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  /// Перечитать данные: после изменения и по кнопке обновления.
  void reload() {
    setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final error = snapshot.error;
        if (error != null) {
          return ErrorView(
            message: '$error',
            forbidden: error is ForbiddenException,
            onRetry: reload,
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
