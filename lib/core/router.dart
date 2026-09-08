import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/department.dart';
import '../models/employee.dart';
import '../models/requester.dart';
import '../models/ticket.dart';
import '../repositories/category_repository.dart';
import '../repositories/department_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/requester_repository.dart';
import '../repositories/ticket_repository.dart';
import '../screens/category_detail_screen.dart';
import '../screens/category_form_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/department_detail_screen.dart';
import '../screens/department_form_screen.dart';
import '../screens/department_list_screen.dart';
import '../screens/employee_detail_screen.dart';
import '../screens/employee_form_screen.dart';
import '../screens/employee_list_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/requester_detail_screen.dart';
import '../screens/requester_form_screen.dart';
import '../screens/requester_list_screen.dart';
import '../screens/ticket_detail_screen.dart';
import '../screens/ticket_form_screen.dart';
import '../screens/ticket_list_screen.dart';
import '../state/detail_notifier.dart';
import '../widgets/app_shell.dart';

/// Схема маршрутов. У каждой сущности одинаковый набор адресов:
/// список, форма создания, карточка и форма изменения.
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

        ..._entityRoutes<Ticket>(
          path: '/tickets',
          name: 'tickets',
          list: const TicketListScreen(),
          detail: const TicketDetailScreen(),
          form: (id) => TicketFormScreen(id: id),
          loader: (context) => context.read<TicketRepository>().findById,
        ),
        ..._entityRoutes<Employee>(
          path: '/employees',
          name: 'employees',
          list: const EmployeeListScreen(),
          detail: const EmployeeDetailScreen(),
          form: (id) => EmployeeFormScreen(id: id),
          loader: (context) => context.read<EmployeeRepository>().findById,
        ),
        ..._entityRoutes<Requester>(
          path: '/requesters',
          name: 'requesters',
          list: const RequesterListScreen(),
          detail: const RequesterDetailScreen(),
          form: (id) => RequesterFormScreen(id: id),
          loader: (context) => context.read<RequesterRepository>().findById,
        ),
        ..._entityRoutes<Department>(
          path: '/departments',
          name: 'departments',
          list: const DepartmentListScreen(),
          detail: const DepartmentDetailScreen(),
          form: (id) => DepartmentFormScreen(id: id),
          loader: (context) => context.read<DepartmentRepository>().findById,
        ),
        ..._entityRoutes<TicketCategory>(
          path: '/categories',
          name: 'categories',
          list: const CategoryListScreen(),
          detail: const CategoryDetailScreen(),
          form: (id) => CategoryFormScreen(id: id),
          loader: (context) => context.read<CategoryRepository>().findById,
        ),
      ],
    ),
  ],
);

/// Четыре маршрута сущности. Порядок важен: '/tickets/new' объявлен
/// раньше '/tickets/:id', иначе слово new разберётся как идентификатор.
List<RouteBase> _entityRoutes<T>({
  required String path,
  required String name,
  required Widget list,
  required Widget detail,
  required Widget Function(int? id) form,
  required Future<T?> Function(int id) Function(BuildContext context) loader,
}) {
  return [
    GoRoute(path: path, name: name, builder: (context, state) => list),
    GoRoute(path: '$path/new', builder: (context, state) => form(null)),
    GoRoute(
      path: '$path/:id/edit',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) return NotFoundScreen(location: state.uri.toString());
        return form(id);
      },
    ),
    GoRoute(
      path: '$path/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) return NotFoundScreen(location: state.uri.toString());
        // Репозиторий берётся из провайдеров и передаётся в notifier.
        return ChangeNotifierProvider<DetailNotifier<T>>(
          key: ValueKey('$name-$id'),
          create: (context) => DetailNotifier<T>(loader(context))..load(id),
          child: detail,
        );
      },
    ),
  ];
}
