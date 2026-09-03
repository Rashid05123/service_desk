/// Статус и приоритет заявки. У каждого значения есть код для адресной
/// строки, подпись для пользователя и порядковый номер для сортировки.
library;

enum TicketStatus {
  newly(code: 'new', label: 'Новая', sortIndex: 0),
  inProgress(code: 'in_progress', label: 'В работе', sortIndex: 1),
  waiting(code: 'waiting', label: 'Ожидает ответа', sortIndex: 2),
  resolved(code: 'resolved', label: 'Решена', sortIndex: 3),
  closed(code: 'closed', label: 'Закрыта', sortIndex: 4);

  const TicketStatus({
    required this.code,
    required this.label,
    required this.sortIndex,
  });

  final String code;
  final String label;
  final int sortIndex;

  /// Разбор кода из адреса. Неизвестный код означает незаданный фильтр.
  static TicketStatus? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final value in TicketStatus.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

enum TicketPriority {
  low(code: 'low', label: 'Низкий', sortIndex: 0),
  normal(code: 'normal', label: 'Обычный', sortIndex: 1),
  high(code: 'high', label: 'Высокий', sortIndex: 2),
  critical(code: 'critical', label: 'Критический', sortIndex: 3);

  const TicketPriority({
    required this.code,
    required this.label,
    required this.sortIndex,
  });

  final String code;
  final String label;
  final int sortIndex;

  static TicketPriority? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final value in TicketPriority.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
