import 'package:flutter/material.dart';

/// Поля панелей фильтров. Вынесены отдельно, потому что панель отбора
/// есть у каждой из пяти сущностей и отличается только набором полей.

/// Выпадающий список фильтра с обязательным пустым значением «любой».
///
/// Обычный DropdownButton, а не DropdownButtonFormField: значение
/// приходит из адреса страницы и может измениться в любой момент,
/// в том числе кнопкой «назад» в браузере.
class FilterDropdown<V> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 220,
    this.emptyLabel = '— любой —',
  });

  final String label;
  final V? value;
  final List<DropdownMenuItem<V>> items;
  final ValueChanged<V?> onChanged;
  final double width;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    // Значения, которого нет среди вариантов, быть не должно: выпадающий
    // список бросает на нём исключение. Такое приходит из адреса,
    // набранного руками.
    final known = items.any((item) => item.value == value) ? value : null;

    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<V>(
            value: known,
            isExpanded: true,
            isDense: true,
            items: [
              DropdownMenuItem<V>(value: null, child: Text(emptyLabel)),
              ...items,
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Поле выбора даты с кнопкой очистки.
class FilterDateField extends StatelessWidget {
  const FilterDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 190,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime(2026, 8, 15),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            locale: const Locale('ru'),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    tooltip: 'Очистить',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(
            value == null
                ? '— не задано —'
                : '${value!.day.toString().padLeft(2, '0')}.'
                      '${value!.month.toString().padLeft(2, '0')}.'
                      '${value!.year}',
          ),
        ),
      ),
    );
  }
}

/// Ряд полей фильтра. Wrap, а не Row: на узком окне поля переносятся.
class FilterRow extends StatelessWidget {
  const FilterRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}
