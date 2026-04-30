import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────
final firestorePostServiceProvider =
    Provider<FirestorePostService>((ref) => FirestorePostService());

// ── FirestorePostService ──────────────────────────────────────
class FirestorePostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ── Collection ref ─────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  // ── Save post ──────────────────────────────────────────────
  // FirebaseFirestore.instance.collection('posts').add({...})
  Future<DocumentReference> savePost({
    required String caption,
    required String mediaUrl,
    required String platform,
    required DateTime? scheduledTime,
    List<String>? mediaUrls,
    List<String>? platforms,
    String mediaType = 'image',
    List<String> hashtags = const [],
    bool aiGenerated = false,
  }) async {
    final data = {
      'uid': _uid,
      'caption': caption,
      'media_url': mediaUrl,
      'media_urls': mediaUrls ?? (mediaUrl.isNotEmpty ? [mediaUrl] : []),
      'media_type': mediaType,
      'platform': platform,
      'platforms': platforms ?? [platform],
      'hashtags': hashtags,
      'scheduled_at': scheduledTime != null
          ? Timestamp.fromDate(scheduledTime)
          : null,
      'status': scheduledTime != null ? 'scheduled' : 'published',
      'ai_generated': aiGenerated,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Exactly as requested:
    // FirebaseFirestore.instance.collection('posts').add({...})
    final ref = await _posts.add(data);

    debugPrint('── FIRESTORE SAVE ───────────────────────');
    debugPrint('Post saved: ${ref.id}');
    debugPrint('Data: $data');

    return ref;
  }

  // ── Fetch user's posts ─────────────────────────────────────
  Stream<QuerySnapshot> streamPosts() {
    return _posts
        .where('uid', isEqualTo: _uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // ── Fetch scheduled posts ──────────────────────────────────
  Stream<QuerySnapshot> streamScheduledPosts() {
    return _posts
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('scheduled_at')
        .snapshots();
  }

  // ── Update post ────────────────────────────────────────────
  Future<void> updatePost(String docId, Map<String, dynamic> fields) async {
    await _posts.doc(docId).update({
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    });
    debugPrint('Post updated: $docId');
  }

  // ── Delete post ────────────────────────────────────────────
  Future<void> deletePost(String docId) async {
    await _posts.doc(docId).delete();
    debugPrint('Post deleted: $docId');
  }

  // ── Get single post ────────────────────────────────────────
  Future<DocumentSnapshot> getPost(String docId) async {
    return await _posts.doc(docId).get();
  }
}
