import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/adaptive_layout.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  /// Set by the first submit: from then on, field errors update as the
  /// user types instead of lingering until the next submit.
  bool _submitted = false;
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final l = context.l10n;

    ref.listen(authStateProvider, (prev, next) {
      next.whenData((user) {
        if (user != null) context.go('/');
      });
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(httpStatus(next.error!) == 401
                ? l.authLoginBadCredentials
                : l.authLoginFailed(describeError(next.error!, l))),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ReadableInset(
            maxWidth: ReadableWidths.form + 48,
            builder: (context, inset) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24 + inset, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo.stacked(height: 128),
                const SizedBox(height: 12),
                Text(l.appTagline, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 48),
                Form(
                  key: _formKey,
                  autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _loginController,
                        decoration: InputDecoration(
                          labelText: l.authLoginField,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l.authLoginRequired : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: l.authPassword,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? l.authPasswordRequired : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text(l.authForgotPasswordLink),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: authState.isLoading ? null : _handleLogin,
                          child: authState.isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(l.authLogin),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(l.authNoAccount),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() {
    if (!_submitted) setState(() => _submitted = true);
    if (_formKey.currentState?.validate() != true) return;
    ref.read(authStateProvider.notifier).login(
      _loginController.text,
      _passwordController.text,
    );
  }
}
