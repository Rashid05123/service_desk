/// Решение о переходе: пустить, отправить на вход или на экран отказа.
///
/// Вынесено из маршрутизатора в чистую функцию, чтобы проверяться
/// без запуска приложения.
library;

import '../models/app_user.dart';
import 'permissions.dart';

const _publicPaths = {'/login', '/register'};

/// Адрес, на который нужно перенаправить, или `null`, если переход
/// разрешён.
String? guardRoute({
  required bool loggedIn,
  required Role? role,
  required Uri uri,
}) {
  final isPublic = _publicPaths.contains(uri.path);

  if (!loggedIn) {
    if (isPublic) return null;
    // Адрес, куда человек шёл, запоминается: после входа он должен
    // попасть на присланную ему карточку, а не на главную.
    final target = uri.toString();
    return target == '/'
        ? '/login'
        : Uri(path: '/login', queryParameters: {'from': target}).toString();
  }

  if (isPublic) {
    return safeReturnPath(uri.queryParameters['from']) ?? '/';
  }

  if (!canOpen(role, uri.path)) {
    return Uri(
      path: '/forbidden',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  return null;
}

/// Адрес возврата после входа. Принимается только путь внутри
/// приложения: ссылка вида /login?from=https://чужой.сайт иначе увела бы
/// только что вошедшего пользователя на подставную страницу.
String? safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null || _publicPaths.contains(path)) return null;
  return from;
}
