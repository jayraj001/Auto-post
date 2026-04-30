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
  late final Dio _dio;

  AccountsService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        debugPrint('── ACCOUNTS API ─────────────────────────');
        debugPrint('${response.requestOptions.method} '
            '${response.requestOptions.path} → ${response.statusCode}');
        handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint('── ACCOUNTS ERROR ───────────────────────');
        debugPrint('${e.response?.statusCode}: ${e.response?.data}');
        handler.next(e);
      },
    ));
  }

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
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        debugPrint('fetchAccounts: unauthorized — user not logged in');
      } else {
        debugPrint('fetchAccounts error [$status]: ${e.response?.data}');
      }
      return [];
    } catch (e) {
      debugPrint('fetchAccounts unexpected error: $e');
      return [];
    }
  }

  // ── DELETE /accounts/:id ──────────────────────────────────
  Future<bool> disconnectAccount(String accountId) async {
    try {
      await _dio.delete('/accounts/$accountId', options: await _opts());
      debugPrint('Account disconnected: $accountId');
      return true;
    } on DioException catch (e) {
      debugPrint('disconnectAccount error: ${e.response?.data}');
      return false;
    }
  }

  // ── POST /oauth/refresh/:platform/:accountId ──────────────
  Future<bool> refreshToken(String platform, String accountId) async {
    try {
      await _dio.post(
        '/oauth/refresh/$platform/$accountId',
        options: await _opts(),
      );
      debugPrint('Token refreshed: $platform / $accountId');
      return true;
    } on DioException catch (e) {
      debugPrint('refreshToken error: ${e.response?.data}');
      return false;
    }
  }
}
