import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showResendConfirmation = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;

    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required.');
      return;
    }

    setState(() => _loading = true);
    final result = await context.read<AppState>().loginWithPassword(
          email: email,
          password: password,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      final message = result.failure != null
          ? AuthService.failureMessage(result.failure!)
          : 'Sign in failed.';
      setState(() {
        _showResendConfirmation =
            result.failure == AuthFailure.emailNotConfirmed;
      });
      _showError(message);
    } else {
      setState(() => _showResendConfirmation = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email first.');
      return;
    }

    setState(() => _loading = true);
    final result = await AuthService.resendSignupConfirmation(email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      _showError('Confirmation email sent — check your inbox (and spam).');
    } else {
      final message = result.failure != null
          ? AuthService.failureMessage(result.failure!)
          : 'Could not resend email.';
      _showError(message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = AppLayout.pageGutter(context);
    final usesBackend = context.watch<AppState>().usesBackendAuth;

    return Scaffold(
      body: SafeArea(
        child: AdaptiveBody(
          maxWidth: AppLayout.formMaxWidth,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: (constraints.maxHeight * 0.22).clamp(120, 200),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.forest, AppColors.forestDeep],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'PaceMatch',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Find rides that match your pace',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        usesBackend
                            ? 'Sign in with your PaceMatch account.'
                            : 'Local demo — any email works without a backend.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_loading,
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                      if (_showResendConfirmation) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loading ? null : _resendConfirmation,
                          child: const Text('Resend confirmation email'),
                        ),
                      ],
                      if (!usesBackend) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  context.read<AppState>().login(
                                        email: 'demo@pacematch.app',
                                        name: 'Demo Rider',
                                      );
                                },
                          child: const Text('Continue as demo rider'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/register'),
                        child: const Text('Create an account'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
