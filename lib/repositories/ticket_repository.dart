import '../models/page_result.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';

/// Договор доступа к заявкам. Интерфейс описан отдельно от реализации:
/// сейчас за ним список в памяти, в ПР4 будет обращение к API.
abstract interface class TicketRepository {
  /// Выборка страницы по условиям отбора.
  Future<PageResult<Ticket>> find(TicketQuery query);

  Future<Ticket?> findById(int id);

  Future<Ticket> create(Ticket ticket);

  Future<Ticket> update(Ticket ticket);

  /// Логическое удаление: запись получает deletedAt и уходит из выборок.
  Future<void> softDelete(int id);

  /// Физическое удаление: запись стирается безвозвратно.
  Future<void> hardDelete(int id);

  /// Восстановление логически удалённой записи.
  Future<void> restore(int id);

  /// Множественное удаление. Возвращает число фактически удалённых
  /// записей: часть переданных могла быть удалена раньше.
  Future<int> deleteMany(List<int> ids);
}
