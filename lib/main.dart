import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/fault_switch.dart';
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
import 'repositories/category_repository.dart';
import 'repositories/department_repository.dart';
import 'repositories/employee_repository.dart';
import 'repositories/requester_repository.dart';
import 'repositories/ticket_repository.dart';
import 'state/list_notifier.dart';
import 'state/reference_data_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Адрес без решётки: /tickets вместо /#/tickets.
  usePathUrlStrategy();

  // Учебные переключатели отказа и задержки: интерсептор дописывает
  // по ним параметры запроса, которые понимает сервер.
  final faults = FaultSwitch();

  // Единственное место, где приложение меняется при переходе на сервер.
  // Экраны, формы, состояние списка и условия отбора остались теми же:
  // они работают с договором доступа к данным, а не с его реализацией.
  //
  // Было: AppRepositories(faults, PrefsCollectionStore(prefs))
  final dio = buildDio(faults: faults);
  final repositories = AppRepositories.api(dio);

  runApp(
    MultiProvider(
      providers: [
        Provider<FaultSwitch>.value(value: faults),
        Provider<AppRepositories>.value(value: repositories),

        // Экраны работают с договорами, а не с реализациями.
        Provider<TicketRepository>.value(value: repositories.tickets),
        Provider<EmployeeRepository>.value(value: repositories.employees),
        Provider<RequesterRepository>.value(value: repositories.requesters),
        Provider<DepartmentRepository>.value(value: repositories.departments),
        Provider<CategoryRepository>.value(value: repositories.categories),

        ChangeNotifierProvider<ReferenceDataNotifier>(
          create: (_) => ReferenceDataNotifier(repositories),
        ),

        // Состояние списка одно и то же для всех пяти сущностей,
        // различаются только типы.
        ChangeNotifierProvider<ListNotifier<Ticket, TicketQuery>>(
          create: (_) => ListNotifier(
            repository: repositories.tickets,
            idOf: (t) => t.id,
            initialQuery: const TicketQuery(),
            failureMessage: 'Не удалось загрузить список заявок',
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Employee, EmployeeQuery>>(
          create: (_) => ListNotifier(
            repository: repositories.employees,
            idOf: (e) => e.id,
            initialQuery: const EmployeeQuery(),
            failureMessage: 'Не удалось загрузить список сотрудников',
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Requester, RequesterQuery>>(
          create: (_) => ListNotifier(
            repository: repositories.requesters,
            idOf: (r) => r.id,
            initialQuery: const RequesterQuery(),
            failureMessage: 'Не удалось загрузить список заявителей',
          ),
        ),
        ChangeNotifierProvider<ListNotifier<Department, DepartmentQuery>>(
          create: (_) => ListNotifier(
            repository: repositories.departments,
            idOf: (d) => d.id,
            initialQuery: const DepartmentQuery(),
            failureMessage: 'Не удалось загрузить список отделов',
          ),
        ),
        ChangeNotifierProvider<ListNotifier<TicketCategory, CategoryQuery>>(
          create: (_) => ListNotifier(
            repository: repositories.categories,
            idOf: (c) => c.id,
            initialQuery: const CategoryQuery(),
            failureMessage: 'Не удалось загрузить список категорий',
          ),
        ),
      ],
      child: const ServiceDeskApp(),
    ),
  );
}
