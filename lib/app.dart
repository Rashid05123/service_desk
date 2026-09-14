import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'widgets/session_guard.dart';

/// Корневой виджет. MaterialApp.router нужен для работы go_router.
///
/// Маршрутизатор передаётся снаружи: он зависит от сессии, а сессия
/// восстанавливается в main до построения дерева виджетов.
class ServiceDeskApp extends StatelessWidget {
  const ServiceDeskApp({super.key, required this.router});

  final GoRouter router;

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
      routerConfig: router,
      // Сроки сессии следят за действиями на любом экране, поэтому
      // обёртка стоит над навигатором, а не внутри отдельного экрана.
      builder: (context, child) =>
          SessionGuard(child: child ?? const SizedBox.shrink()),
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
