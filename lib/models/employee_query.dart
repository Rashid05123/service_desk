/// Условия отбора сотрудников. Устроен так же, как TicketQuery.
class EmployeeQuery {
  /// Поиск по фамилии и отделу — поля, отличные от идентификатора.
  final String search;

  final String? department;
  final int? supportLine;
  final bool? onlyActive;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  static const List<int> availableSizes = [10, 25, 50];

  static const List<String> sortableFields = [
    'fullName',
    'position',
    'department',
    'supportLine',
  ];

  const EmployeeQuery({
    this.search = '',
    this.department,
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
    Object? department = _unset,
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
      department: department == _unset
          ? this.department
          : department as String?,
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

  int get activeFilterCount {
    var count = 0;
    if (department != null) count++;
    if (supportLine != null) count++;
    if (onlyActive != null) count++;
    if (includeDeleted) count++;
    return count;
  }

  bool get hasAnyCondition => search.trim().isNotEmpty || activeFilterCount > 0;

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (department != null) params['department'] = department!;
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
    final department = params['department'];

    return EmployeeQuery(
      search: params['search'] ?? '',
      department: (department == null || department.isEmpty)
          ? null
          : department,
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
      other.department == department &&
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
    department,
    supportLine,
    onlyActive,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
