/// Общая часть условий отбора: то, что есть у списка любой сущности.
/// Обобщённый экран списка работает только через этот договор, поэтому
/// пятый список не потребовал нового экрана.
///
/// Параметр Q — сам тип условий: методы `with…` возвращают объект того же
/// класса, а не абстракцию.
abstract interface class ListQuery<Q> {
  String get search;

  int get page;

  int get size;

  String get sortField;

  bool get sortAscending;

  bool get includeDeleted;

  /// Сколько фильтров задано — для значка на кнопке «Фильтры».
  int get activeFilterCount;

  bool get hasAnyCondition;

  /// Параметры адресной строки. Значения по умолчанию не пишутся.
  Map<String, String> toQueryParameters();

  Q withSearch(String value);

  Q withPage(int value);

  Q withSize(int value);

  Q withSort(String field, bool ascending);

  Q withIncludeDeleted(bool value);

  /// Условия по умолчанию — кнопка «Сбросить».
  Q cleared();
}

/// Параметры запроса к серверу.
///
/// От [ListQuery.toQueryParameters] отличаются только тем, что страница,
/// её размер и сортировка передаются всегда. В адресной строке значения
/// по умолчанию опускаются, чтобы ссылка оставалась читаемой; серверу же
/// удобнее получать их явно, и совпадение имён параметров с контрактом
/// API здесь не случайно — условия отбора в ПР2 задумывались как
/// будущая строка запроса к серверу.
extension ListQueryApiParameters<Q> on ListQuery<Q> {
  Map<String, dynamic> toApiParameters() => {
    ...toQueryParameters(),
    'page': page,
    'size': size,
    'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
  };
}

/// Размеры страницы, общие для всех списков.
const List<int> kPageSizes = [10, 25, 50];
