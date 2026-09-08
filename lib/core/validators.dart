/// Проверки полей форм. Вынесены в отдельный файл и переиспользуются
/// всеми формами: одно и то же требование не должно быть записано
/// в приложении дважды.
///
/// Каждая проверка возвращает текст ошибки или `null`, то есть подходит
/// прямо в параметр `validator` виджетов формы.
library;

/// Тип проверки значения произвольного типа.
typedef Validator<T> = String? Function(T? value);

/// Проверка обязательности заполнения. Название notEmpty, а не required:
/// required — модификатор языка, именем функции быть не может.
String? notEmpty(Object? value, [String message = 'Поле обязательно']) {
  if (value == null) return message;
  if (value is String && value.trim().isEmpty) return message;
  if (value is List && value.isEmpty) return message;
  return null;
}

/// Ограничение длины строки. Пустая строка пропускается: за неё отвечает
/// [notEmpty], иначе на одно пустое поле придут две ошибки сразу.
String? length(String? value, {int min = 0, int max = 255}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (text.length < min) return 'Не короче $min символов';
  if (text.length > max) return 'Не длиннее $max символов';
  return null;
}

/// Диапазон целого числа.
String? range(int? value, {required int min, required int max}) {
  if (value == null) return null;
  if (value < min || value > max) return 'Значение от $min до $max';
  return null;
}

/// Целое число из строки. Отдельная проверка нужна потому, что поле
/// ввода всегда отдаёт текст.
String? integer(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (int.tryParse(text) == null) return 'Введите целое число';
  return null;
}

/// Положительное целое: количества, нормативы, номера линий.
String? positive(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  if (parsed == null) return 'Введите целое число';
  if (parsed <= 0) return 'Значение должно быть больше нуля';
  return null;
}

final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// Формат адреса электронной почты.
String? email(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_emailPattern.hasMatch(text)) {
    return 'Адрес вида имя@домен.ru';
  }
  return null;
}

final RegExp _phonePattern = RegExp(r'^\+?[\d\s()-]{7,20}$');

/// Формат телефона: цифры, пробелы, скобки и дефисы.
String? phone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_phonePattern.hasMatch(text)) {
    return 'Телефон вида +7 495 000-00-00';
  }
  return null;
}

final RegExp _loginPattern = RegExp(r'^[a-z][a-z0-9._-]{2,29}$');

/// Доменный логин: латиница в нижнем регистре, цифры, точка, дефис.
String? login(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_loginPattern.hasMatch(text)) {
    return 'Латиница в нижнем регистре, от 3 до 30 символов';
  }
  return null;
}

final RegExp _codePattern = RegExp(r'^[A-Z][A-Z0-9]{1,9}$');

/// Код отдела: заглавная латиница и цифры.
String? code(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_codePattern.hasMatch(text)) {
    return 'Заглавная латиница и цифры, от 2 до 10 символов';
  }
  return null;
}

final RegExp _ticketNumberPattern = RegExp(r'^SD-\d{6}$');

/// Регистрационный номер заявки вида SD-000012.
String? ticketNumber(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!_ticketNumberPattern.hasMatch(text)) {
    return 'Номер вида SD-000012';
  }
  return null;
}

final RegExp _fullNamePattern = RegExp(r'^[А-ЯЁ][а-яё-]+(\s+[А-ЯЁ][а-яё-]+){1,2}$');

/// ФИО: фамилия и имя обязательно, отчество по желанию.
String? fullName(String? value) {
  final text = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return null;
  if (!_fullNamePattern.hasMatch(text)) {
    return 'Фамилия и имя с заглавной буквы, например «Иванов Иван»';
  }
  return null;
}

/// Последовательное применение проверок: возвращается первая ошибка.
/// Так требования к полю читаются списком, а не вложенными условиями.
Validator<T> all<T>(List<Validator<T>> validators) {
  return (value) {
    for (final validate in validators) {
      final error = validate(value);
      if (error != null) return error;
    }
    return null;
  };
}
