import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/enums.dart';
import '../models/ticket.dart';
import '../models/ticket_query.dart';
import '../repositories/ticket_repository.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Форма заявки. Один экран и на создание, и на изменение: различие
/// сводится к тому, передан идентификатор или нет.
///
/// Здесь собраны все три вида связей: категория, исполнитель и заявитель —
/// многие к одному (выпадающие списки), соисполнители — многие ко многим
/// (множественный выбор).
class TicketFormScreen extends StatelessWidget {
  const TicketFormScreen({super.key, this.id});

  final int? id;

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TicketRepository>();

    return FormLoader<Ticket>(
      id: id,
      load: repository.findById,
      notFoundTitle: 'Заявка не найдена',
      notFoundDescription: 'Изменить можно только существующую запись.',
      builder: (context, ticket) => _TicketFormBody(ticket: ticket),
    );
  }
}

class _TicketFormBody extends StatelessWidget {
  const _TicketFormBody({required this.ticket});

  /// null — создание новой заявки.
  final Ticket? ticket;

  bool get isEditing => ticket != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TicketRepository>();
    final reference = context.read<ReferenceDataNotifier>();
    final list = context.read<ListNotifier<Ticket, TicketQuery>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: '/tickets',
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    final now = DateTime.now();

    final initialValues = <String, dynamic>{
      'number': ticket?.number ?? repository.nextNumber(),
      'subject': ticket?.subject ?? '',
      'description': ticket?.description ?? '',
      'categoryId': ticket?.categoryId,
      'priority': ticket?.priority ?? TicketPriority.normal,
      'status': ticket?.status ?? TicketStatus.newly,
      'assigneeId': ticket?.assigneeId,
      'coworkerIds': [...?ticket?.coworkerIds],
      'requesterId': ticket?.requesterId,
      'dueAt': ticket?.dueAt ?? now.add(const Duration(days: 1)),
    };

    return EntityFormScreen(
      title: isEditing ? 'Заявка ${ticket!.number}' : 'Новая заявка',
      subtitle: isEditing
          ? 'Изменение зарегистрированной заявки'
          : 'Регистрация обращения в техподдержку',
      submitLabel: isEditing ? 'Сохранить' : 'Зарегистрировать',
      initialValues: initialValues,
      onLeave: () => context.go(listUri()),
      fields: _fields(reference),
      onSubmit: (values) async {
        final saved = _build(values);
        if (isEditing) {
          await repository.update(saved);
        } else {
          await repository.create(saved);
        }
        // Справочники и список читают те же репозитории, поэтому им
        // достаточно сообщить об изменении.
        reference.refresh();
        await list.load();
        if (context.mounted) context.go(listUri());
      },
    );
  }

  /// Сборка записи из значений формы. Все приведения защищены значениями
  /// по умолчанию: форма гарантирует заполненность, но полагаться на это
  /// при приведении типов не стоит.
  Ticket _build(FormValues values) {
    return Ticket(
      id: ticket?.id ?? 0,
      number: (values['number'] as String? ?? '').trim(),
      subject: (values['subject'] as String? ?? '').trim(),
      description: (values['description'] as String? ?? '').trim(),
      categoryId: values['categoryId'] as int? ?? 0,
      priority: values['priority'] as TicketPriority? ?? TicketPriority.normal,
      status: values['status'] as TicketStatus? ?? TicketStatus.newly,
      assigneeId: values['assigneeId'] as int?,
      coworkerIds: [...?values['coworkerIds'] as List<int>?],
      requesterId: values['requesterId'] as int? ?? 0,
      createdAt: ticket?.createdAt ?? DateTime.now(),
      dueAt: values['dueAt'] as DateTime? ?? DateTime.now(),
      deletedAt: ticket?.deletedAt,
    );
  }

  List<FieldSpec> _fields(ReferenceDataNotifier reference) {
    return [
      TextFieldSpec(
        name: 'number',
        label: 'Регистрационный номер',
        helper: 'Уникален в пределах журнала, вид SD-000012',
        width: FieldWidth.half,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите номер заявки'),
          v.ticketNumber,
        ]),
      ),
      DateFieldSpec(
        name: 'dueAt',
        label: 'Срок решения по SLA',
        width: FieldWidth.half,
        validator: (value) => v.notEmpty(value, 'Укажите срок решения'),
      ),
      TextFieldSpec(
        name: 'subject',
        label: 'Тема',
        helper: 'От 5 до 120 символов',
        autofocus: true,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите тему заявки'),
          (value) => v.length(value, min: 5, max: 120),
        ]),
      ),
      TextFieldSpec(
        name: 'description',
        label: 'Описание',
        maxLines: 5,
        helper: 'От 10 до 1000 символов: что произошло и когда',
        validator: v.all([
          (value) => v.notEmpty(value, 'Опишите обращение'),
          (value) => v.length(value, min: 10, max: 1000),
        ]),
      ),
      // Многие к одному. Значением выбран int, а не объект: сравнение
      // объектов идёт по ==, и без переопределения ==/hashCode выбранное
      // значение перестало бы совпадать с элементом списка.
      SelectFieldSpec(
        name: 'categoryId',
        label: 'Категория',
        helper: 'Определяет, кого можно назначить исполнителем',
        width: FieldWidth.half,
        options: (_) => [
          for (final category in reference.categories)
            (
              value: category.id,
              label: category.name,
              description: 'Норматив: ${category.slaHours} ч',
            ),
        ],
        validator: (value) => v.notEmpty(value, 'Выберите категорию'),
      ),
      SelectFieldSpec(
        name: 'requesterId',
        label: 'Заявитель',
        width: FieldWidth.half,
        options: (_) => [
          for (final requester in reference.requesters)
            (
              value: requester.id,
              label:
                  '${requester.fullName} · '
                  '${reference.departmentName(requester.departmentId)}',
              description: null,
            ),
        ],
        validator: (value) => v.notEmpty(value, 'Выберите заявителя'),
      ),
      // Каскад: список исполнителей сужается до сотрудников,
      // обслуживающих выбранную категорию.
      SelectFieldSpec(
        name: 'assigneeId',
        label: 'Исполнитель',
        helper: 'Только сотрудники с компетенцией по выбранной категории',
        width: FieldWidth.half,
        emptyLabel: '— не назначен —',
        options: (values) => [
          for (final employee in reference.employeesForCategory(
            values['categoryId'] as int?,
          ))
            (
              value: employee.id,
              label: '${employee.fullName} · линия ${employee.supportLine}',
              description: employee.position,
            ),
        ],
      ),
      EnumFieldSpec<TicketPriority>(
        name: 'priority',
        label: 'Приоритет',
        width: FieldWidth.half,
        values: TicketPriority.values,
        labelOf: (value) => value.label,
      ),
      EnumFieldSpec<TicketStatus>(
        name: 'status',
        label: 'Статус',
        width: FieldWidth.half,
        values: TicketStatus.values,
        labelOf: (value) => value.label,
      ),
      // Многие ко многим: готового виджета в Material нет, поэтому набор
      // FilterChip внутри собственного поля формы.
      MultiSelectFieldSpec(
        name: 'coworkerIds',
        label: 'Соисполнители',
        helper: 'Сотрудники, подключённые к заявке дополнительно',
        options: (values) => [
          for (final employee in reference.employeesForCategory(
            values['categoryId'] as int?,
          ))
            if (employee.id != values['assigneeId'])
              (
                value: employee.id,
                label: employee.fullName,
                description: employee.position,
              ),
        ],
      ),
      const NoteSpec(
        name: 'hint',
        label:
            'Смена категории пересобирает списки исполнителя и '
            'соисполнителей: сотрудники без нужной компетенции из них '
            'исчезают, а выбранные ранее снимаются.',
        icon: Icons.link,
      ),
    ];
  }
}
