import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/category.dart';
import '../models/category_query.dart';
import '../repositories/category_repository.dart';
import '../state/list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Форма категории заявок.
class CategoryFormScreen extends StatelessWidget {
  const CategoryFormScreen({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CategoryRepository>();

    return FormLoader<TicketCategory>(
      id: id,
      load: repository.findById,
      notFoundTitle: 'Категория не найдена',
      notFoundDescription: 'Изменить можно только существующую запись.',
      builder: (context, category) => _CategoryFormBody(category: category),
    );
  }
}

class _CategoryFormBody extends StatelessWidget {
  const _CategoryFormBody({required this.category});

  final TicketCategory? category;

  bool get isEditing => category != null;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CategoryRepository>();
    final reference = context.read<ReferenceDataNotifier>();
    final list = context.read<ListNotifier<TicketCategory, CategoryQuery>>();
    final listParams = GoRouterState.of(context).uri.queryParameters;

    String listUri() => Uri(
      path: '/categories',
      queryParameters: listParams.isEmpty ? null : listParams,
    ).toString();

    return EntityFormScreen(
      title: isEditing ? category!.name : 'Новая категория',
      subtitle: isEditing
          ? 'Изменение записи справочника'
          : 'Добавление категории заявок',
      submitLabel: isEditing ? 'Сохранить' : 'Добавить',
      onLeave: () => context.go(listUri()),
      initialValues: {
        'name': category?.name ?? '',
        'description': category?.description ?? '',
        'slaHours': category?.slaHours ?? 24,
        'isActive': category?.isActive ?? true,
      },
      fields: [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          helper: 'Уникально в пределах справочника',
          autofocus: true,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите название категории'),
            (value) => v.length(value, min: 3, max: 60),
          ]),
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          maxLines: 3,
          helper: 'Что относится к этой категории, до 200 символов',
          validator: v.all([
            (value) => v.notEmpty(value, 'Опишите категорию'),
            (value) => v.length(value, min: 10, max: 200),
          ]),
        ),
        NumberFieldSpec(
          name: 'slaHours',
          label: 'Норматив решения',
          suffix: 'ч',
          helper: 'От 1 до 720 часов',
          width: FieldWidth.half,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите норматив'),
            v.positive,
            (value) => v.range(int.tryParse(value ?? ''), min: 1, max: 720),
          ]),
        ),
        const SwitchFieldSpec(
          name: 'isActive',
          label: 'Действует',
          subtitle: 'Закрытая категория не предлагается в новых заявках',
          width: FieldWidth.half,
        ),
      ],
      onSubmit: (values) async {
        final saved = TicketCategory(
          id: category?.id ?? 0,
          name: (values['name'] as String? ?? '').trim(),
          description: (values['description'] as String? ?? '').trim(),
          slaHours: values['slaHours'] as int? ?? 24,
          isActive: values['isActive'] as bool? ?? true,
          deletedAt: category?.deletedAt,
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
