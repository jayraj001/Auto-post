import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/accounts/screens/accounts_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/posts/screens/create_post_screen.dart';
import '../../features/posts/screens/calendar_screen.dart';
import '../../features/ai/screens/ai_studio_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/automation/screens/automation_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/billing/screens/plans_screen.dart';
import '../../features/shell/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth state changes
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/forgot-password';

      // Not logged in → send to login
      if (!isLoggedIn && !isAuthRoute) return '/login';
      // Already logged in → skip auth screens
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // ── Auth routes ──────────────────────────────────────────
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',        builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // ── App shell with bottom nav ────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',  builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/create',     builder: (_, __) => const CreatePostScreen()),
          GoRoute(path: '/calendar',   builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/ai-studio',  builder: (_, __) => const AiStudioScreen()),
          GoRoute(path: '/analytics',  builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/automation', builder: (_, __) => const AutomationScreen()),
          GoRoute(path: '/settings',   builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/accounts',   builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/plans',      builder: (_, __) => const PlansScreen()),
        ],
      ),
    ],
  );
});
