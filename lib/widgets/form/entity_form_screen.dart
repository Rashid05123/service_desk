import 'package:flutter/material.dart';

import 'entity_form.dart';
import 'field_spec.dart';

/// Каркас экрана формы: заголовок, кнопка возврата и предупреждение
/// о несохранённых изменениях. Общий для всех пяти сущностей — экрану
/// остаётся описать поля и способ сохранения.
class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({
    super.key,
    required this.title,
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
    required this.onLeave,
    required this.submitLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<FieldSpec> fields;
  final FormValues initialValues;

  /// Сохранение записи. Возврат к списку делает сам экран после успеха.
  final Future<void> Function(FormValues values) onSubmit;

  /// Уход с экрана: и по кнопке «Отмена», и по стрелке возврата.
  final VoidCallback onLeave;

  final String submitLabel;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  /// Признак несохранённых изменений приходит из формы: от него зависит
  /// и перехват ухода со страницы, и вопрос пользователю.
  bool _dirty = false;

  /// Подтверждение ухода с незаконченной формы. Возвращает true, если
  /// уходить можно.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Уйти без сохранения?'),
        content: const Text(
          'В форме есть изменения, которые ещё не сохранены. '
          'Если уйти сейчас, они будут потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Уйти без сохранения'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _leave() async {
    if (await _confirmLeave()) widget.onLeave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // canPop: false перехватывает возврат браузера и системную кнопку
    // «назад», пока в форме есть несохранённые изменения.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) widget.onLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          leading: Tooltip(
            message: 'Вернуться к списку',
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _leave,
            ),
          ),
        ),
        body: EntityForm(
          fields: widget.fields,
          initialValues: widget.initialValues,
          onSubmit: widget.onSubmit,
          submitLabel: widget.submitLabel,
          onCancel: _leave,
          onDirtyChanged: (value) => setState(() => _dirty = value),
        ),
      ),
    );
  }
}
