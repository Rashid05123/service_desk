/// Оболочка страницы выборки, общая для всех сущностей. Поля совпадают
/// с ответом учебного API.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;

  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  int get totalPages => total == 0 ? 1 : (total / size).ceil();

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  /// Для подписи «показаны 11–20 из 137».
  int get firstItemNumber => total == 0 ? 0 : (page - 1) * size + 1;
  int get lastItemNumber => total == 0 ? 0 : firstItemNumber + items.length - 1;

  /// Пустая страница до первой загрузки. Не const: список с параметром
  /// типа T требует обычного конструктора.
  PageResult.empty() : items = <T>[], page = 1, size = 10, total = 0;

  /// Вырезка страницы из отобранного и отсортированного списка.
  /// Верхняя граница обрезается явно: sublist иначе бросает исключение.
  static PageResult<T> slice<T>(List<T> rows, int page, int size) {
    final total = rows.length;
    final from = (page - 1) * size;
    final to = (from + size) > total ? total : (from + size);
    final items = from >= total ? <T>[] : rows.sublist(from, to);
    return PageResult(items: items, page: page, size: size, total: total);
  }
}
