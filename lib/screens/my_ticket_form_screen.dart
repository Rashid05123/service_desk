import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart' as v;
import '../models/enums.dart';
import '../models/ticket.dart';
import '../repositories/workspace_api.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/form/entity_form_screen.dart';
import '../widgets/form/field_spec.dart';
import '../widgets/form/form_loader.dart';

/// Подача обращения заявителем.
///
/// В отличие от формы заявки у специалиста здесь нет ни номера, ни
/// статуса, ни исполнителя, ни заявителя: всё это назначает сервер.
/// Скрыть поля недостаточно — сервер игнорирует их, даже если они
/// придут в теле запроса.
class MyTicketFormScreen extends StatelessWidget {
  const MyTicketFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FormLoader<Ticket>(
      id: null,
      load: (_) async => null,
      notFoundTitle: 'Форма недоступна',
      notFoundDescription: 'Обновите страницу.',
      builder: (context, _) => const _MyTicketFormBody(),
    );
  }
}

class _MyTicketFormBody extends StatelessWidget {
  const _MyTicketFormBody();

  static const _priorities = [
    TicketPriority.low,
    TicketPriority.normal,
    TicketPriority.high,
  ];

  @override
  Widget build(BuildContext context) {
    final api = context.read<WorkspaceApi>();
    final reference = context.read<ReferenceDataNotifier>();

    return EntityFormScreen(
      title: 'Новое обращение',
      subtitle: 'Опишите проблему — заявка попадёт к диспетчеру поддержки',
      submitLabel: 'Отправить',
      onLeave: () => context.go('/my'),
      initialValues: const {
        'subject': '',
        'description': '',
        'categoryId': null,
        'priority': TicketPriority.normal,
      },
      fields: [
        TextFieldSpec(
          name: 'subject',
          label: 'Тема',
          helper: 'Коротко, что случилось: «Не печатает принтер в 214»',
          autofocus: true,
          validator: v.all([
            (value) => v.notEmpty(value, 'Укажите тему обращения'),
            (value) => v.length(value, min: 5, max: 120),
          ]),
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          maxLines: 5,
          helper: 'Что делали, что увидели, текст сообщения об ошибке',
          validator: v.all([
            (value) => v.notEmpty(value, 'Опишите проблему'),
            (value) => v.length(value, min: 10, max: 2000),
          ]),
        ),
        SelectFieldSpec(
          name: 'categoryId',
          label: 'Категория',
          width: FieldWidth.half,
          options: (values) => [
            for (final c in reference.categories.where((c) => c.isActive))
              (value: c.id, label: c.name, description: c.description),
          ],
          validator: (value) => v.notEmpty(value, 'Выберите категорию'),
        ),
        EnumFieldSpec<TicketPriority>(
          name: 'priority',
          label: 'Срочность',
          width: FieldWidth.half,
          values: _priorities,
          labelOf: (p) => p.label,
          helper: 'Критический приоритет назначает специалист',
        ),
      ],
      onSubmit: (values) async {
        final created = await api.createOwnTicket(
          subject: (values['subject'] as String? ?? '').trim(),
          description: (values['description'] as String? ?? '').trim(),
          categoryId: values['categoryId'] as int?,
          priority:
              values['priority'] as TicketPriority? ?? TicketPriority.normal,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Обращение зарегистрировано: ${created.number}'),
          ),
        );
        context.go('/my');
      },
    );
  }
}
