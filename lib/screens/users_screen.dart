import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../models/app_user.dart';
import '../repositories/workspace_api.dart';
import '../state/auth_notifier.dart';
import '../widgets/async_view.dart';

/// Пользователи и роли. Экран только администратора.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _view = GlobalKey<AsyncViewState<List<AppUser>>>();

  Future<void> _changeRole(AppUser user, Role role) async {
    if (role == user.role) return;
    final api = context.read<WorkspaceApi>();
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await api.changeRole(user.id, role);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${user.fullName}: роль изменена на «${role.label}»'),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: errorColor, content: Text(e.message)),
      );
    }
    _view.currentState?.reload();
  }

  /// Строка пользователя. На телефоне список роли стоит под подзаголовком:
  /// в trailing он забирал почти всю ширину строки 360, и ФИО выстраивалось
  /// в столбик по одной букве.
  Widget _userTile(AppUser user, AppUser? me, {required bool compact}) {
    final details = Text(
      [
        user.username,
        user.email,
        if (user.employeeId != null) 'сотрудник поддержки №${user.employeeId}',
        if (user.requesterId != null) 'карточка заявителя №${user.requesterId}',
      ].join(' · '),
    );
    final roleSelector = DropdownButton<Role>(
      value: user.role,
      // Собственную роль администратор не меняет: сервер это тоже запрещает.
      onChanged: user.id == me?.id
          ? null
          : (role) {
              if (role != null) _changeRole(user, role);
            },
      items: [
        for (final role in Role.values)
          DropdownMenuItem(value: role, child: Text(role.label)),
      ],
    );

    return ListTile(
      leading: CircleAvatar(
        child: Text(user.fullName.isEmpty ? '?' : user.fullName[0]),
      ),
      title: Text(user.fullName),
      subtitle: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, roleSelector],
            )
          : details,
      trailing: compact ? null : roleSelector,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.watch<AuthNotifier>().user;
    final compact = screenSizeOf(context) == ScreenSize.compact;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи и роли'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => _view.currentState?.reload(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView<List<AppUser>>(
        key: _view,
        load: () => context.read<WorkspaceApi>().users(),
        builder: (context, users) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Роль определяет, какие операции разрешит сервер. Изменение '
              'действует с ближайшего запроса пользователя: сервер берёт роль '
              'из своей записи, а не из сохранённой в браузере.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final user in users)
                    _userTile(user, me, compact: compact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
