import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/requester.dart';
import '../models/requester_query.dart';
import '../models/service_account.dart';
import '../repositories/requester_repository.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Форма заявителя. Учётная запись — связь один к одному — редактируется
/// вложенной группой полей прямо здесь: отдельного экрана у неё нет.
class RequesterFormScreen extends StatelessWidget {
  const RequesterFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RequesterRepository>();

    return FormLoader<Requester>(
      id: id,
      load: repository.findById,
      notFoundTitle: 'Заявитель не найден',
      notFoundDescription: 'Изменить можно только существующую запись.',
      builder: (context, requester) => _RequesterFormBody(requester: requester),
    );
  }
}

class _RequesterFormBody extends StatelessWidget {
  const _RequesterFormBody({required this.requester});

  final Requester? requester;

  bool get isEditing => requester != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<RequesterRepository>();
    final reference = context.read<ReferenceDataNotifier>();
    final list = context.read<ListNotifier<Requester, RequesterQuery>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: '/requesters',
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    final account = requester?.account ?? const ServiceAccount.empty();

    return EntityFormScreen(
      title: isEditing ? requester!.fullName : 'Новый заявитель',
      subtitle: isEditing
          ? 'Изменение записи вместе с учётной записью'
          : 'Добавление заявителя и его учётной записи',
      submitLabel: isEditing ? 'Сохранить' : 'Добавить',
      onLeave: () => context.go(listUri()),
      // Ключи вложенных полей записываются через точку — так же они
      // приходят в ошибке уникальности из репозитория.
      initialValues: {
        'fullName': requester?.fullName ?? '',
        'position': requester?.position ?? '',
        'departmentId': requester?.departmentId,
        'note': requester?.note ?? '',
        'account.login': account.login,
        'account.email': account.email,
        'account.phone': account.phone,
        'account.office': account.office,
        'account.isBlocked': account.isBlocked,
      },
      fields: _fields(reference),
      onSubmit: (values) async {
        final saved = Requester(
          id: requester?.id ?? 0,
          fullName: (values['fullName'] as String? ?? '').trim(),
          position: (values['position'] as String? ?? '').trim(),
          departmentId: values['departmentId'] as int? ?? 0,
          note: (values['note'] as String? ?? '').trim(),
          account: ServiceAccount(
            login: (values['account.login'] as String? ?? '').trim(),
            email: (values['account.email'] as String? ?? '').trim(),
            phone: (values['account.phone'] as String? ?? '').trim(),
            office: (values['account.office'] as String? ?? '').trim(),
            isBlocked: values['account.isBlocked'] as bool? ?? false,
          ),
          deletedAt: requester?.deletedAt,
        );

        if (isEditing) {
          await repository.update(saved);
        } else {
          await repository.create(saved);
        }
        reference.refresh();
        await list.load();
        if (context.mounted) context.go(listUri());
      },
    );
  }

  List<FieldSpec> _fields(ReferenceDataNotifier reference) {
    return [
      TextFieldSpec(
        name: 'fullName',
        label: 'ФИО',
        hintText: 'Иванов Иван Иванович',
        autofocus: true,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите ФИО'),
          (value) => v.length(value, min: 5, max: 100),
          v.fullName,
        ]),
      ),
      TextFieldSpec(
        name: 'position',
        label: 'Должность',
        width: FieldWidth.half,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите должность'),
          (value) => v.length(value, min: 3, max: 80),
        ]),
      ),
      SelectFieldSpec(
        name: 'departmentId',
        label: 'Отдел',
        width: FieldWidth.half,
        options: (_) => [
          for (final department in reference.departments)
            (
              value: department.id,
              label: '${department.name} (${department.code})',
              description: department.location,
            ),
        ],
        validator: (value) => v.notEmpty(value, 'Выберите отдел'),
      ),
      // Связь один к одному: вложенная группа полей.
      SectionSpec(
        name: 'account',
        label: 'Учётная запись',
        helper:
            'Принадлежит только этому заявителю. Логин и адрес почты '
            'уникальны в пределах системы.',
        icon: Icons.account_circle_outlined,
        fields: [
          TextFieldSpec(
            name: 'account.login',
            label: 'Логин',
            hintText: 'ivanov.ii',
            width: FieldWidth.half,
            validator: v.all([
              (value) => v.notEmpty(value, 'Укажите логин'),
              v.login,
            ]),
          ),
          TextFieldSpec(
            name: 'account.email',
            label: 'Электронная почта',
            width: FieldWidth.half,
            validator: v.all([
              (value) => v.notEmpty(value, 'Укажите адрес почты'),
              v.email,
              (value) => v.length(value, max: 60),
            ]),
          ),
          TextFieldSpec(
            name: 'account.phone',
            label: 'Телефон',
            hintText: '+7 495 000-00-00',
            width: FieldWidth.half,
            validator: v.all([
              (value) => v.notEmpty(value, 'Укажите телефон'),
              v.phone,
            ]),
          ),
          TextFieldSpec(
            name: 'account.office',
            label: 'Рабочее место',
            hintText: 'Корпус Б, каб. 201',
            width: FieldWidth.half,
            validator: v.all([
              (value) => v.notEmpty(value, 'Укажите рабочее место'),
              (value) => v.length(value, min: 3, max: 60),
            ]),
          ),
          const SwitchFieldSpec(
            name: 'account.isBlocked',
            label: 'Учётная запись заблокирована',
            subtitle: 'Заявки принимаются, но исполнителю видно об этом',
          ),
        ],
      ),
      TextFieldSpec(
        name: 'note',
        label: 'Примечание',
        maxLines: 3,
        helper: 'Необязательное поле, до 300 символов',
        validator: (value) => v.length(value, max: 300),
      ),
    ];
  }
}
