import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/fault_switch.dart';
import 'repositories/employee_repository.dart';
import 'repositories/in_memory_employee_repository.dart';
import 'repositories/in_memory_ticket_repository.dart';
import 'repositories/ticket_repository.dart';
import 'state/employee_list_notifier.dart';
import 'state/reference_data_notifier.dart';
import 'state/ticket_list_notifier.dart';

void main() {
  // Адрес без решётки: /tickets вместо /#/tickets.
  usePathUrlStrategy();

  runApp(
    // Провайдеры объявлены выше любого экрана, репозитории — раньше
    // notifier-ов, которые их читают.
    MultiProvider(
      providers: [
        Provider<FaultSwitch>(create: (_) => FaultSwitch()),
        Provider<TicketRepository>(
          create: (context) =>
              InMemoryTicketRepository(context.read<FaultSwitch>()),
        ),
        Provider<EmployeeRepository>(
          create: (context) =>
              InMemoryEmployeeRepository(context.read<FaultSwitch>()),
        ),
        ChangeNotifierProvider<ReferenceDataNotifier>(
          create: (context) =>
              ReferenceDataNotifier(context.read<EmployeeRepository>())..load(),
        ),
        ChangeNotifierProvider<TicketListNotifier>(
          create: (context) =>
              TicketListNotifier(context.read<TicketRepository>()),
        ),
        ChangeNotifierProvider<EmployeeListNotifier>(
          create: (context) =>
              EmployeeListNotifier(context.read<EmployeeRepository>()),
        ),
      ],
      child: const ServiceDeskApp(),
    ),
  );
}
