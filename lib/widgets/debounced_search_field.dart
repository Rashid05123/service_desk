import 'dart:async';

import 'package:flutter/material.dart';

/// Поле поиска с задержкой: запрос уходит через [delay] после последнего
/// нажатия. Значение приходит из адреса страницы, поэтому виджет следит
/// за его изменением снаружи.
class DebouncedSearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Duration delay;

  const DebouncedSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Поиск',
    this.delay = const Duration(milliseconds: 350),
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _timer;
  late bool _isEmpty = _controller.text.isEmpty;

  @override
  void initState() {
    super.initState();
    // Кнопка очистки появляется вместе с текстом. Локальное состояние
    // виджета, в notifier ему делать нечего.
    _controller.addListener(() {
      final isEmpty = _controller.text.isEmpty;
      if (isEmpty != _isEmpty) setState(() => _isEmpty = isEmpty);
    });
  }

  @override
  void didUpdateWidget(covariant DebouncedSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Значение изменилось снаружи: история браузера или сброс фильтров.
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted) widget.onChanged(text);
    });
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      // Enter применяет введённое немедленно, не дожидаясь задержки.
      onSubmitted: (text) {
        _timer?.cancel();
        widget.onChanged(text);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: _isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить',
                icon: const Icon(Icons.close),
                onPressed: _clear,
              ),
      ),
    );
  }
}
