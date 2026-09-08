import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../data/seed_data.dart';
import '../models/category.dart';
import '../models/category_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';
import 'stored_repository.dart';

/// Договор доступа к категориям заявок.
abstract interface class CategoryRepository
    implements CrudRepository<TicketCategory, CategoryQuery> {
  /// Действующие категории — то, что предлагается в форме заявки.
  List<TicketCategory> get available;
}

/// Хранилище категорий. На категорию ссылаются и заявки, и компетенции
/// сотрудников, поэтому зависимостей у неё две.
class PersistentCategoryRepository extends StoredRepository<TicketCategory>
    implements CategoryRepository {
  PersistentCategoryRepository(FaultSwitch faults, CollectionStore store)
    : super(
        faults: faults,
        store: store,
        collection: 'categories',
        seed: seedCategories,
        fromJson: TicketCategory.fromJson,
      );

  @override
  String describe(TicketCategory item) => 'категория «${item.name}»';

  @override
  void checkUnique(TicketCategory item) {
    final name = item.name.trim().toLowerCase();
    if (rows.any((c) => c.id != item.id && c.name.trim().toLowerCase() == name)) {
      throw UniqueConstraintException(
        'name',
        'Категория «${item.name}» уже есть в справочнике',
      );
    }
  }

  @override
  List<TicketCategory> get available =>
      activeRows.where((c) => c.isActive).toList();

  @override
  Future<PageResult<TicketCategory>> find(CategoryQuery query) async {
    await Future.delayed(StoredRepository.latency);
    faults.throwIfEnabled();

    var result = rows
        .where((c) => query.includeDeleted || !c.isDeleted)
        .toList();

    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result
          .where(
            (c) =>
                c.name.toLowerCase().contains(needle) ||
                c.description.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.onlyActive != null) {
      result = result.where((c) => c.isActive == query.onlyActive).toList();
    }

    result.sort((a, b) {
      final compared = switch (query.sortField) {
        'slaHours' => a.slaHours.compareTo(b.slaHours),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return query.sortAscending ? compared : -compared;
    });

    return PageResult.slice(result, query.page, query.size);
  }
}
