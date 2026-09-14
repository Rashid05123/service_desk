import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../state/auth_notifier.dart';

/// Сроки сессии: выход по неактивности с предупреждением и предельная
/// длительность сессии независимо от активности.
///
/// Стоит над всем приложением, в `MaterialApp.builder`, поэтому видит
/// любое действие на любом экране. Отметка последнего действия пишется
/// в хранилище: таймер живёт в памяти вкладки и при перезагрузке
/// обнуляется, и без отметки перезагрузка продлевала бы сессию.
class SessionGuard extends StatefulWidget {
  const SessionGuard({
    super.key,
    required this.child,
    this.inactivity = inactivityTimeout,
    this.warningLead = sessionWarningLead,
    this.maxDuration = sessionMaxDuration,
  });

  final Widget child;
  final Duration inactivity;
  final Duration warningLead;
  final Duration maxDuration;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  late final AuthNotifier _auth;

  Timer? _idleWarning;
  Timer? _idleEnd;
  Timer? _maxWarning;
  Timer? _maxEnd;

  /// Раз в секунду перерисовывает обратный отсчёт в предупреждении.
  Timer? _ticker;

  /// Какое предупреждение показано и когда сессия завершится.
  SessionEndReason? _warning;
  DateTime? _deadline;

  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthNotifier>();
    _auth.addListener(_sync);
    // Клавиатура слушается глобально. KeyboardListener здесь не подходит:
    // он сообщает о нажатиях, только когда его узел в фокусе, а у обёртки
    // над приложением фокуса нет — набор текста в форме не сбрасывал бы
    // таймер, и пользователя выбросило бы посреди заполнения.
    HardwareKeyboard.instance.addHandler(_onKey);
    _sync();
  }

  @override
  void dispose() {
    _auth.removeListener(_sync);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _cancelAll();
    super.dispose();
  }

  /// Вход запускает таймеры, выход останавливает.
  void _sync() {
    final authenticated = _auth.isAuthenticated;
    if (authenticated && !_watching) {
      _watching = true;
      _restartIdle();
      _scheduleMax();
    } else if (!authenticated && _watching) {
      _watching = false;
      _cancelAll();
      if (mounted) setState(_hideWarning);
    }
  }

  // false — событие не обработано и идёт дальше, к полям ввода.
  bool _onKey(KeyEvent event) {
    _onActivity();
    return false;
  }

  void _onActivity() {
    if (!_watching) return;
    _auth.recordActivity();
    _restartIdle();
    if (_warning == SessionEndReason.inactivity) setState(_hideWarning);
  }

  void _restartIdle() {
    _idleWarning?.cancel();
    _idleEnd?.cancel();
    final lead = widget.inactivity - widget.warningLead;
    _idleWarning = Timer(lead.isNegative ? Duration.zero : lead, () {
      _showWarning(SessionEndReason.inactivity, widget.warningLead);
    });
    _idleEnd = Timer(widget.inactivity, () {
      _end(SessionEndReason.inactivity);
    });
  }

  void _scheduleMax() {
    final started = _auth.sessionStartedAt ?? DateTime.now();
    final left = started.add(widget.maxDuration).difference(DateTime.now());
    final lead = left - widget.warningLead;
    _maxWarning = Timer(lead.isNegative ? Duration.zero : lead, () {
      _showWarning(
        SessionEndReason.maxDuration,
        left < widget.warningLead ? left : widget.warningLead,
      );
    });
    _maxEnd = Timer(left.isNegative ? Duration.zero : left, () {
      _end(SessionEndReason.maxDuration);
    });
  }

  void _showWarning(SessionEndReason reason, Duration left) {
    if (!mounted || !_watching) return;
    final deadline = DateTime.now().add(left);
    // Показывается то предупреждение, чей срок наступит раньше.
    if (_deadline != null && _deadline!.isBefore(deadline)) return;
    setState(() {
      _warning = reason;
      _deadline = deadline;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _hideWarning() {
    _warning = null;
    _deadline = null;
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _end(SessionEndReason reason) async {
    if (!_watching) return;
    _cancelAll();
    await _auth.logout(reason: reason);
  }

  void _cancelAll() {
    for (final timer in [_idleWarning, _idleEnd, _maxWarning, _maxEnd]) {
      timer?.cancel();
    }
    _ticker?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline;

    return Listener(
      // Перехват без поглощения: событие идёт дальше к виджетам.
      // С HitTestBehavior.opaque кнопки под обёрткой перестали бы нажиматься.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerMove: (_) => _onActivity(),
      onPointerHover: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
      child: Stack(
        children: [
          widget.child,
          if (_warning != null && deadline != null)
            Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: Center(
                child: _SessionWarning(
                  reason: _warning!,
                  secondsLeft:
                      (deadline.difference(DateTime.now()).inMilliseconds /
                              1000)
                          .ceil()
                          .clamp(0, 9999),
                  onContinue: _onActivity,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionWarning extends StatelessWidget {
  const _SessionWarning({
    required this.reason,
    required this.secondsLeft,
    required this.onContinue,
  });

  final SessionEndReason reason;
  final int secondsLeft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final idle = reason == SessionEndReason.inactivity;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        elevation: 6,
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      idle
                          ? 'Сессия завершится через $secondsLeft с'
                          : 'Истекает срок сессии: $secondsLeft с',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      idle
                          ? 'Давно не было действий. Чтобы продолжить работу, '
                                'пошевелите мышью или нажмите любую клавишу.'
                          : 'Предельная длительность сессии истекает. '
                                'Сохраните изменения: потребуется войти заново.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              if (idle) ...[
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onContinue,
                  child: const Text('Продолжить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
