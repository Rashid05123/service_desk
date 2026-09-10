import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/employee.dart';
import '../models/employee_query.dart';
import '../repositories/employee_repository.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Форма сотрудника поддержки: многие к одному с отделом и многие
/// ко многим с категориями-компетенциями.
class EmployeeFormScreen extends StatelessWidget {
  const EmployeeFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EmployeeRepository>();

    return FormLoader<Employee>(
      id: id,
      load: repository.findById,
      notFoundTitle: 'Сотрудник не найден',
      notFoundDescription: 'Изменить можно только существующую запись.',
      builder: (context, employee) => _EmployeeFormBody(employee: employee),
    );
  }
}

class _EmployeeFormBody extends StatelessWidget {
  const _EmployeeFormBody({required this.employee});

  final Employee? employee;

  bool get isEditing => employee != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EmployeeRepository>();
    final reference = context.read<ReferenceDataNotifier>();
    final list = context.read<ListNotifier<Employee, EmployeeQuery>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: '/employees',
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    return EntityFormScreen(
      title: isEditing ? employee!.fullName : 'Новый сотрудник',
      subtitle: isEditing
          ? 'Изменение записи справочника'
          : 'Добавление сотрудника поддержки',
      submitLabel: isEditing ? 'Сохранить' : 'Добавить',
      onLeave: () => context.go(listUri()),
      initialValues: {
        'fullName': employee?.fullName ?? '',
        'position': employee?.position ?? '',
        'departmentId': employee?.departmentId,
        'email': employee?.email ?? '',
        'phone': employee?.phone ?? '',
        'supportLine': employee?.supportLine ?? 1,
        'categoryIds': [...?employee?.categoryIds],
        'isActive': employee?.isActive ?? true,
      },
      fields: _fields(reference),
      onSubmit: (values) async {
        final saved = Employee(
          id: employee?.id ?? 0,
          fullName: (values['fullName'] as String? ?? '').trim(),
          position: (values['position'] as String? ?? '').trim(),
          departmentId: values['departmentId'] as int? ?? 0,
          email: (values['email'] as String? ?? '').trim(),
          phone: (values['phone'] as String? ?? '').trim(),
          supportLine: values['supportLine'] as int? ?? 1,
          categoryIds: [...?values['categoryIds'] as List<int>?],
          isActive: values['isActive'] as bool? ?? true,
          deletedAt: employee?.deletedAt,
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
      // Многие к одному: отдел выбирается из справочника, а не задаётся
      // строкой — иначе один и тот же отдел напишут тремя способами.
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
      TextFieldSpec(
        name: 'email',
        label: 'Электронная почта',
        helper: 'Уникальна в пределах справочника',
        width: FieldWidth.half,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите адрес почты'),
          v.email,
          (value) => v.length(value, max: 60),
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
      NumberFieldSpec(
        name: 'supportLine',
        label: 'Линия поддержки',
        helper: '1 — приём обращений, 2 — специалисты, 3 — эксперты',
        width: FieldWidth.half,
        validator: v.all([
          (value) => v.notEmpty(value, 'Укажите линию'),
          v.positive,
          (value) => v.range(int.tryParse(value ?? ''), min: 1, max: 3),
        ]),
      ),
      SwitchFieldSpec(
        name: 'isActive',
        label: 'Работает',
        subtitle: 'Уволенного сотрудника нельзя назначить исполнителем',
        width: FieldWidth.half,
      ),
      // Многие ко многим: от этого набора зависит, в каких заявках
      // сотрудник может стать исполнителем.
      MultiSelectFieldSpec(
        name: 'categoryIds',
        label: 'Обслуживаемые категории',
        helper: 'Хотя бы одна: иначе сотрудника некуда назначать',
        options: (_) => [
          for (final category in reference.categories)
            (
              value: category.id,
              label: category.name,
              description: category.description,
            ),
        ],
        validator: (value) =>
            v.notEmpty(value, 'Выберите хотя бы одну категорию'),
      ),
    ];
  }
}
