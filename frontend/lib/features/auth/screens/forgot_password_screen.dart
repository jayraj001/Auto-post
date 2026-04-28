import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _SuccessView(email: _emailCtrl.text) : _FormView(
            formKey: _formKey,
            emailCtrl: _emailCtrl,
            loading: _loading,
            errorMsg: _errorMsg,
            onSubmit: _sendReset,
          ),
        ),
      ),
    );
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      await ref.read(authServiceProvider).sendPasswordReset(_emailCtrl.text);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (e) {
      setState(() => _errorMsg = 'Failed to send reset email. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final String? errorMsg;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey, required this.emailCtrl,
    required this.loading, required this.errorMsg, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const Icon(Icons.lock_reset, size: 56, color: AppTheme.primary),
        const SizedBox(height: 20),
        const Text('Forgot your password?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Enter your email and we'll send you a reset link.",
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),

        if (errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) =>
              v != null && v.contains('@') ? null : 'Enter a valid email',
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Send Reset Link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Sign In'),
          ),
        ),
      ]),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  const _SuccessView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 40, color: AppTheme.secondary),
        ),
        const SizedBox(height: 24),
        const Text('Check your inbox!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to\n$email',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Sign In',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
