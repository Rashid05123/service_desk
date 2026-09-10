import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/department.dart';
import '../models/department_query.dart';
import '../repositories/department_repository.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Форма отдела. Уникальны и название, и код: обе проверки выполняет
/// репозиторий, а форма показывает их под соответствующими полями.
class DepartmentFormScreen extends StatelessWidget {
  const DepartmentFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<DepartmentRepository>();

    return FormLoader<Department>(
      id: id,
      load: repository.findById,
      notFoundTitle: 'Отдел не найден',
      notFoundDescription: 'Изменить можно только существующую запись.',
      builder: (context, department) =>
          _DepartmentFormBody(department: department),
    );
  }
}

class _DepartmentFormBody extends StatelessWidget {
  const _DepartmentFormBody({required this.department});

  final Department? department;

  bool get isEditing => department != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<DepartmentRepository>();
    final reference = context.read<ReferenceDataNotifier>();
    final list = context.read<ListNotifier<Department, DepartmentQuery>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: '/departments',
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    return EntityFormScreen(
      title: isEditing ? department!.name : 'Новый отдел',
      subtitle: isEditing
          ? 'Изменение записи справочника'
          : 'Добавление отдела организации',
      submitLabel: isEditing ? 'Сохранить' : 'Добавить',
      onLeave: () => context.go(listUri()),
      initialValues: {
        'name': department?.name ?? '',
        'code': department?.code ?? '',
        'location': department?.location ?? '',
        'phone': department?.phone ?? '',
      },
      fields: [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          helper: 'Уникально в пределах справочника',
          autofocus: true,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите название отдела'),
            (value) => v.length(value, min: 3, max: 80),
          ]),
        ),
        TextFieldSpec(
          name: 'code',
          label: 'Код',
          hintText: 'ITSUP',
          helper: 'Заглавная латиница и цифры, уникален',
          width: FieldWidth.half,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите код отдела'),
            v.code,
          ]),
        ),
        TextFieldSpec(
          name: 'phone',
          label: 'Телефон',
          hintText: '+7 495 000-00-00',
          width: FieldWidth.half,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите телефон'),
            v.phone,
          ]),
        ),
        TextFieldSpec(
          name: 'location',
          label: 'Расположение',
          hintText: 'Корпус А, каб. 104',
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите расположение'),
            (value) => v.length(value, min: 3, max: 60),
          ]),
        ),
      ],
      onSubmit: (values) async {
        final saved = Department(
          id: department?.id ?? 0,
          name: (values['name'] as String? ?? '').trim(),
          code: (values['code'] as String? ?? '').trim(),
          location: (values['location'] as String? ?? '').trim(),
          phone: (values['phone'] as String? ?? '').trim(),
          deletedAt: department?.deletedAt,
        );

        if (isEditing) {
          await repository.update(saved);
        } else {
          await repository.create(saved);
        }
        // Справочник изменился — кэш помечается устаревшим, иначе новая
        // запись не появится в выпадающих списках других форм.
        reference.invalidate();
        await list.load();
        if (context.mounted) context.go(listUri());
      },
    );
  }
}
