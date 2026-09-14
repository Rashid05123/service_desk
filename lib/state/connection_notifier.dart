import 'dart:async';

import 'package:flutter/foundation.dart';

/// Связь с сервером: есть она или нет, и когда вернулась.
///
/// Об отказе сообщает сетевой слой — интерсептор видит каждый запрос
/// и отличает «сервер не ответил» от «сервер ответил ошибкой». Пока связи
/// нет, сервер опрашивается с паузой [probeInterval]; первый же ответ
/// возвращает состояние «на связи», и экраны, которые показали ошибку,
/// перечитывают данные сами, без перезагрузки страницы.
class ConnectionNotifier extends ChangeNotifier {
  ConnectionNotifier({
    required this.probe,
    this.probeInterval = const Duration(seconds: 5),
  });

  /// Проверка сервера: true — ответил.
  final Future<bool> Function() probe;

  final Duration probeInterval;

  bool _online = true;
  bool _probing = false;
  bool _disposed = false;
  Timer? _timer;

  bool get isOnline => _online;

  /// Запрос не дошёл до сервера: нет сети, таймаут, сервер выключен.
  void reportFailure() {
    if (!_online) return;
    _online = false;
    _timer?.cancel();
    _timer = Timer.periodic(probeInterval, (_) => checkNow());
    _notify();
  }

  /// Сервер ответил — всё равно чем, хоть кодом 404.
  void reportSuccess() {
    if (_online) return;
    _online = true;
    _timer?.cancel();
    _timer = null;
    _notify();
  }

  /// Внеочередная проверка: по кнопке и по таймеру.
  Future<void> checkNow() async {
    if (_online || _probing) return;
    _probing = true;
    try {
      if (await probe()) reportSuccess();
    } finally {
      _probing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
