import 'list_query.dart';

/// Условия отбора заявителей.
class RequesterQuery implements ListQuery<RequesterQuery> {
  /// Поиск по фамилии и по логину учётной записи.
  @override
  final String search;

  final int? departmentId;

  /// Состояние учётной записи — поле вложенной сущности связи один к одному.
  final bool? onlyBlocked;

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

  static const List<String> sortableFields = ['fullName', 'position', 'login'];

  const RequesterQuery({
    this.search = '',
    this.departmentId,
    this.onlyBlocked,
    this.sortField = 'fullName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  RequesterQuery copyWith({
    String? search,
    Object? departmentId = _unset,
    Object? onlyBlocked = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return RequesterQuery(
      search: search ?? this.search,
      departmentId: departmentId == _unset
          ? this.departmentId
          : departmentId as int?,
      onlyBlocked: onlyBlocked == _unset
          ? this.onlyBlocked
          : onlyBlocked as bool?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  RequesterQuery withSearch(String value) => copyWith(search: value);

  @override
  RequesterQuery withPage(int value) => copyWith(page: value);

  @override
  RequesterQuery withSize(int value) => copyWith(size: value);

  @override
  RequesterQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending, page: page);

  @override
  RequesterQuery withIncludeDeleted(bool value) =>
      copyWith(includeDeleted: value);

  @override
  RequesterQuery cleared() => const RequesterQuery();

  @override
  int get activeFilterCount {
    var count = 0;
    if (departmentId != null) count++;
    if (onlyBlocked != null) count++;
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
    if (onlyBlocked != null) {
      params['blocked'] = onlyBlocked! ? 'true' : 'false';
    }
    if (sortField != 'fullName' || !sortAscending) {
      params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  factory RequesterQuery.fromQueryParameters(Map<String, String> params) {
    final sortParts = (params['sort'] ?? 'fullName,asc').split(',');
    final field = sortParts.first;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;
    final blocked = params['blocked'];

    return RequesterQuery(
      search: params['search'] ?? '',
      departmentId: int.tryParse(params['departmentId'] ?? ''),
      onlyBlocked: blocked == null ? null : blocked == 'true',
      sortField: sortableFields.contains(field) ? field : 'fullName',
      sortAscending: sortParts.length > 1 ? sortParts[1] == 'asc' : true,
      page: page < 1 ? 1 : page,
      size: availableSizes.contains(size) ? size : 10,
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RequesterQuery &&
      other.search == search &&
      other.departmentId == departmentId &&
      other.onlyBlocked == onlyBlocked &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    departmentId,
    onlyBlocked,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
