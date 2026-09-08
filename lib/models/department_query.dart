import 'list_query.dart';

/// Условия отбора отделов. Фильтров, кроме показа удалённых, у справочника
/// нет — но поиск, сортировка и постраничный вывод работают так же, как
/// у остальных списков.
class DepartmentQuery implements ListQuery<DepartmentQuery> {
  /// Поиск по названию и коду отдела.
  @override
  final String search;

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

  static const List<String> sortableFields = ['name', 'code', 'location'];

  const DepartmentQuery({
    this.search = '',
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  DepartmentQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return DepartmentQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  DepartmentQuery withSearch(String value) => copyWith(search: value);

  @override
  DepartmentQuery withPage(int value) => copyWith(page: value);

  @override
  DepartmentQuery withSize(int value) => copyWith(size: value);

  @override
  DepartmentQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending, page: page);

  @override
  DepartmentQuery withIncludeDeleted(bool value) =>
      copyWith(includeDeleted: value);

  @override
  DepartmentQuery cleared() => const DepartmentQuery();

  @override
  int get activeFilterCount => includeDeleted ? 1 : 0;

  @override
  bool get hasAnyCondition => search.trim().isNotEmpty || includeDeleted;

  @override
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (sortField != 'name' || !sortAscending) {
      params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  factory DepartmentQuery.fromQueryParameters(Map<String, String> params) {
    final sortParts = (params['sort'] ?? 'name,asc').split(',');
    final field = sortParts.first;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;

    return DepartmentQuery(
      search: params['search'] ?? '',
      sortField: sortableFields.contains(field) ? field : 'name',
      sortAscending: sortParts.length > 1 ? sortParts[1] == 'asc' : true,
      page: page < 1 ? 1 : page,
      size: availableSizes.contains(size) ? size : 10,
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DepartmentQuery &&
      other.search == search &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
