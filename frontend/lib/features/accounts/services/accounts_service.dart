import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../models/social_account.dart';

final accountsServiceProvider =
    Provider<AccountsService>((ref) => AccountsService());

final accountsProvider = FutureProvider<List<SocialAccount>>((ref) async {
  return ref.read(accountsServiceProvider).fetchAccounts();
});

class AccountsService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<String?> _token() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken();

  Future<Options> _opts() async {
    final t = await _token();
    return Options(headers: {if (t != null) 'Authorization': 'Bearer $t'});
  }

  // ── GET /accounts ─────────────────────────────────────────
  Future<List<SocialAccount>> fetchAccounts() async {
    try {
      final response = await _dio.get('/accounts', options: await _opts());
      final list = response.data as List;
      debugPrint('Accounts fetched: ${list.length}');
      return list.map((e) => SocialAccount.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchAccounts error: $e');
      return [];
    }
  }

  // ── POST /connect-account ─────────────────────────────────
  // Called after OAuth callback with the received token
  Future<SocialAccount?> connectAccount({
    required String platform,
    required String accessToken,
    required String platformUserId,
    required String username,
    required String displayName,
    String? avatarUrl,
    String? refreshToken,
    String? pageId,
  }) async {
    try {
      final response = await _dio.post(
        '/accounts/connect/$platform',
        data: {
          'access_token': accessToken,
          'platform_user_id': platformUserId,
          'username': username,
          'display_name': displayName,
          'avatar_url': avatarUrl,
          if (refreshToken != null) 'refresh_token': refreshToken,
          if (pageId != null) 'page_id': pageId,
        },
        options: await _opts(),
      );
      debugPrint('Account connected: ${response.data}');
      return SocialAccount.fromJson(response.data);
    } catch (e) {
      debugPrint('connectAccount error: $e');
      return null;
    }
  }

  // ── DELETE /accounts/:id ──────────────────────────────────
  Future<bool> disconnectAccount(String accountId) async {
    try {
      await _dio.delete('/accounts/$accountId', options: await _opts());
      debugPrint('Account disconnected: $accountId');
      return true;
    } catch (e) {
      debugPrint('disconnectAccount error: $e');
      return false;
    }
  }

  // ── Build OAuth URL ───────────────────────────────────────
  // Returns the URL to open in a WebView / browser for OAuth
  String buildOAuthUrl(SocialPlatform platform) {
    return '$_baseUrl${platform.oauthPath}';
  }
}
