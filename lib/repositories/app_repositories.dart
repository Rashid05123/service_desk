import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import 'category_repository.dart';
import 'department_repository.dart';
import 'employee_repository.dart';
import 'requester_repository.dart';
import 'ticket_repository.dart';

/// Пять репозиториев и связи между ними. Собираются в одном месте
/// до запуска приложения: чтобы отдел знал, кто на него ссылается,
/// он должен видеть остальные коллекции, а provider создаёт объекты
/// по требованию и такого порядка не гарантирует.
class AppRepositories {
  AppRepositories(FaultSwitch faults, this.store)
    : departments = PersistentDepartmentRepository(faults, store),
      categories = PersistentCategoryRepository(faults, store),
      employees = PersistentEmployeeRepository(faults, store),
      requesters = PersistentRequesterRepository(faults, store),
      tickets = PersistentTicketRepository(faults, store) {
    _wireDependencies();
  }

  final CollectionStore store;

  final PersistentDepartmentRepository departments;
  final PersistentCategoryRepository categories;
  final PersistentEmployeeRepository employees;
  final PersistentRequesterRepository requesters;
  final PersistentTicketRepository tickets;

  /// Кто на кого ссылается. Отсюда берётся и запрет удаления, и число
  /// связанных записей в сообщении об отказе.
  void _wireDependencies() {
    departments.dependsOn('сотрудников', employees.countByDepartment);
    departments.dependsOn('заявителей', requesters.countByDepartment);

    categories.dependsOn('заявок', tickets.countByCategory);
    categories.dependsOn('сотрудников', employees.countByCategory);

    employees.dependsOn('заявок', tickets.countByEmployee);

    requesters.dependsOn('заявок', tickets.countByRequester);
  }
}
