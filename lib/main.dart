import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/fault_switch.dart';
import 'data/collection_store.dart';
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

Future<void> main() async {
  // Хранилище читается до запуска приложения, поэтому нужна ручная
  // инициализация привязки виджетов.
  WidgetsFlutterBinding.ensureInitialized();

  // Адрес без решётки: /tickets вместо /#/tickets.
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final store = PrefsCollectionStore(prefs);
  final faults = FaultSwitch();

  // Репозитории создаются до дерева виджетов и здесь же связываются
  // между собой: отдел должен знать, кто на него ссылается, а provider
  // создаёт объекты по требованию и такого порядка не гарантирует.
  final repositories = AppRepositories(faults, store);

  runApp(
    MultiProvider(
      providers: [
        Provider<FaultSwitch>.value(value: faults),
        Provider<AppRepositories>.value(value: repositories),

        // Экраны работают с договорами, а не с реализациями: в ПР4
        // подменяется только эта часть.
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
      child: ServiceDeskApp(storageNotice: store.consumeNotice()),
    ),
  );
}
