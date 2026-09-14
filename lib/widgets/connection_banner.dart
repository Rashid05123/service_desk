import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/connection_notifier.dart';

/// Полоса над всем приложением, пока нет связи с сервером.
///
/// Стоит над навигатором, а не в каркасе раздела: сервер может пропасть
/// и на экране входа, и человек должен понимать, что «неверный пароль»
/// тут ни при чём.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  ConnectionNotifier? _connection;
  bool _wasOnline = true;

  /// Короткое сообщение «связь восстановлена»: исчезнувшая молча полоса
  /// оставляет вопрос, починилось ли что-нибудь.
  bool _restored = false;
  Timer? _restoredTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Provider.of<ConnectionNotifier?>(context, listen: false);
    if (identical(next, _connection)) return;
    _connection?.removeListener(_changed);
    _connection = next;
    _wasOnline = next?.isOnline ?? true;
    next?.addListener(_changed);
  }

  void _changed() {
    final online = _connection!.isOnline;
    if (online && !_wasOnline) {
      _restoredTimer?.cancel();
      _restored = true;
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _restored = false);
      });
    }
    if (!online) _restored = false;
    _wasOnline = online;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connection?.removeListener(_changed);
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    final offline = connection != null && !connection.isOnline;

    return Column(
      children: [
        if (offline)
          _Strip(
            icon: Icons.cloud_off_outlined,
            text:
                'Нет связи с сервером. Данные не загружаются и не сохраняются; '
                'проверка соединения каждые ${connection.probeInterval.inSeconds} с.',
            action: TextButton(
              onPressed: connection.checkNow,
              child: const Text('Проверить сейчас'),
            ),
            error: true,
          )
        else if (_restored)
          const _Strip(
            icon: Icons.cloud_done_outlined,
            text: 'Связь с сервером восстановлена, данные обновлены.',
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.text,
    this.action,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final Widget? action;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = error ? scheme.errorContainer : scheme.primaryContainer;
    final foreground = error
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    // liveRegion: экранный чтец объявит пропажу связи сам, без перехода
    // фокуса на полосу.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: background,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: foreground),
                  ),
                ),
                ?action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Вызов [onReconnect], когда связь с сервером вернулась.
///
/// Экран, показавший ошибку из-за пропавшей связи, оборачивается в этот
/// виджет и перечитывает данные сам: человек не обязан догадываться,
/// что после восстановления сети нужно нажать «Повторить».
class ReloadOnReconnect extends StatefulWidget {
  const ReloadOnReconnect({
    super.key,
    required this.onReconnect,
    required this.child,
  });

  final VoidCallback onReconnect;
  final Widget child;

  @override
  State<ReloadOnReconnect> createState() => _ReloadOnReconnectState();
}

class _ReloadOnReconnectState extends State<ReloadOnReconnect> {
  ConnectionNotifier? _connection;
  bool _wasOnline = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Необязательная зависимость: в проверках отдельных виджетов
    // состояния связи может не быть вовсе.
    final next = Provider.of<ConnectionNotifier?>(context, listen: false);
    if (identical(next, _connection)) return;
    _connection?.removeListener(_changed);
    _connection = next;
    _wasOnline = next?.isOnline ?? true;
    next?.addListener(_changed);
  }

  void _changed() {
    final online = _connection!.isOnline;
    if (online && !_wasOnline && mounted) widget.onReconnect();
    _wasOnline = online;
  }

  @override
  void dispose() {
    _connection?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
