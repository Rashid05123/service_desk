import 'entity.dart';

/// Роль пользователя. Набор функций у ролей разный, а не больший
/// или меньший объём одного и того же: заявитель подаёт обращения,
/// специалист их обрабатывает, администратор управляет системой.
enum Role {
  requester(code: 'requester', label: 'Заявитель'),
  agent(code: 'agent', label: 'Специалист поддержки'),
  admin(code: 'admin', label: 'Администратор');

  const Role({required this.code, required this.label});

  /// Код в ответе сервера.
  final String code;

  final String label;

  /// Неизвестный код — не роль. Подставлять «заявителя по умолчанию»
  /// нельзя: неразобранный ответ не должен давать никаких прав.
  static Role? fromCode(Object? code) {
    for (final role in Role.values) {
      if (role.code == code) return role;
    }
    return null;
  }
}

/// Вошедший пользователь в том виде, в каком его отдаёт сервер.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.employeeId,
    this.requesterId,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final Role role;

  /// Сотрудник поддержки, от имени которого работает специалист.
  final int? employeeId;

  /// Карточка заявителя, от имени которого подаются обращения.
  final int? requesterId;

  /// Разбор ответа сервера. Запись без известной роли не принимается.
  static AppUser? tryParse(Object? json) {
    if (json is! Map) return null;
    final role = Role.fromCode(json['role']);
    if (role == null) return null;

    int? linkId(Object? link) =>
        link is Map ? Json.asIntOrNull(link['id']) : Json.asIntOrNull(link);

    return AppUser(
      id: Json.asInt(json['id']),
      username: Json.asString(json['username']),
      fullName: Json.asString(json['fullName']),
      email: Json.asString(json['email']),
      role: role,
      employeeId: linkId(json['employee'] ?? json['employeeId']),
      requesterId: linkId(json['requester'] ?? json['requesterId']),
    );
  }

  /// Запись для хранилища браузера. Нужна только чтобы нарисовать
  /// интерфейс сразу после перезагрузки страницы: права проверяет сервер.
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.code,
    'employeeId': employeeId,
    'requesterId': requesterId,
  };
}
