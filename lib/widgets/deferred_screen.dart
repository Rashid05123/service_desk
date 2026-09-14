import 'package:flutter/material.dart';

import 'status_views.dart';

/// Экран из библиотеки с отложенной загрузкой (`import … deferred as`).
///
/// Код редко нужных разделов — форм, регистрации, экранов администратора —
/// собирается в отдельные файлы и скачивается при первом переходе туда,
/// а не вместе с main.dart.js до первого кадра. Заявитель, который только
/// смотрит свои заявки, код форм справочников не скачивает вовсе.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.name,
    required this.load,
    required this.builder,
  });

  /// Имя библиотеки: по нему запоминается, что она уже загружена.
  final String name;

  final Future<void> Function() load;

  final WidgetBuilder builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  /// Загруженные библиотеки. Без этого повторный переход на форму на один
  /// кадр показывал бы индикатор: FutureBuilder начинает с ожидания даже
  /// для уже завершённой загрузки.
  static final Set<String> _loaded = {};

  Future<void>? _future;

  @override
  void initState() {
    super.initState();
    if (!_loaded.contains(widget.name)) _future = _start();
  }

  Future<void> _start() => widget.load().then((_) => _loaded.add(widget.name));

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return widget.builder(context);

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Часть сборки не скачалась: пропала сеть или на сервере
          // лежит сборка новее той, что открыта во вкладке.
          return Scaffold(
            body: ErrorView(
              message: 'Не удалось загрузить раздел: ${snapshot.error}',
              offline: true,
              onRetry: () => setState(() => _future = _start()),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        return widget.builder(context);
      },
    );
  }
}
