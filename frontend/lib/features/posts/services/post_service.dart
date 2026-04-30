import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────
final postServiceProvider = Provider<PostService>((ref) => PostService());

// ── Post Model ────────────────────────────────────────────────
class PostModel {
  final String id;
  final String caption;
  final List<String> mediaUrls;
  final List<String> platforms;
  final DateTime? scheduledAt;
  final String status;

  const PostModel({
    required this.id,
    required this.caption,
    required this.mediaUrls,
    required this.platforms,
    this.scheduledAt,
    required this.status,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
        id: json['id'] ?? '',
        caption: json['caption'] ?? '',
        mediaUrls: List<String>.from(json['media_urls'] ?? []),
        platforms: List<String>.from(json['platforms'] ?? []),
        scheduledAt: json['scheduled_at'] != null
            ? DateTime.tryParse(json['scheduled_at'])
            : null,
        status: json['status'] ?? 'draft',
      );
}

// ── PostService ───────────────────────────────────────────────
class PostService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  PostService() {
    // ── Logging interceptor — prints request + response.body ──
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('── API REQUEST ──────────────────────────');
        debugPrint('${options.method} ${options.uri}');
        debugPrint('Headers: ${options.headers}');
        debugPrint('Body: ${options.data}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Equivalent to: print(response.body)
        debugPrint('── API RESPONSE ─────────────────────────');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Body: ${response.data}');
        handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint('── API ERROR ────────────────────────────');
        debugPrint('Status: ${e.response?.statusCode}');
        debugPrint('Body: ${e.response?.data}');
        debugPrint('Message: ${e.message}');
        handler.next(e);
      },
    ));
  }

  // ── Get Firebase ID token for auth header ──────────────────
  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // ── savePost ───────────────────────────────────────────────
  // Main function: savePost(caption, mediaUrl, platform, scheduledTime)
  Future<PostModel> savePost({
    required String caption,
    required String mediaUrl,       // single URL (or empty string)
    required String platform,       // single platform id
    required DateTime? scheduledTime,
    List<String>? mediaUrls,        // optional: multiple URLs
    List<String>? platforms,        // optional: multiple platforms
    String mediaType = 'image',
    List<String> hashtags = const [],
    bool aiGenerated = false,
  }) async {
    final token = await _getToken();

    final response = await _dio.post(
      '/posts',
      data: {
        'caption': caption,
        'media_urls': mediaUrls ?? (mediaUrl.isNotEmpty ? [mediaUrl] : []),
        'media_type': mediaType,
        'platforms': platforms ?? [platform],
        'hashtags': hashtags,
        'scheduled_at': scheduledTime?.toIso8601String(),
        'ai_generated': aiGenerated,
      },
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );

    return PostModel.fromJson(response.data);
  }

  // ── Publish immediately ────────────────────────────────────
  Future<void> publishNow(String postId) async {
    final token = await _getToken();
    await _dio.post(
      '/posts/$postId/publish',
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
  }

  // ── Fetch posts list ───────────────────────────────────────
  Future<List<PostModel>> fetchPosts({String? status}) async {
    final token = await _getToken();
    final response = await _dio.get(
      '/posts',
      queryParameters: status != null ? {'status': status} : {},
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
    final list = response.data['posts'] as List;
    return list.map((e) => PostModel.fromJson(e)).toList();
  }

  // ── Delete post ────────────────────────────────────────────
  Future<void> deletePost(String postId) async {
    final token = await _getToken();
    await _dio.delete(
      '/posts/$postId',
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
  }
}
