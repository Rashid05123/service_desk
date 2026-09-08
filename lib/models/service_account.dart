import 'entity.dart';

/// Учётная запись заявителя. Связь один к одному: у заявителя ровно одна
/// запись, у записи ровно один владелец. Отдельного экрана нет — поля
/// редактируются вложенной группой прямо в форме заявителя.
class ServiceAccount {
  /// Доменный логин вида ivanov.ii. Уникален в пределах системы.
  final String login;

  final String email;

  final String phone;

  /// Рабочее место: корпус и кабинет.
  final String office;

  /// Учётная запись заблокирована — заявки от такого пользователя
  /// принимаются, но исполнителю видно предупреждение.
  final bool isBlocked;

  const ServiceAccount({
    required this.login,
    required this.email,
    required this.phone,
    required this.office,
    required this.isBlocked,
  });

  /// Пустая запись для формы создания заявителя.
  const ServiceAccount.empty()
    : login = '',
      email = '',
      phone = '',
      office = '',
      isBlocked = false;

  ServiceAccount copyWith({
    String? login,
    String? email,
    String? phone,
    String? office,
    bool? isBlocked,
  }) {
    return ServiceAccount(
      login: login ?? this.login,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      office: office ?? this.office,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  Map<String, dynamic> toJson() => {
    'login': login,
    'email': email,
    'phone': phone,
    'office': office,
    'isBlocked': isBlocked,
  };

  factory ServiceAccount.fromJson(Map<String, dynamic> json) => ServiceAccount(
    login: Json.asString(json['login']),
    email: Json.asString(json['email']),
    phone: Json.asString(json['phone']),
    office: Json.asString(json['office']),
    isBlocked: Json.asBool(json['isBlocked']),
  );
}
