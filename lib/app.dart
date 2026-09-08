import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router.dart';

/// Корневой виджет. MaterialApp.router нужен для работы go_router.
class ServiceDeskApp extends StatefulWidget {
  const ServiceDeskApp({super.key, this.storageNotice});

  /// Сообщение хранилища о смене формата данных. Показывается один раз
  /// после запуска: молча терять сохранённые записи нельзя.
  final String? storageNotice;

  @override
  State<ServiceDeskApp> createState() => _ServiceDeskAppState();
}

class _ServiceDeskAppState extends State<ServiceDeskApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final notice = widget.storageNotice;
    if (notice == null) return;

    // Показать всплывающую строку из initState нельзя: дерево ещё
    // не построено.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(notice),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF16607A));
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF16607A),
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: 'Служба технической поддержки',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: appRouter,
      // Русская локаль для календаря в выборе даты.
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: ThemeMode.system,
    );
  }
}
