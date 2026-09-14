import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart' as v;
import '../state/auth_notifier.dart';

/// Вход в систему.
///
/// После успешного входа экран сам никуда не переходит: сессия сообщает
/// об изменении, маршрутизатор пересчитывает перенаправление и уводит
/// пользователя туда, откуда его отправили на вход.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  /// Учётные записи учебного сервера, по одной на роль.
  static const _demoAccounts = [
    (username: 'grigorev', password: 'grigorev123', role: 'заявитель'),
    (username: 'abramov', password: 'abramov123', role: 'специалист'),
    (username: 'admin', password: 'admin123', role: 'администратор'),
  ];

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().login(_username.text, _password.text);
    } on UnauthorizedException catch (e) {
      // Неверный пароль — не пустой экран и не падение, а сообщение
      // сервера над формой. Поле пароля очищается, логин остаётся.
      _password.clear();
      _error = e.message;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthNotifier>();
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final endReason = auth.endReason;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.support_agent, size: 44, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Служба технической поддержки',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Вход в систему',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (endReason != null &&
                    endReason != SessionEndReason.signedOut)
                  _Notice(
                    icon: Icons.timer_off_outlined,
                    text: endReason.message,
                    background: scheme.tertiaryContainer,
                    foreground: scheme.onTertiaryContainer,
                  ),
                if (from != null && endReason == null)
                  _Notice(
                    icon: Icons.lock_outline,
                    text: 'Чтобы открыть $from, войдите в систему.',
                    background: scheme.secondaryContainer,
                    foreground: scheme.onSecondaryContainer,
                  ),
                if (_error != null)
                  _Notice(
                    icon: Icons.error_outline,
                    text: _error!,
                    background: scheme.errorContainer,
                    foreground: scheme.onErrorContainer,
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _username,
                              autofocus: true,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Логин',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  v.notEmpty(value, 'Укажите логин'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                prefixIcon: const Icon(Icons.key_outlined),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Показать пароль'
                                      : 'Скрыть пароль',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) =>
                                  v.notEmpty(value, 'Укажите пароль'),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Войти'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(
                    Uri(
                      path: '/register',
                      queryParameters: from == null ? null : {'from': from},
                    ).toString(),
                  ),
                  child: const Text('Нет учётной записи? Зарегистрироваться'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Учебный стенд: учётные записи для проверки',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final account in _demoAccounts)
                      ActionChip(
                        label: Text('${account.username} · ${account.role}'),
                        onPressed: () => setState(() {
                          _username.text = account.username;
                          _password.text = account.password;
                          _error = null;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
