import 'dart:io';

/// Central config — resolves API base URL at runtime.
/// Priority: --dart-define=API_BASE_URL → auto-detect → fallback
class AppConfig {
  AppConfig._();

  // ── API Base URL ──────────────────────────────────────────
  static const String _defined = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_defined.isNotEmpty) return _defined;
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    if (Platform.isIOS)     return 'http://localhost:5000/api';
    return 'http://localhost:5000/api';
  }

  // ── OAuth deep link scheme ────────────────────────────────
  // Backend redirects to: autopostai://oauth-result?success=true&platform=facebook
  static const String oauthScheme    = 'autopostai';
  static const String oauthHost      = 'oauth-result';
  static String get oauthRedirectUri =>
      '$oauthScheme://$oauthHost';

  // ── Environment ───────────────────────────────────────────
  static const bool isProduction =
      String.fromEnvironment('ENV', defaultValue: 'dev') == 'prod';

  static bool get isDev => !isProduction;
}
