import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import 'connection_banner.dart';
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

  /// Последняя загрузка завершилась ошибкой. Нужен, чтобы после
  /// возвращения связи перечитать только экран с ошибкой, а не каждый.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  Future<T> _start() {
    _failed = false;
    final future = widget.load();
    future.then<void>((_) {}, onError: (Object _) => _failed = true);
    return future;
  }

  /// Перечитать данные: после изменения и по кнопке обновления.
  void reload() {
    setState(() => _future = _start());
  }

  @override
  Widget build(BuildContext context) {
    return ReloadOnReconnect(
      onReconnect: () {
        if (_failed) reload();
      },
      child: FutureBuilder<T>(
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
              offline: error is NetworkException,
              onRetry: reload,
            );
          }
          return widget.builder(context, snapshot.data as T);
        },
      ),
    );
  }
}
