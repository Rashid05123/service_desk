/// Настройки, зависящие от места запуска.
library;

/// Базовый адрес учебного API.
///
/// Константой его зашивать нельзя: на занятии сервер один, дома другой,
/// при публикации третий. Значение задаётся при сборке и по умолчанию
/// указывает на сервер, запущенный на той же машине:
///
///     flutter run -d chrome --web-port=5555 \
///       --dart-define=API_BASE_URL=http://192.168.1.10:8080/api
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);
