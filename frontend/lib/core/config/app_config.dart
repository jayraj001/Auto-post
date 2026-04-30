import 'dart:io';

/// Central config — resolves API base URL at runtime.
/// Priority: --dart-define=API_BASE_URL → auto-detect → fallback
class AppConfig {
  AppConfig._();

  // ── API Base URL ──────────────────────────────────────────
  static const String _defined = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    // 1. Explicit override via --dart-define
    if (_defined.isNotEmpty) return _defined;

    // 2. Auto-detect: Android emulator uses 10.0.2.2 to reach host
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }

    // 3. iOS simulator uses localhost
    if (Platform.isIOS) {
      return 'http://localhost:5000/api';
    }

    // 4. Fallback
    return 'http://localhost:5000/api';
  }

  // ── Environment ───────────────────────────────────────────
  static const bool isProduction =
      String.fromEnvironment('ENV', defaultValue: 'dev') == 'prod';

  static bool get isDev => !isProduction;
}
