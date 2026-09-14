/// Настройки, зависящие от места запуска.
library;

/// Базовый адрес учебного API.
///
/// Константой его зашивать нельзя: на занятии сервер один, дома другой,
/// при публикации третий. Поэтому в коде нет даже значения по умолчанию —
/// адрес задаётся только при сборке, файлом или флагом:
///
///     flutter run -d chrome --web-port=5555 \
///       --dart-define-from-file=config/local.json
///     flutter build web --release \
///       --dart-define=API_BASE_URL=https://api.example.com/api
///
/// Пустая строка означает, что параметр забыли; main сообщает об этом
/// при запуске.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Время без действий, после которого сессия завершается. Задаётся при
/// сборке так же, как адрес сервера, чтобы проверить выход по
/// неактивности, не дожидаясь трёх минут:
///
///     flutter run -d chrome --web-port=5555 \
///       --dart-define=INACTIVITY_SECONDS=45
const Duration inactivityTimeout = Duration(
  seconds: int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 180),
);

/// За сколько до завершения сессии показывается предупреждение.
const Duration sessionWarningLead = Duration(
  seconds: int.fromEnvironment('SESSION_WARNING_SECONDS', defaultValue: 30),
);

/// Предельная длительность сессии: по её истечении пользователь выходит
/// независимо от активности и входит заново. Рабочая смена — восемь часов.
const Duration sessionMaxDuration = Duration(
  minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480),
);
