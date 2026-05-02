import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Global error handler provider ────────────────────────────
final errorHandlerProvider = Provider<ErrorHandler>((ref) => ErrorHandler());

class ErrorHandler {
  /// Convert any error into a user-friendly message
  static String message(Object error) {
    // Firebase Auth errors
    if (error is FirebaseAuthException) {
      return _firebaseMessage(error);
    }

    // Dio / API errors
    if (error is DioException) {
      return _dioMessage(error);
    }

    // Generic
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('network')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':       return 'Incorrect password. Please try again.';
      case 'invalid-credential':   return 'Invalid email or password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password':        return 'Password too weak. Use at least 8 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      case 'user-disabled':        return 'This account has been disabled.';
      case 'too-many-requests':    return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'Network error. Check your connection.';
      default: return e.message ?? 'Authentication error. Please try again.';
    }
  }

  static String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    final body   = e.response?.data;

    // Use server error message if available
    if (body is Map && body['error'] != null) {
      return body['error'].toString();
    }

    switch (status) {
      case 400: return 'Invalid request. Please check your input.';
      case 401: return 'Session expired. Please sign in again.';
      case 403: return 'You don\'t have permission to do this.';
      case 404: return 'Resource not found.';
      case 409: return 'This already exists.';
      case 429: return 'Too many requests. Please wait a moment.';
      case 500: return 'Server error. Please try again later.';
      case 503: return 'Service unavailable. Please try again later.';
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return 'Connection timed out. Please try again.';
        }
        if (e.type == DioExceptionType.connectionError) {
          return 'Cannot connect to server. Check your internet.';
        }
        return 'Network error. Please try again.';
    }
  }
}

// ── Flutter global error handler ─────────────────────────────
void setupGlobalErrorHandling() {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  // Catch async errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true; // handled
  };
}
