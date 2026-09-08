import 'enums.dart';
import 'list_query.dart';

/// Условия отбора заявок: единственный аргумент метода find репозитория
/// и одновременно параметры адресной строки.
class TicketQuery implements ListQuery<TicketQuery> {
  @override
  final String search;

  final int? categoryId;
  final TicketPriority? priority;
  final TicketStatus? status;
  final int? assigneeId;
  final int? requesterId;
  final DateTime? createdFrom;
  final DateTime? createdTo;

  @override
  final String sortField;

  @override
  final bool sortAscending;

  @override
  final int page;

  @override
  final int size;

  @override
  final bool includeDeleted;

  static const List<int> availableSizes = kPageSizes;

  /// Поля, по которым разрешена сортировка. Всё прочее из адреса
  /// отбрасывается.
  static const List<String> sortableFields = [
    'number',
    'subject',
    'priority',
    'status',
    'createdAt',
    'dueAt',
  ];

  const TicketQuery({
    this.search = '',
    this.categoryId,
    this.priority,
    this.status,
    this.assigneeId,
    this.requesterId,
    this.createdFrom,
    this.createdTo,
    this.sortField = 'createdAt',
    this.sortAscending = false,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  /// Признак «параметр не передан» — отличает «не менять» от «сбросить в null».
  static const _unset = Object();

  TicketQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? priority = _unset,
    Object? status = _unset,
    Object? assigneeId = _unset,
    Object? requesterId = _unset,
    Object? createdFrom = _unset,
    Object? createdTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return TicketQuery(
      search: search ?? this.search,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      priority: priority == _unset
          ? this.priority
          : priority as TicketPriority?,
      status: status == _unset ? this.status : status as TicketStatus?,
      assigneeId: assigneeId == _unset ? this.assigneeId : assigneeId as int?,
      requesterId: requesterId == _unset
          ? this.requesterId
          : requesterId as int?,
      createdFrom: createdFrom == _unset
          ? this.createdFrom
          : createdFrom as DateTime?,
      createdTo: createdTo == _unset ? this.createdTo : createdTo as DateTime?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Изменение условий отбора возвращает на первую страницу, иначе
      // после сужения выборки пользователь увидит пустой список.
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  TicketQuery withSearch(String value) => copyWith(search: value);

  @override
  TicketQuery withPage(int value) => copyWith(page: value);

  @override
  TicketQuery withSize(int value) => copyWith(size: value);

  @override
  TicketQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending, page: page);

  @override
  TicketQuery withIncludeDeleted(bool value) => copyWith(includeDeleted: value);

  @override
  TicketQuery cleared() => const TicketQuery();

  @override
  int get activeFilterCount {
    var count = 0;
    if (categoryId != null) count++;
    if (priority != null) count++;
    if (status != null) count++;
    if (assigneeId != null) count++;
    if (requesterId != null) count++;
    if (createdFrom != null) count++;
    if (createdTo != null) count++;
    if (includeDeleted) count++;
    return count;
  }

  @override
  bool get hasAnyCondition => search.trim().isNotEmpty || activeFilterCount > 0;

  /// Сборка параметров адреса. Значения по умолчанию не пишутся, чтобы
  /// адрес чистого списка выглядел как /tickets.
  @override
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (categoryId != null) params['categoryId'] = '$categoryId';
    if (priority != null) params['priority'] = priority!.code;
    if (status != null) params['status'] = status!.code;
    if (assigneeId != null) params['assigneeId'] = '$assigneeId';
    if (requesterId != null) params['requesterId'] = '$requesterId';
    if (createdFrom != null) params['createdFrom'] = formatDate(createdFrom!);
    if (createdTo != null) params['createdTo'] = formatDate(createdTo!);
    if (sortField != 'createdAt' || sortAscending) {
      params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  /// Разбор адреса. Некорректные значения заменяются значениями
  /// по умолчанию: присланная ссылка не должна ронять приложение.
  factory TicketQuery.fromQueryParameters(Map<String, String> params) {
    final sortParts = (params['sort'] ?? 'createdAt,desc').split(',');
    final field = sortParts.first;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;

    return TicketQuery(
      search: params['search'] ?? '',
      categoryId: int.tryParse(params['categoryId'] ?? ''),
      priority: TicketPriority.fromCode(params['priority']),
      status: TicketStatus.fromCode(params['status']),
      assigneeId: int.tryParse(params['assigneeId'] ?? ''),
      requesterId: int.tryParse(params['requesterId'] ?? ''),
      createdFrom: DateTime.tryParse(params['createdFrom'] ?? ''),
      createdTo: DateTime.tryParse(params['createdTo'] ?? ''),
      sortField: sortableFields.contains(field) ? field : 'createdAt',
      sortAscending: sortParts.length > 1 && sortParts[1] == 'asc',
      page: page < 1 ? 1 : page,
      size: availableSizes.contains(size) ? size : 10,
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  /// Дата в виде `2026-08-18` — то, что читается в адресной строке.
  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  // Сравнение по значению: экран сверяет условия из адреса с применёнными.
  @override
  bool operator ==(Object other) =>
      other is TicketQuery &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.priority == priority &&
      other.status == status &&
      other.assigneeId == assigneeId &&
      other.requesterId == requesterId &&
      other.createdFrom == createdFrom &&
      other.createdTo == createdTo &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    categoryId,
    priority,
    status,
    assigneeId,
    requesterId,
    createdFrom,
    createdTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
