import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/page_result.dart';

/// Договор доступа к сотрудникам. Набор операций повторяет
/// TicketRepository: в контракте API все ресурсы устроены одинаково.
abstract interface class EmployeeRepository {
  Future<PageResult<Employee>> find(EmployeeQuery query);

  Future<Employee?> findById(int id);

  Future<Employee> create(Employee employee);

  Future<Employee> update(Employee employee);

  Future<void> softDelete(int id);

  Future<void> hardDelete(int id);

  Future<void> restore(int id);

  Future<int> deleteMany(List<int> ids);

  /// Список отделов для выпадающего списка фильтра.
  Future<List<String>> departments();
}
