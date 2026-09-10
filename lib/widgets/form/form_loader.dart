import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/reference_data_notifier.dart';
import '../status_views.dart';

/// Загрузка всего, что нужно форме, до её построения.
///
/// Форма изменения строится только после того, как запись получена:
/// если создать поля раньше, контроллеры заполнятся пустыми значениями
/// и такими и останутся — это и есть «форма редактирования открывается
/// пустой». При создании записи загружать нечего, и builder получает null.
///
/// С переходом на сервер к записи добавились справочники: выпадающие
/// списки заполняются из кэша, и до его загрузки строить форму нельзя —
/// выбранное значение не нашлось бы среди вариантов, а выпадающий список
/// на таком значении бросает исключение.
class FormLoader<T> extends StatefulWidget {
  const FormLoader({
    super.key,
    required this.id,
    required this.load,
    required this.builder,
    required this.notFoundTitle,
    required this.notFoundDescription,
    this.prepare,
  });

  /// Идентификатор изменяемой записи; null — создание новой.
  final int? id;

  final Future<T?> Function(int id) load;

  /// Что ещё нужно форме до построения. Форме заявки — свободный
  /// регистрационный номер: его знает только хранилище.
  final Future<void> Function()? prepare;

  final Widget Function(BuildContext context, T? item) builder;

  final String notFoundTitle;
  final String notFoundDescription;

  @override
  State<FormLoader<T>> createState() => _FormLoaderState<T>();
}

/// Что вернула загрузка: запись может отсутствовать и потому, что её
/// создают, и потому, что её нет. Одним `null` эти случаи не различить.
typedef _Loaded<T> = ({bool found, T? item});

class _FormLoaderState<T> extends State<FormLoader<T>> {
  late Future<_Loaded<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant FormLoader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) _future = _load();
  }

  Future<_Loaded<T>> _load() async {
    // Справочники и запись запрашиваются одновременно: они не зависят
    // друг от друга. Отказ справочников здесь не гасится — форма без
    // выпадающих списков бесполезна, и это состояние ошибки.
    final reference = context.read<ReferenceDataNotifier>().ensureLoaded();
    final record = widget.id == null ? null : widget.load(widget.id!);

    await reference;
    await widget.prepare?.call();

    if (record == null) return (found: true, item: null);
    final item = await record;
    return (found: item != null, item: item);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Loaded<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorView(
              message: 'Не удалось открыть форму: ${snapshot.error}',
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }

        final loaded = snapshot.data!;
        if (!loaded.found) {
          return Scaffold(
            body: EmptyView(
              title: widget.notFoundTitle,
              description: widget.notFoundDescription,
            ),
          );
        }
        return widget.builder(context, loaded.item);
      },
    );
  }
}
