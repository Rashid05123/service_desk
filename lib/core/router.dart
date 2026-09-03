import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../models/ticket.dart';
import '../repositories/employee_repository.dart';
import '../repositories/ticket_repository.dart';
import '../screens/employee_detail_screen.dart';
import '../screens/employee_list_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/ticket_detail_screen.dart';
import '../screens/ticket_list_screen.dart';
import '../state/detail_notifier.dart';
import '../widgets/app_shell.dart';

/// Схема маршрутов. Карточки объявлены отдельными маршрутами верхнего
/// уровня: список и карточка это разные страницы.
final GoRouter appRouter = GoRouter(
  initialLocation: '/tickets',
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
  routes: [
    // Общий каркас с адаптивной навигацией.
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/tickets'),
        GoRoute(
          path: '/tickets',
          name: 'tickets',
          builder: (context, state) => const TicketListScreen(),
        ),
        GoRoute(
          path: '/tickets/:id',
          name: 'ticket',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return NotFoundScreen(location: state.uri.toString());
            }
            // Репозиторий берётся из провайдеров и передаётся в notifier.
            return ChangeNotifierProvider<DetailNotifier<Ticket>>(
              key: ValueKey('ticket-$id'),
              create: (context) => DetailNotifier<Ticket>(
                context.read<TicketRepository>().findById,
              )..load(id),
              child: const TicketDetailScreen(),
            );
          },
        ),
        GoRoute(
          path: '/employees',
          name: 'employees',
          builder: (context, state) => const EmployeeListScreen(),
        ),
        GoRoute(
          path: '/employees/:id',
          name: 'employee',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return NotFoundScreen(location: state.uri.toString());
            }
            return ChangeNotifierProvider<DetailNotifier<Employee>>(
              key: ValueKey('employee-$id'),
              create: (context) => DetailNotifier<Employee>(
                context.read<EmployeeRepository>().findById,
              )..load(id),
              child: const EmployeeDetailScreen(),
            );
          },
        ),
      ],
    ),
  ],
);
