import 'package:flutter/material.dart';

/// Значения формы: имя поля — значение. Ключ вложенного поля записывается
/// через точку («account.login»), так же он приходит в ошибке
/// уникальности из репозитория.
typedef FormValues = Map<String, dynamic>;

/// Ширина поля в раскладке формы. На узком окне обе превращаются
/// в полную ширину.
enum FieldWidth { full, half }

/// Описание поля формы. Экран собирает список таких описаний, а рисует
/// и проверяет их общий виджет EntityForm — за счёт этого форма заявки
/// и форма отдела устроены одинаково.
sealed class FieldSpec {
  const FieldSpec({
    required this.name,
    required this.label,
    this.helper,
    this.width = FieldWidth.full,
  });

  /// Ключ значения в [FormValues] и одновременно имя поля в ошибке
  /// уникальности.
  final String name;

  final String label;

  /// Пояснение под полем: требования к значению, единицы измерения.
  final String? helper;

  final FieldWidth width;
}

/// Строка: тема заявки, название отдела, примечание.
class TextFieldSpec extends FieldSpec {
  const TextFieldSpec({
    required super.name,
    required super.label,
    super.helper,
    super.width,
    this.validator,
    this.maxLines = 1,
    this.hintText,
    this.autofocus = false,
  });

  final String? Function(String? value)? validator;
  final int maxLines;
  final String? hintText;
  final bool autofocus;
}

/// Целое число. Значение хранится числом, а не строкой: разбор делает
/// сама форма, экранам не приходится повторять int.tryParse.
class NumberFieldSpec extends FieldSpec {
  const NumberFieldSpec({
    required super.name,
    required super.label,
    super.helper,
    super.width,
    this.validator,
    this.suffix,
  });

  final String? Function(String? value)? validator;

  /// Единица измерения справа в поле: «ч», «шт».
  final String? suffix;
}

/// Вариант выбора для списка и для набора меток.
typedef SelectOption = ({int value, String label, String? description});

/// Связь многие к одному — выпадающий список. Значение хранится
/// идентификатором, а не объектом: сравнение объектов идёт по ==,
/// и без переопределения ==/hashCode выбранное значение перестало бы
/// совпадать с элементом списка.
class SelectFieldSpec extends FieldSpec {
  const SelectFieldSpec({
    required super.name,
    required super.label,
    required this.options,
    super.helper,
    super.width,
    this.validator,
    this.emptyLabel,
  });

  /// Варианты зависят от остальных полей: список исполнителей сужается
  /// после выбора категории. Отсюда и параметр — текущие значения формы.
  final List<SelectOption> Function(FormValues values) options;

  final String? Function(int? value)? validator;

  /// Подпись пустого значения. Если null, поле обязательное и пустого
  /// варианта в списке нет.
  final String? emptyLabel;
}

/// Связь многие ко многим — множественный выбор набором меток.
/// Значение — список идентификаторов.
class MultiSelectFieldSpec extends FieldSpec {
  const MultiSelectFieldSpec({
    required super.name,
    required super.label,
    required this.options,
    super.helper,
    super.width,
    this.validator,
    this.emptyHint = 'Ничего не выбрано',
  });

  final List<SelectOption> Function(FormValues values) options;

  final String? Function(List<int>? value)? validator;

  final String emptyHint;
}

/// Перечисление: приоритет, статус. Значения известны заранее, поэтому
/// список вариантов не зависит от других полей.
class EnumFieldSpec<E extends Object> extends FieldSpec {
  const EnumFieldSpec({
    required super.name,
    required super.label,
    required this.values,
    required this.labelOf,
    super.helper,
    super.width,
  });

  final List<E> values;
  final String Function(E value) labelOf;

  /// Разметка формы разбирает описания полей без параметра типа, поэтому
  /// значения и подписи выдаются наружу как Object: приведение обратно
  /// к E выполняется здесь, где тип известен.
  List<Object> get rawValues => List<Object>.from(values);

  String labelFor(Object value) => labelOf(value as E);
}

/// Флажок-переключатель: «работает», «учётная запись заблокирована».
class SwitchFieldSpec extends FieldSpec {
  const SwitchFieldSpec({
    required super.name,
    required super.label,
    super.helper,
    super.width,
    this.subtitle,
  });

  final String? subtitle;
}

/// Дата: срок решения по SLA.
class DateFieldSpec extends FieldSpec {
  const DateFieldSpec({
    required super.name,
    required super.label,
    super.helper,
    super.width,
    this.validator,
    this.firstDate,
    this.lastDate,
  });

  final String? Function(DateTime? value)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
}

/// Группа полей с заголовком. Так показывается связь один к одному:
/// учётная запись редактируется внутри формы заявителя, отдельного
/// экрана у неё нет.
class SectionSpec extends FieldSpec {
  const SectionSpec({
    required super.name,
    required super.label,
    required this.fields,
    super.helper,
    this.icon,
  });

  final List<FieldSpec> fields;
  final IconData? icon;
}

/// Пояснение между полями — не поле, но часть раскладки.
class NoteSpec extends FieldSpec {
  const NoteSpec({required super.name, required super.label, this.icon});

  final IconData? icon;
}
