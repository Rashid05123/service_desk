import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';

/// Доступ к данным через учебное API.
///
/// Договор `CrudRepository<T, Q>` из ПР2 остался без единого изменения —
/// сменилась только реализация. Все пять сущностей отличаются лишь именем
/// коллекции, разбором записи и телом запроса на запись, поэтому общая
/// часть собрана здесь, а наследнику остаются три поля.
abstract class ApiRepository<T, Q extends ListQuery<Q>>
    implements CrudRepository<T, Q> {
  ApiRepository(this.dio);

  final Dio dio;

  /// Имя коллекции в адресе: `tickets`, `employees`.
  String get collection;

  /// Разбор записи из ответа сервера.
  T fromJson(Map<String, dynamic> json);

  /// Тело запроса на создание и изменение. Отличается от ответа: уходят
  /// идентификаторы связей, приходят развёрнутые объекты.
  Map<String, dynamic> toBody(T item);

  /// Токен последней выборки. Изменяющие операции им не пользуются:
  /// отменять сохранение нельзя — запрос мог дойти до сервера.
  CancelToken? _pendingFind;

  /// Выборка страницы.
  ///
  /// Отбор, сортировка и разбивка на страницы выполняются сервером:
  /// клиент держит в памяти только текущую страницу.
  @override
  Future<PageResult<T>> find(Q query) {
    final token = CancelToken();
    _pendingFind = token;

    return guard(() async {
      final response = await dio.get<dynamic>(
        '/$collection',
        queryParameters: query.toApiParameters(),
        cancelToken: token,
      );
      return _page(response.data, query.size);
    });
  }

  @override
  void cancelPendingFind() {
    _pendingFind?.cancel('условия отбора изменились');
    _pendingFind = null;
  }

  @override
  Future<T?> findById(int id) async {
    try {
      final response = await dio.get<dynamic>('/$collection/$id');
      return fromJson(_object(response.data));
    } on DioException catch (e) {
      final mapped = mapDioError(e);
      // Отсутствие записи — не сбой: экран показывает «запись не найдена»,
      // а не состояние ошибки загрузки.
      if (mapped is NotFoundException) return null;
      throw mapped;
    }
  }

  @override
  Future<T> create(T item) => guard(() async {
    final response = await dio.post<dynamic>(
      '/$collection',
      data: toBody(item),
    );
    return fromJson(_object(response.data));
  });

  @override
  Future<T> update(T item) => guard(() async {
    final response = await dio.put<dynamic>(
      '/$collection/${idOf(item)}',
      data: toBody(item),
    );
    return fromJson(_object(response.data));
  });

  /// Идентификатор записи: нужен, чтобы собрать адрес изменения.
  int idOf(T item);

  @override
  Future<void> softDelete(int id) =>
      guard(() => dio.delete<dynamic>('/$collection/$id'));

  @override
  Future<void> hardDelete(int id) => guard(
    () => dio.delete<dynamic>(
      '/$collection/$id',
      queryParameters: const {'hard': true},
    ),
  );

  @override
  Future<void> restore(int id) =>
      guard(() => dio.post<dynamic>('/$collection/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await dio.post<dynamic>(
      '/$collection/bulk-delete',
      data: {'ids': ids},
    );
    return _object(response.data)['deleted'] as int? ?? 0;
  });

  /// Оболочка списка. Разбирается со значениями по умолчанию: ответ
  /// приходит из внешнего источника, и отсутствующее поле не должно
  /// ронять экран.
  PageResult<T> _page(Object? data, int requestedSize) {
    final map = _object(data);
    final items = map['items'];

    return PageResult(
      items: [
        if (items is List)
          for (final row in items)
            if (row is Map) fromJson(row.cast<String, dynamic>()),
      ],
      page: map['page'] as int? ?? 1,
      size: map['size'] as int? ?? requestedSize,
      total: map['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _object(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    throw const ServerException('Сервер вернул ответ неизвестного вида.');
  }
}
