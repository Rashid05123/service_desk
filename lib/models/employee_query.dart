import 'list_query.dart';

/// Условия отбора сотрудников. Устроен так же, как TicketQuery.
class EmployeeQuery implements ListQuery<EmployeeQuery> {
  /// Поиск по фамилии и должности — поля, отличные от идентификатора.
  @override
  final String search;

  /// Фильтр по отделу. Многие к одному: хранится ссылка, а не название.
  final int? departmentId;

  /// Фильтр по компетенции — сторона связи многие ко многим.
  final int? categoryId;

  final int? supportLine;
  final bool? onlyActive;

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

  static const List<String> sortableFields = [
    'fullName',
    'position',
    'supportLine',
    'email',
  ];

  const EmployeeQuery({
    this.search = '',
    this.departmentId,
    this.categoryId,
    this.supportLine,
    this.onlyActive,
    this.sortField = 'fullName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  EmployeeQuery copyWith({
    String? search,
    Object? departmentId = _unset,
    Object? categoryId = _unset,
    Object? supportLine = _unset,
    Object? onlyActive = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return EmployeeQuery(
      search: search ?? this.search,
      departmentId: departmentId == _unset
          ? this.departmentId
          : departmentId as int?,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      supportLine: supportLine == _unset
          ? this.supportLine
          : supportLine as int?,
      onlyActive: onlyActive == _unset ? this.onlyActive : onlyActive as bool?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  EmployeeQuery withSearch(String value) => copyWith(search: value);

  @override
  EmployeeQuery withPage(int value) => copyWith(page: value);

  @override
  EmployeeQuery withSize(int value) => copyWith(size: value);

  @override
  EmployeeQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending, page: page);

  @override
  EmployeeQuery withIncludeDeleted(bool value) =>
      copyWith(includeDeleted: value);

  @override
  EmployeeQuery cleared() => const EmployeeQuery();

  @override
  int get activeFilterCount {
    var count = 0;
    if (departmentId != null) count++;
    if (categoryId != null) count++;
    if (supportLine != null) count++;
    if (onlyActive != null) count++;
    if (includeDeleted) count++;
    return count;
  }

  @override
  bool get hasAnyCondition => search.trim().isNotEmpty || activeFilterCount > 0;

  @override
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (departmentId != null) params['departmentId'] = '$departmentId';
    if (categoryId != null) params['categoryId'] = '$categoryId';
    if (supportLine != null) params['supportLine'] = '$supportLine';
    if (onlyActive != null) params['active'] = onlyActive! ? 'true' : 'false';
    if (sortField != 'fullName' || !sortAscending) {
      params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  factory EmployeeQuery.fromQueryParameters(Map<String, String> params) {
    final sortParts = (params['sort'] ?? 'fullName,asc').split(',');
    final field = sortParts.first;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;
    final active = params['active'];

    return EmployeeQuery(
      search: params['search'] ?? '',
      departmentId: int.tryParse(params['departmentId'] ?? ''),
      categoryId: int.tryParse(params['categoryId'] ?? ''),
      supportLine: int.tryParse(params['supportLine'] ?? ''),
      onlyActive: active == null ? null : active == 'true',
      sortField: sortableFields.contains(field) ? field : 'fullName',
      sortAscending: sortParts.length > 1 ? sortParts[1] == 'asc' : true,
      page: page < 1 ? 1 : page,
      size: availableSizes.contains(size) ? size : 10,
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EmployeeQuery &&
      other.search == search &&
      other.departmentId == departmentId &&
      other.categoryId == categoryId &&
      other.supportLine == supportLine &&
      other.onlyActive == onlyActive &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    departmentId,
    categoryId,
    supportLine,
    onlyActive,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
