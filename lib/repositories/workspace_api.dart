import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/ticket.dart';

/// Статистика для администратора.
class ServiceStats {
  const ServiceStats({
    required this.total,
    required this.overdue,
    required this.unassigned,
    required this.byStatus,
    required this.byPriority,
    required this.byCategory,
    required this.deleted,
    required this.usersByRole,
    required this.activeSessions,
  });

  final int total;
  final int overdue;
  final int unassigned;
  final Map<TicketStatus, int> byStatus;
  final Map<TicketPriority, int> byPriority;
  final List<({String name, int count})> byCategory;
  final Map<String, int> deleted;
  final Map<Role, int> usersByRole;
  final int activeSessions;

  static ServiceStats parse(Object? data) {
    if (data is! Map) {
      throw const ServerException('Сервер вернул ответ неизвестного вида.');
    }
    final tickets = data['tickets'] is Map ? data['tickets'] as Map : const {};

    Map<String, int> counts(Object? value) => {
      if (value is Map)
        for (final entry in value.entries)
          '${entry.key}': entry.value is int ? entry.value as int : 0,
    };

    final statuses = counts(tickets['byStatus']);
    final priorities = counts(tickets['byPriority']);
    final users = counts(data['users']);

    return ServiceStats(
      total: tickets['total'] as int? ?? 0,
      overdue: tickets['overdue'] as int? ?? 0,
      unassigned: tickets['unassigned'] as int? ?? 0,
      byStatus: {
        for (final status in TicketStatus.values)
          status: statuses[status.code] ?? 0,
      },
      byPriority: {
        for (final priority in TicketPriority.values)
          priority: priorities[priority.code] ?? 0,
      },
      byCategory: [
        if (data['byCategory'] is List)
          for (final row in data['byCategory'] as List)
            if (row is Map)
              (name: '${row['name']}', count: row['count'] as int? ?? 0),
      ],
      deleted: counts(data['deleted']),
      usersByRole: {
        for (final role in Role.values) role: users[role.code] ?? 0,
      },
      activeSessions: data['activeSessions'] as int? ?? 0,
    );
  }
}

/// Рабочие места ролей: собственные заявки заявителя, очередь
/// специалиста, пользователи и статистика администратора.
///
/// Эти операции не укладываются в договор `CrudRepository`: заявитель
/// не выбирает ни номер, ни статус, ни себя в качестве заявителя —
/// всё это сервер назначает сам по токену.
class WorkspaceApi {
  WorkspaceApi(this._dio);

  final Dio _dio;

  Future<List<Ticket>> myTickets() => guard(() async {
    final response = await _dio.get<dynamic>('/my/tickets');
    return _tickets(response.data);
  });

  Future<Ticket> createOwnTicket({
    required String subject,
    required String description,
    required int? categoryId,
    required TicketPriority priority,
  }) => guard(() async {
    final response = await _dio.post<dynamic>(
      '/my/tickets',
      data: {
        'subject': subject,
        'description': description,
        'categoryId': categoryId,
        'priority': priority.code,
      },
    );
    return Ticket.fromJson(_object(response.data));
  });

  Future<Ticket> reopen(int id) => guard(() async {
    final response = await _dio.post<dynamic>('/my/tickets/$id/reopen');
    return Ticket.fromJson(_object(response.data));
  });

  Future<List<Ticket>> queue() => guard(() async {
    final response = await _dio.get<dynamic>('/my/queue');
    return _tickets(response.data);
  });

  Future<List<AppUser>> users() => guard(() async {
    final response = await _dio.get<dynamic>('/users');
    final items = _object(response.data)['items'];
    return [
      if (items is List)
        for (final row in items) ?AppUser.tryParse(row),
    ];
  });

  Future<AppUser> changeRole(int userId, Role role) => guard(() async {
    final response = await _dio.put<dynamic>(
      '/users/$userId',
      data: {'role': role.code},
    );
    final user = AppUser.tryParse(response.data);
    if (user == null) {
      throw const ServerException('Сервер вернул ответ неизвестного вида.');
    }
    return user;
  });

  Future<ServiceStats> stats() => guard(() async {
    final response = await _dio.get<dynamic>('/stats');
    return ServiceStats.parse(response.data);
  });

  List<Ticket> _tickets(Object? data) {
    final items = _object(data)['items'];
    return [
      if (items is List)
        for (final row in items)
          if (row is Map) Ticket.fromJson(row.cast<String, dynamic>()),
    ];
  }

  Map<String, dynamic> _object(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    throw const ServerException('Сервер вернул ответ неизвестного вида.');
  }
}
