import 'list_query.dart';

/// Условия отбора категорий заявок.
class CategoryQuery implements ListQuery<CategoryQuery> {
  /// Поиск по названию и описанию категории.
  @override
  final String search;

  /// Только действующие категории — те, что предлагаются в форме заявки.
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

  static const List<String> sortableFields = ['name', 'slaHours'];

  const CategoryQuery({
    this.search = '',
    this.onlyActive,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  CategoryQuery copyWith({
    String? search,
    Object? onlyActive = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return CategoryQuery(
      search: search ?? this.search,
      onlyActive: onlyActive == _unset ? this.onlyActive : onlyActive as bool?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  CategoryQuery withSearch(String value) => copyWith(search: value);

  @override
  CategoryQuery withPage(int value) => copyWith(page: value);

  @override
  CategoryQuery withSize(int value) => copyWith(size: value);

  @override
  CategoryQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending, page: page);

  @override
  CategoryQuery withIncludeDeleted(bool value) =>
      copyWith(includeDeleted: value);

  @override
  CategoryQuery cleared() => const CategoryQuery();

  @override
  int get activeFilterCount {
    var count = 0;
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
    if (onlyActive != null) params['active'] = onlyActive! ? 'true' : 'false';
    if (sortField != 'name' || !sortAscending) {
      params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    }
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  factory CategoryQuery.fromQueryParameters(Map<String, String> params) {
    final sortParts = (params['sort'] ?? 'name,asc').split(',');
    final field = sortParts.first;
    final size = int.tryParse(params['size'] ?? '') ?? 10;
    final page = int.tryParse(params['page'] ?? '') ?? 1;
    final active = params['active'];

    return CategoryQuery(
      search: params['search'] ?? '',
      onlyActive: active == null ? null : active == 'true',
      sortField: sortableFields.contains(field) ? field : 'name',
      sortAscending: sortParts.length > 1 ? sortParts[1] == 'asc' : true,
      page: page < 1 ? 1 : page,
      size: availableSizes.contains(size) ? size : 10,
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryQuery &&
      other.search == search &&
      other.onlyActive == onlyActive &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    onlyActive,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
