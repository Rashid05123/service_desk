import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/fault_switch.dart';
import 'core/permissions.dart';
import 'core/router.dart';
import 'models/category.dart';
import 'models/category_query.dart';
import 'models/department.dart';
import 'models/department_query.dart';
import 'models/employee.dart';
import 'models/employee_query.dart';
import 'models/requester.dart';
import 'models/requester_query.dart';
import 'models/ticket.dart';
import 'models/ticket_query.dart';
import 'repositories/app_repositories.dart';
import 'repositories/auth_api.dart';
import 'repositories/category_repository.dart';
import 'repositories/department_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/requester_repository.dart';
import 'repositories/ticket_repository.dart';
import 'repositories/workspace_api.dart';
import 'state/auth_notifier.dart';
import 'state/list_notifier.dart';
import 'state/reference_data_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Адрес без решётки: /tickets вместо /#/tickets.
  usePathUrlStrategy();

  // Учебные переключатели отказа и задержки: интерсептор дописывает
  // по ним параметры запроса, которые понимает сервер.
  final faults = FaultSwitch();

  final prefs = await SharedPreferences.getInstance();

  // Клиент HTTP и сессия ссылаются друг на друга: интерсептору нужен
  // токен сессии, а сессии — клиент для входа и обновления токена.
  // Поэтому сессия передаётся функцией и разрешается при первом запросе.
  late final AuthNotifier auth;
  final dio = buildDio(faults: faults, session: () => auth);
  auth = AuthNotifier(prefs, AuthApi(dio));

  // Сессия восстанавливается до первого кадра: иначе маршрутизатор
  // успел бы отправить вошедшего пользователя на экран входа.
  await auth.restore();

  final repositories = AppRepositories.api(dio);
  final workspace = WorkspaceApi(dio);

  final reference = ReferenceDataNotifier(
    repositories,
    canRead: (collection) {
      final section = sectionPermissions['/$collection'];
      return section != null && auth.can(section.view);
    },
  );

  // Состояние списка одно и то же для всех пяти сущностей, различаются
  // только типы.
  final tickets = ListNotifier<Ticket, TicketQuery>(
    repository: repositories.tickets,
    idOf: (t) => t.id,
    initialQuery: const TicketQuery(),
    failureMessage: 'Не удалось загрузить список заявок',
  );
  final employees = ListNotifier<Employee, EmployeeQuery>(
    repository: repositories.employees,
    idOf: (e) => e.id,
    initialQuery: const EmployeeQuery(),
    failureMessage: 'Не удалось загрузить список сотрудников',
  );
  final requesters = ListNotifier<Requester, RequesterQuery>(
    repository: repositories.requesters,
    idOf: (r) => r.id,
    initialQuery: const RequesterQuery(),
    failureMessage: 'Не удалось загрузить список заявителей',
  );
  final departments = ListNotifier<Department, DepartmentQuery>(
    repository: repositories.departments,
    idOf: (d) => d.id,
    initialQuery: const DepartmentQuery(),
    failureMessage: 'Не удалось загрузить список отделов',
  );
  final categories = ListNotifier<TicketCategory, CategoryQuery>(
    repository: repositories.categories,
    idOf: (c) => c.id,
    initialQuery: const CategoryQuery(),
    failureMessage: 'Не удалось загрузить список категорий',
  );

  // Смена пользователя сбрасывает всё, что загружено для предыдущего:
  // иначе после выхода администратора и входа заявителя на экране на
  // мгновение остались бы чужие списки и справочники.
  var userId = auth.user?.id;
  auth.addListener(() {
    final next = auth.user?.id;
    if (next == userId) return;
    userId = next;
    reference.reset();
    tickets.reset();
    employees.reset();
    requesters.reset();
    departments.reset();
    categories.reset();
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<FaultSwitch>.value(value: faults),
        Provider<AppRepositories>.value(value: repositories),
        Provider<WorkspaceApi>.value(value: workspace),
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),

        // Экраны работают с договорами, а не с реализациями.
        Provider<TicketRepository>.value(value: repositories.tickets),
        Provider<EmployeeRepository>.value(value: repositories.employees),
        Provider<RequesterRepository>.value(value: repositories.requesters),
        Provider<DepartmentRepository>.value(value: repositories.departments),
        Provider<CategoryRepository>.value(value: repositories.categories),

        ChangeNotifierProvider<ReferenceDataNotifier>.value(value: reference),
        ChangeNotifierProvider<ListNotifier<Ticket, TicketQuery>>.value(
          value: tickets,
        ),
        ChangeNotifierProvider<ListNotifier<Employee, EmployeeQuery>>.value(
          value: employees,
        ),
        ChangeNotifierProvider<ListNotifier<Requester, RequesterQuery>>.value(
          value: requesters,
        ),
        ChangeNotifierProvider<ListNotifier<Department, DepartmentQuery>>.value(
          value: departments,
        ),
        ChangeNotifierProvider<
          ListNotifier<TicketCategory, CategoryQuery>
        >.value(value: categories),
      ],
      child: ServiceDeskApp(router: buildRouter(auth)),
    ),
  );
}
