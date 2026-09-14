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
import '../screens/category_list_screen.dart';
import '../screens/department_detail_screen.dart';
import '../screens/department_list_screen.dart';
import '../screens/employee_detail_screen.dart';
import '../screens/employee_list_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_tickets_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/queue_screen.dart';
import '../screens/requester_detail_screen.dart';
import '../screens/requester_list_screen.dart';
import '../screens/ticket_detail_screen.dart';
import '../screens/ticket_list_screen.dart';
import '../state/auth_notifier.dart';
import '../state/detail_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/app_shell.dart';
import '../widgets/deferred_screen.dart';
import 'route_guard.dart';

// Отложенная загрузка (ПР6): формы, регистрация и экраны администратора
// нужны не каждому и не при каждом входе. Их код уходит из main.dart.js
// в отдельные части и скачивается при первом переходе на экран.
import '../screens/category_form_screen.dart' deferred as category_form;
import '../screens/department_form_screen.dart' deferred as department_form;
import '../screens/employee_form_screen.dart' deferred as employee_form;
import '../screens/my_ticket_form_screen.dart' deferred as my_ticket_form;
import '../screens/register_screen.dart' deferred as register;
import '../screens/requester_form_screen.dart' deferred as requester_form;
import '../screens/stats_screen.dart' deferred as stats;
import '../screens/ticket_form_screen.dart' deferred as ticket_form;
import '../screens/users_screen.dart' deferred as users;

/// Схема маршрутов с защитой.
///
/// `redirect` вызывается перед каждым переходом — и по кнопке, и при
/// вводе адреса вручную, и при открытии ссылки в новой вкладке. Поэтому
/// проверка стоит здесь, а не в `build` экрана: там экран успел бы
/// построиться и мелькнуть до перехода на экран отказа.
///
/// `refreshListenable` заставляет пересчитать `redirect` при каждом
/// изменении сессии: после входа пользователь уходит с экрана входа,
/// после выхода — на него, без ручных переходов в коде экранов.
GoRouter buildRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) => guardRoute(
      loggedIn: auth.isAuthenticated,
      role: auth.role,
      uri: state.uri,
    ),
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => DeferredScreen(
          name: 'register',
          load: register.loadLibrary,
          builder: (_) => register.RegisterScreen(),
        ),
      ),

      // Общий каркас с шапкой и навигацией по разделам роли.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/forbidden',
            builder: (context, state) =>
                ForbiddenScreen(from: state.uri.queryParameters['from']),
          ),

          // Заявитель.
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyTicketsScreen(),
          ),
          GoRoute(
            path: '/my/new',
            builder: (context, state) => DeferredScreen(
              name: 'my_ticket_form',
              load: my_ticket_form.loadLibrary,
              builder: (_) => my_ticket_form.MyTicketFormScreen(),
            ),
          ),

          // Специалист поддержки.
          GoRoute(
            path: '/queue',
            builder: (context, state) => const QueueScreen(),
          ),

          // Администратор.
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => DeferredScreen(
              name: 'users',
              load: users.loadLibrary,
              builder: (_) => users.UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/stats',
            builder: (context, state) => DeferredScreen(
              name: 'stats',
              load: stats.loadLibrary,
              builder: (_) => stats.StatsScreen(),
            ),
          ),

          ..._entityRoutes<Ticket>(
            path: '/tickets',
            name: 'tickets',
            list: const TicketListScreen(),
            detail: const TicketDetailScreen(),
            form: (id) => DeferredScreen(
              name: 'ticket_form',
              load: ticket_form.loadLibrary,
              builder: (_) => ticket_form.TicketFormScreen(id: id),
            ),
            loader: (context) => context.read<TicketRepository>().findById,
          ),
          ..._entityRoutes<Employee>(
            path: '/employees',
            name: 'employees',
            list: const EmployeeListScreen(),
            detail: const EmployeeDetailScreen(),
            form: (id) => DeferredScreen(
              name: 'employee_form',
              load: employee_form.loadLibrary,
              builder: (_) => employee_form.EmployeeFormScreen(id: id),
            ),
            loader: (context) => context.read<EmployeeRepository>().findById,
          ),
          ..._entityRoutes<Requester>(
            path: '/requesters',
            name: 'requesters',
            list: const RequesterListScreen(),
            detail: const RequesterDetailScreen(),
            form: (id) => DeferredScreen(
              name: 'requester_form',
              load: requester_form.loadLibrary,
              builder: (_) => requester_form.RequesterFormScreen(id: id),
            ),
            loader: (context) => context.read<RequesterRepository>().findById,
          ),
          ..._entityRoutes<Department>(
            path: '/departments',
            name: 'departments',
            list: const DepartmentListScreen(),
            detail: const DepartmentDetailScreen(),
            form: (id) => DeferredScreen(
              name: 'department_form',
              load: department_form.loadLibrary,
              builder: (_) => department_form.DepartmentFormScreen(id: id),
            ),
            loader: (context) => context.read<DepartmentRepository>().findById,
          ),
          ..._entityRoutes<TicketCategory>(
            path: '/categories',
            name: 'categories',
            list: const CategoryListScreen(),
            detail: const CategoryDetailScreen(),
            form: (id) => DeferredScreen(
              name: 'category_form',
              load: category_form.loadLibrary,
              builder: (_) => category_form.CategoryFormScreen(id: id),
            ),
            loader: (context) => context.read<CategoryRepository>().findById,
          ),
        ],
      ),
    ],
  );
}

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
          create: (context) => DetailNotifier<T>(
            loader(context),
            prepare: context.read<ReferenceDataNotifier>().ensureLoaded,
          )..load(id),
          child: detail,
        );
      },
    ),
  ];
}
