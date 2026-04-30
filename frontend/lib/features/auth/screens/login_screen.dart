import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  bool    _loading = false;
  bool    _obscure = true;
  String? _errorMsg;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Logo ──────────────────────────────────────
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.secondary]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('AutoPost AI',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 40),

                const Text('Welcome back 👋',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Sign in to manage your social media',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 15)),
                const SizedBox(height: 32),

                // ── Error banner ──────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ─────────────────────────────────────
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v != null && v.contains('@')
                          ? null
                          : 'Enter a valid email',
                ),
                const SizedBox(height: 16),

                // ── Password ──────────────────────────────────
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onSignIn(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 6
                          ? null
                          : 'Minimum 6 characters',
                ),
                const SizedBox(height: 8),

                // ── Forgot password ───────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Sign In button ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onSignIn,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Divider ───────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                // ── Google Sign In ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _onGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Register link ─────────────────────────────
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("Don't have an account? ",
                        style: TextStyle(color: Colors.grey[600])),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sign In ───────────────────────────────────────────────────
  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      await ref.read(authServiceProvider).signIn(
        emailController.text.trim(),
        passwordController.text,
      );
      // GoRouter redirect handles navigation automatically
      // authStateProvider stream fires → router redirects to /dashboard
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (e) {
      setState(() => _errorMsg = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign In ────────────────────────────────────────────
  Future<void> _onGoogleSignIn() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        setState(() => _errorMsg = 'Google sign-in was cancelled.');
      }
      // GoRouter handles redirect on success
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (e) {
      setState(() => _errorMsg = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
