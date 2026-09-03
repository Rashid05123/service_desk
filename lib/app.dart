import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router.dart';

/// Корневой виджет. MaterialApp.router нужен для работы go_router.
class ServiceDeskApp extends StatelessWidget {
  const ServiceDeskApp({super.key});

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
      routerConfig: appRouter,
      // Русская локаль для календаря в фильтре по дате.
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
