import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/validators.dart' as v;
import '../state/auth_notifier.dart';

/// Регистрация заявителя.
///
/// Роль не выбирается: новая учётная запись всегда получает роль
/// заявителя, и назначает её сервер. Поле роли в форме было бы не
/// удобством, а приглашением отправить запрос с ролью администратора.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  /// Ошибки полей от сервера (код 422). Ключи совпадают с именами полей.
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Проверка поля: сначала ответ сервера, затем собственные требования.
  String? Function(String?) _check(
    String field,
    String? Function(String?) local,
  ) {
    return (value) => _serverErrors[field] ?? local(value);
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _serverErrors = const {});
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
        username: _username.text,
        password: _password.text,
        fullName: _fullName.text,
        email: _email.text,
      );
    } on ValidationException catch (e) {
      _serverErrors = e.errors;
      _error = 'Сервер не принял данные: исправьте отмеченные поля.';
      _formKey.currentState?.validate();
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
    final from = GoRouterState.of(context).uri.queryParameters['from'];

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Регистрация',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Учётная запись заявителя: подача обращений и контроль '
                  'их решения',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _fullName,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => _clearServerError('fullName'),
                            decoration: const InputDecoration(
                              labelText: 'ФИО',
                              helperText: 'Например, Петров Пётр Ильич',
                            ),
                            validator: _check(
                              'fullName',
                              v.all([
                                (value) => v.notEmpty(value, 'Укажите ФИО'),
                                v.fullName,
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _username,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => _clearServerError('username'),
                            decoration: const InputDecoration(
                              labelText: 'Логин',
                              helperText: 'Доменный логин: латиница, например petrov.pi',
                            ),
                            validator: _check(
                              'username',
                              v.all([
                                (value) => v.notEmpty(value, 'Укажите логин'),
                                v.login,
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => _clearServerError('email'),
                            decoration: const InputDecoration(
                              labelText: 'Рабочая почта',
                            ),
                            validator: _check(
                              'email',
                              v.all([
                                (value) =>
                                    v.notEmpty(value, 'Укажите адрес почты'),
                                v.email,
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            // Проверка по мере ввода: и сообщение под полем,
                            // и список требований ниже обновляются
                            // на каждый символ.
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) {
                              _clearServerError('password');
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: 'Пароль',
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
                            validator: _check(
                              'password',
                              v.all([
                                (value) =>
                                    v.notEmpty(value, 'Придумайте пароль'),
                                v.strongPassword,
                              ]),
                            ),
                          ),
                          const SizedBox(height: 8),
                          PasswordRulesChecklist(password: _password.text),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Повтор пароля',
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Повторите пароль';
                              }
                              return value == _password.text
                                  ? null
                                  : 'Пароли не совпадают';
                            },
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
                                : const Text('Зарегистрироваться'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(
                    Uri(
                      path: '/login',
                      queryParameters: from == null ? null : {'from': from},
                    ).toString(),
                  ),
                  child: const Text('Уже есть учётная запись? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Требования к паролю списком с отметками выполненных.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in v.passwordRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  rule.test(password)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: rule.test(password) ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: rule.test(password)
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
