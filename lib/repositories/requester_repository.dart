import '../core/exceptions.dart';
import '../core/fault_switch.dart';
import '../data/collection_store.dart';
import '../data/seed_data.dart';
import '../models/page_result.dart';
import '../models/requester.dart';
import '../models/requester_query.dart';
import 'crud_repository.dart';
import 'stored_repository.dart';

/// Договор доступа к заявителям.
abstract interface class RequesterRepository
    implements CrudRepository<Requester, RequesterQuery> {
  /// Действующие заявители — источник выпадающего списка в форме заявки.
  List<Requester> get available;

  int countByDepartment(int departmentId);
}

/// Хранилище заявителей. Уникальность проверяется по полям вложенной
/// учётной записи — стороны связи один к одному.
class PersistentRequesterRepository extends StoredRepository<Requester>
    implements RequesterRepository {
  PersistentRequesterRepository(FaultSwitch faults, CollectionStore store)
    : super(
        faults: faults,
        store: store,
        collection: 'requesters',
        seed: seedRequesters,
        fromJson: Requester.fromJson,
      );

  @override
  String describe(Requester item) => 'заявитель ${item.fullName}';

  /// Имена полей совпадают с именами полей формы, включая вложенные:
  /// «account.login» — это путь до поля внутри группы.
  @override
  void checkUnique(Requester item) {
    final login = item.account.login.trim().toLowerCase();
    final email = item.account.email.trim().toLowerCase();

    if (rows.any(
      (r) => r.id != item.id && r.account.login.trim().toLowerCase() == login,
    )) {
      throw UniqueConstraintException(
        'account.login',
        'Логин ${item.account.login} уже занят',
      );
    }
    if (rows.any(
      (r) => r.id != item.id && r.account.email.trim().toLowerCase() == email,
    )) {
      throw UniqueConstraintException(
        'account.email',
        'Адрес ${item.account.email} уже занят',
      );
    }
  }

  @override
  List<Requester> get available => activeRows;

  @override
  int countByDepartment(int departmentId) => rows
      .where((r) => !r.isDeleted && r.departmentId == departmentId)
      .length;

  @override
  Future<PageResult<Requester>> find(RequesterQuery query) async {
    await Future.delayed(StoredRepository.latency);
    faults.throwIfEnabled();

    var result = rows
        .where((r) => query.includeDeleted || !r.isDeleted)
        .toList();

    // Поиск по фамилии и по логину учётной записи.
    final needle = query.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result
          .where(
            (r) =>
                r.lastName.toLowerCase().contains(needle) ||
                r.account.login.toLowerCase().contains(needle),
          )
          .toList();
    }

    if (query.departmentId != null) {
      result = result
          .where((r) => r.departmentId == query.departmentId)
          .toList();
    }
    if (query.onlyBlocked != null) {
      result = result
          .where((r) => r.account.isBlocked == query.onlyBlocked)
          .toList();
    }

    result.sort((a, b) {
      final compared = switch (query.sortField) {
        'position' => a.position.toLowerCase().compareTo(
          b.position.toLowerCase(),
        ),
        'login' => a.account.login.compareTo(b.account.login),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      };
      return query.sortAscending ? compared : -compared;
    });

    return PageResult.slice(result, query.page, query.size);
  }
}
