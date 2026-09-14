import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/ru_localizations.dart';
import 'widgets/connection_banner.dart';
import 'widgets/session_guard.dart';

/// Ширина диалогов задана темой, а не каждому диалогу: иначе длинный
/// вопрос об удалении на мониторе 1920 растягивал окно почти на весь
/// экран, а новый диалог легко забыть ограничить.
const _dialogTheme = DialogThemeData(
  constraints: BoxConstraints(minWidth: 280, maxWidth: 560),
);

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
      // Сроки сессии и связь с сервером касаются любого экрана, поэтому
      // обёртки стоят над навигатором, а не внутри отдельного экрана.
      builder: (context, child) => ConnectionBanner(
        child: SessionGuard(child: child ?? const SizedBox.shrink()),
      ),
      // Русская локаль для календаря в выборе даты.
      locale: const Locale('ru'),
      // Только русский: делегаты всех языков тянули в сборку переводы
      // и таблицы дат восьмидесяти языков (см. core/ru_localizations.dart).
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: ruLocalizationsDelegates,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        dialogTheme: _dialogTheme,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        dialogTheme: _dialogTheme,
      ),
      themeMode: ThemeMode.system,
    );
  }
}
