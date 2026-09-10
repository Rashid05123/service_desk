import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exceptions.dart';
import '../../core/breakpoints.dart';
import '../../core/exceptions.dart';
import '../../core/formatting.dart';
import 'field_spec.dart';

/// Общий виджет формы для всех сущностей. Экран передаёт список описаний
/// полей и начальные значения; разметка, проверка, предупреждение
/// о несохранённых изменениях и обработка отправки — здесь.
///
/// Форма создания и форма изменения — один и тот же виджет: различаются
/// только начальные значения и подпись кнопки.
class EntityForm extends StatefulWidget {
  const EntityForm({
    super.key,
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
    required this.submitLabel,
    this.onCancel,
    this.onDirtyChanged,
  });

  final List<FieldSpec> fields;

  /// Начальные значения. При изменении записи форма строится только
  /// после её загрузки — иначе поля успеют заполниться пустыми
  /// значениями и останутся такими.
  final FormValues initialValues;

  /// Сохранение. Ошибку уникальности следует бросать
  /// [UniqueConstraintException] — форма покажет её под нужным полем.
  final Future<void> Function(FormValues values) onSubmit;

  final String submitLabel;

  final VoidCallback? onCancel;

  /// Сообщение экрану о появлении или исчезновении несохранённых
  /// изменений: от этого зависит, перехватывать ли уход со страницы.
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<EntityForm> createState() => EntityFormState();
}

class EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  late final FormValues _values = {...widget.initialValues};

  /// Ошибки, пришедшие из репозитория: уникальность номера заявки,
  /// логина, адреса почты. Показываются как обычные ошибки поля, а не
  /// сообщением наверху формы.
  final Map<String, String> _storageErrors = {};

  bool _dirty = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final field in _leafFields(widget.fields)) {
      if (field is TextFieldSpec) {
        _controllers[field.name] = TextEditingController(
          text: (_values[field.name] as String?) ?? '',
        );
      } else if (field is NumberFieldSpec) {
        final value = _values[field.name];
        _controllers[field.name] = TextEditingController(
          text: value == null ? '' : '$value',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Есть ли несохранённые изменения — читает экран, чтобы спросить
  /// подтверждение перед уходом.
  bool get isDirty => _dirty;

  /// Разворачивание групп: раскладка знает про вложенность, а проверка
  /// и хранение значений — нет.
  static List<FieldSpec> _leafFields(List<FieldSpec> fields) => [
    for (final field in fields)
      if (field is SectionSpec) ..._leafFields(field.fields) else field,
  ];

  void _set(String name, Object? value) {
    setState(() {
      _values[name] = value;
      // Пользователь исправил значение — прежняя ошибка хранилища
      // к нему больше не относится.
      _storageErrors.remove(name);
      _reconcile();
    });
    _setDirty(true);
  }

  void _setDirty(bool value) {
    if (_dirty == value) return;
    _dirty = value;
    widget.onDirtyChanged?.call(value);
  }

  /// Согласование зависимых списков. После смены категории список
  /// исполнителей сужается, и прежний исполнитель может из него выпасть.
  /// Оставить его значением нельзя: выпадающий список бросает исключение
  /// на значении, которого нет среди items.
  void _reconcile() {
    for (final field in _leafFields(widget.fields)) {
      if (field is SelectFieldSpec) {
        final current = _values[field.name] as int?;
        if (current == null) continue;
        final allowed = field.options(_values).map((o) => o.value).toSet();
        if (!allowed.contains(current)) _values[field.name] = null;
      } else if (field is MultiSelectFieldSpec) {
        final current = (_values[field.name] as List<int>?) ?? const [];
        if (current.isEmpty) continue;
        final allowed = field.options(_values).map((o) => o.value).toSet();
        final kept = current.where(allowed.contains).toList();
        if (kept.length != current.length) _values[field.name] = kept;
      }
    }
  }

  /// Имена полей формы, включая вложенные: по ним видно, есть ли куда
  /// показать ошибку, пришедшую с сервера.
  Set<String> get _fieldNames =>
      _leafFields(widget.fields).map((f) => f.name).toSet();

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(message),
      ),
    );
  }

  Future<void> submit() async {
    // Снимаем фокус: иначе последнее поле остаётся с курсором, а на web
    // это мешает увидеть сообщение под ним.
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_values);
      // Запись сохранена — уходить со страницы можно без вопросов.
      if (mounted) _setDirty(false);
    } on ValidationException catch (e) {
      // Проверка сервера с кодом 422. Ключи совпадают с именами полей
      // формы, включая вложенные («account.login»), поэтому ошибки
      // раскладываются по полям без сопоставления вручную.
      if (!mounted) return;
      setState(() => _storageErrors.addAll(e.errors));
      // Повторная проверка нужна, чтобы ошибки появились под полями
      // сразу, а не после следующего нажатия.
      _formKey.currentState!.validate();
      // Ошибка, для которой поля на форме нет — например, нарушено
      // правило, связывающее два значения. Иначе она осталась бы
      // невидимой.
      final orphan = e.errors.keys
          .where((key) => !_fieldNames.contains(key))
          .toList();
      if (orphan.isNotEmpty) {
        _showFailure(e.errors[orphan.first]!);
      }
    } on UniqueConstraintException catch (e) {
      // То же самое от локального хранилища: имя поля в исключении.
      if (!mounted) return;
      setState(() => _storageErrors[e.field] = e.message);
      _formKey.currentState!.validate();
    } on ConflictException catch (e) {
      // Код 409: значения полей верны, но операция нарушила бы
      // целостность. Под конкретным полем такое не покажешь.
      if (!mounted) return;
      _showFailure(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFailure(e.message);
    } catch (e) {
      if (!mounted) return;
      _showFailure('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = screenSizeOf(context) == ScreenSize.compact;

    return Form(
      key: _formKey,
      // autovalidateMode задан каждому полю отдельно, а не форме целиком:
      // на форме этот режим проверяет разом все поля при изменении
      // любого из них, и правка одного поля подсветила бы ошибками всю
      // форму, включая ещё не заполненные поля.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _layout(context, widget.fields, compact),
                const SizedBox(height: 24),
                _actions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    List<FieldSpec> fields,
    bool compact, {
    double maxWidth = 860,
  }) {
    // Wrap вместо Row: половинное поле на узком окне занимает всю строку.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final field in fields)
              SizedBox(
                width: (compact || field.width == FieldWidth.full)
                    ? available
                    : (available - 16) / 2,
                child: _field(context, field, compact),
              ),
          ],
        );
      },
    );
  }

  Widget _field(BuildContext context, FieldSpec field, bool compact) {
    return switch (field) {
      TextFieldSpec() => _text(field),
      NumberFieldSpec() => _number(field),
      SelectFieldSpec() => _select(field),
      MultiSelectFieldSpec() => _multiSelect(field),
      EnumFieldSpec() => _enum(field),
      SwitchFieldSpec() => _switch(field),
      DateFieldSpec() => _date(field),
      SectionSpec() => _section(context, field, compact),
      NoteSpec() => _note(context, field),
    };
  }

  Widget _text(TextFieldSpec field) {
    return TextFormField(
      // Поле проверяется после того, как его тронули: исправленная
      // ошибка исчезает сразу, а не после следующего нажатия кнопки.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // controller и initialValue вместе задавать нельзя: TextFormField
      // бросает исключение при построении.
      controller: _controllers[field.name],
      autofocus: field.autofocus,
      maxLines: field.maxLines,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        hintText: field.hintText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: field.maxLines > 1,
      ),
      onChanged: (value) => _set(field.name, value),
      validator: (value) =>
          _storageErrors[field.name] ?? field.validator?.call(value),
    );
  }

  Widget _number(NumberFieldSpec field) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _controllers[field.name],
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        suffixText: field.suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _set(field.name, int.tryParse(value.trim())),
      validator: (value) =>
          _storageErrors[field.name] ?? field.validator?.call(value),
    );
  }

  Widget _select(SelectFieldSpec field) {
    final options = field.options(_values);
    final value = _values[field.name] as int?;

    return DropdownButtonFormField<int>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // initialValue, а не value: в текущей версии Flutter параметр
      // переименован, а didUpdateWidget подхватывает новое значение —
      // это и позволяет каскаду сбрасывать поле.
      initialValue: options.any((o) => o.value == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (field.emptyLabel != null)
          DropdownMenuItem(value: null, child: Text(field.emptyLabel!)),
        for (final option in options)
          DropdownMenuItem(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (next) => _set(field.name, next),
      validator: (next) =>
          _storageErrors[field.name] ?? field.validator?.call(next),
    );
  }

  /// Множественный выбор. Готового виджета в Material нет, поэтому
  /// собственное поле формы через FormField: оно участвует в общей
  /// проверке наравне с текстовыми полями.
  Widget _multiSelect(MultiSelectFieldSpec field) {
    final options = field.options(_values);
    final selected = (_values[field.name] as List<int>?) ?? const <int>[];

    return FormField<List<int>>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: selected,
      // Проверяется значение из _values, а не внутреннее значение поля:
      // согласование зависимых списков меняет первое напрямую.
      validator: (_) =>
          _storageErrors[field.name] ??
          field.validator?.call(_values[field.name] as List<int>?),
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.helper,
            border: const OutlineInputBorder(),
            // Ошибка показывается так же, как у обычного поля.
            errorText: state.errorText,
          ),
          child: options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Нет доступных значений',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      FilterChip(
                        label: Text(option.label),
                        tooltip: option.description,
                        selected: selected.contains(option.value),
                        onSelected: (_) {
                          final next = [...selected];
                          if (next.contains(option.value)) {
                            next.remove(option.value);
                          } else {
                            next.add(option.value);
                          }
                          // Без didChange форма не узнает о новом
                          // значении и проверка не сработает.
                          state.didChange(next);
                          _set(field.name, next);
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _enum(EnumFieldSpec field) {
    final value = _values[field.name] as Object?;

    return DropdownButtonFormField<Object>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in field.rawValues)
          DropdownMenuItem(value: option, child: Text(field.labelFor(option))),
      ],
      onChanged: (next) => _set(field.name, next),
      validator: (next) => next == null ? 'Выберите значение' : null,
    );
  }

  Widget _switch(SwitchFieldSpec field) {
    final value = (_values[field.name] as bool?) ?? false;

    return SwitchListTile(
      value: value,
      onChanged: (next) => _set(field.name, next),
      title: Text(field.label),
      subtitle: field.subtitle == null ? null : Text(field.subtitle!),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _date(DateFieldSpec field) {
    final value = _values[field.name] as DateTime?;

    return FormField<DateTime>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: value,
      validator: (_) => field.validator?.call(_values[field.name] as DateTime?),
      builder: (state) {
        return InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: field.firstDate ?? DateTime(2020),
              lastDate: field.lastDate ?? DateTime(2030),
              locale: const Locale('ru'),
            );
            if (picked == null) return;
            state.didChange(picked);
            _set(field.name, picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              helperText: field.helper,
              border: const OutlineInputBorder(),
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(value == null ? '— не задано —' : formatDate(value)),
          ),
        );
      },
    );
  }

  /// Группа полей связи один к одному. Визуально отделена рамкой:
  /// пользователю видно, что учётная запись — часть карточки заявителя,
  /// а не отдельная запись.
  Widget _section(BuildContext context, SectionSpec field, bool compact) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (field.icon != null) ...[
                  Icon(field.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(field.label, style: theme.textTheme.titleMedium),
              ],
            ),
            if (field.helper != null) ...[
              const SizedBox(height: 4),
              Text(
                field.helper!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _layout(context, field.fields, compact),
          ],
        ),
      ),
    );
  }

  Widget _note(BuildContext context, NoteSpec field) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          field.icon ?? Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            field.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: _submitting ? null : widget.onCancel,
            child: const Text('Отмена'),
          ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _submitting ? null : submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
