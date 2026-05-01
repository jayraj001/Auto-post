import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../models/social_account.dart';

// ── OAuth result model ────────────────────────────────────────
class OAuthResult {
  final bool success;
  final String? platform;
  final String? username;
  final String? error;

  const OAuthResult({
    required this.success,
    this.platform,
    this.username,
    this.error,
  });
}

// ── Provider ──────────────────────────────────────────────────
final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());

// ── OAuthService ──────────────────────────────────────────────
class OAuthService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  Completer<OAuthResult>? _pendingCompleter;

  /// Launch OAuth for a platform and wait for the deep link callback.
  /// Returns [OAuthResult] with success/error info.
  Future<OAuthResult> connect(SocialPlatform platform) async {
    // Get Firebase UID to pass as state (backend links account to user)
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Exactly: final url = '${AppConfig.apiBaseUrl}/oauth/$platform';
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/oauth/${platform.id}'
      '?state=${Uri.encodeComponent(uid)}'
      '&redirect_uri=${Uri.encodeComponent(AppConfig.oauthRedirectUri)}',
    );

    debugPrint('── OAuth LAUNCH ─────────────────────────');
    debugPrint('Platform: ${platform.label}');
    debugPrint('URL: $url');

    if (!await canLaunchUrl(url)) {
      return const OAuthResult(
        success: false,
        error: 'Could not open browser. Please check your device settings.',
      );
    }

    final completer = Completer<OAuthResult>();
    _pendingCompleter = completer;

    _linkSub?.cancel();
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) {
        debugPrint('Deep link error: $e');
        if (!completer.isCompleted) {
          completer.complete(OAuthResult(
            success: false,
            error: 'Deep link error: $e',
          ));
        }
      },
    );

    // Launch browser — exactly as requested:
    // await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _cleanup();
      return OAuthResult(
        success: false,
        error: 'Failed to open browser: $e',
      );
    }

    // Wait for callback (timeout after 5 minutes)
    try {
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _cleanup();
          return const OAuthResult(
            success: false,
            error: 'OAuth timed out. Please try again.',
          );
        },
      );
    } finally {
      _cleanup();
    }
  }

  /// Handle incoming deep link: autopostai://oauth-result?success=true&platform=facebook
  void _handleDeepLink(Uri uri) {
    debugPrint('── Deep Link Received ───────────────────');
    debugPrint('URI: $uri');

    if (uri.scheme != AppConfig.oauthScheme ||
        uri.host != AppConfig.oauthHost) {
      return;
    }

    final completer = _pendingCompleter;
    if (completer == null || completer.isCompleted) return;

    final success  = uri.queryParameters['success'] == 'true';
    final platform = uri.queryParameters['platform'];
    final username = uri.queryParameters['username'];
    final error    = uri.queryParameters['error'];

    if (success) {
      debugPrint('OAuth success: $platform (@$username)');
      completer.complete(OAuthResult(
        success: true,
        platform: platform,
        username: username,
      ));
    } else {
      final msg = error != null
          ? Uri.decodeComponent(error)
          : 'Connection failed. Please try again.';
      debugPrint('OAuth failed: $msg');
      completer.complete(OAuthResult(success: false, error: msg));
    }
  }

  void _cleanup() {
    _linkSub?.cancel();
    _linkSub = null;
    _pendingCompleter = null;
  }

  void dispose() => _cleanup();
}
