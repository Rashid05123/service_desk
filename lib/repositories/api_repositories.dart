import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/department.dart';
import '../models/department_query.dart';
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../models/requester.dart';
import '../models/requester_query.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import 'api_repository.dart';
import 'category_repository.dart';
import 'department_repository.dart';
import 'employee_repository.dart';
import 'requester_repository.dart';
import 'ticket_repository.dart';

/// Пять реализаций договоров доступа к данным поверх учебного API.
///
/// Каждая занимает несколько строк: имя коллекции, разбор записи и тело
/// запроса на запись. Всё остальное — в [ApiRepository]. Тело запроса
/// собирается методом `toJson` самой модели: он и писался как
/// представление на запись, поэтому идентификаторы связей уходят
/// на сервер в том виде, в каком контракт их ждёт.

class ApiTicketRepository extends ApiRepository<Ticket, TicketQuery>
    implements TicketRepository {
  ApiTicketRepository(super.dio);

  @override
  String get collection => 'tickets';

  @override
  Ticket fromJson(Map<String, dynamic> json) => Ticket.fromJson(json);

  @override
  Map<String, dynamic> toBody(Ticket item) => item.toJson();

  @override
  int idOf(Ticket item) => item.id;

  /// Свободный регистрационный номер выдаёт сервер: только он видит все
  /// заявки сразу, включая созданные другими.
  @override
  Future<String> nextNumber() => guard(() async {
    final response = await dio.get<dynamic>('/tickets/next-number');
    final data = response.data;
    return (data is Map ? data['number'] as String? : null) ?? 'SD-000001';
  });
}

class ApiEmployeeRepository extends ApiRepository<Employee, EmployeeQuery>
    implements EmployeeRepository {
  ApiEmployeeRepository(super.dio);

  @override
  String get collection => 'employees';

  @override
  Employee fromJson(Map<String, dynamic> json) => Employee.fromJson(json);

  @override
  Map<String, dynamic> toBody(Employee item) => item.toJson();

  @override
  int idOf(Employee item) => item.id;
}

class ApiRequesterRepository extends ApiRepository<Requester, RequesterQuery>
    implements RequesterRepository {
  ApiRequesterRepository(super.dio);

  @override
  String get collection => 'requesters';

  @override
  Requester fromJson(Map<String, dynamic> json) => Requester.fromJson(json);

  @override
  Map<String, dynamic> toBody(Requester item) => item.toJson();

  @override
  int idOf(Requester item) => item.id;
}

class ApiDepartmentRepository extends ApiRepository<Department, DepartmentQuery>
    implements DepartmentRepository {
  ApiDepartmentRepository(super.dio);

  @override
  String get collection => 'departments';

  @override
  Department fromJson(Map<String, dynamic> json) => Department.fromJson(json);

  @override
  Map<String, dynamic> toBody(Department item) => item.toJson();

  @override
  int idOf(Department item) => item.id;
}

class ApiCategoryRepository extends ApiRepository<TicketCategory, CategoryQuery>
    implements CategoryRepository {
  ApiCategoryRepository(super.dio);

  @override
  String get collection => 'categories';

  @override
  TicketCategory fromJson(Map<String, dynamic> json) =>
      TicketCategory.fromJson(json);

  @override
  Map<String, dynamic> toBody(TicketCategory item) => item.toJson();

  @override
  int idOf(TicketCategory item) => item.id;
}

/// Пять репозиториев одним объектом. Клиенту сервера нечего связывать
/// между собой: ссылочную целостность проверяет сервер, а не набор
/// перекрёстных ссылок внутри приложения.
class ApiRepositories {
  ApiRepositories(Dio dio)
    : tickets = ApiTicketRepository(dio),
      employees = ApiEmployeeRepository(dio),
      requesters = ApiRequesterRepository(dio),
      departments = ApiDepartmentRepository(dio),
      categories = ApiCategoryRepository(dio);

  final ApiTicketRepository tickets;
  final ApiEmployeeRepository employees;
  final ApiRequesterRepository requesters;
  final ApiDepartmentRepository departments;
  final ApiCategoryRepository categories;
}
