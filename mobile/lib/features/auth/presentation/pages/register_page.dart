import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/adaptive_layout.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  /// Set by the first submit: from then on, field errors update as the
  /// user types instead of lingering until the next submit.
  bool _submitted = false;
  final _usernameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
          SnackBar(content: Text(l.authRegisterFailed(describeError(next.error!, l)))),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l.authRegister)),
      body: SafeArea(
        child: ReadableInset(
          maxWidth: ReadableWidths.form + 48,
          builder: (context, inset) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24 + inset, vertical: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 32),
                  child: BrandLogo.horizontal(height: 40),
                ),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                      labelText: l.authUsername, border: const OutlineInputBorder(), hintText: l.authUsernameHint),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.authUsernameRequired;
                    if (v.length < 4 || v.length > 20) return l.authUsernameLength;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(labelText: l.authNickname, border: const OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? l.authNicknameRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.authEmail, border: const OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.authEmailRequired;
                    if (!v.contains('@')) return l.authEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l.authPassword,
                    border: const OutlineInputBorder(),
                    hintText: l.authPasswordHint,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.authPasswordRequired;
                    if (v.length < 8) return l.authPasswordTooShort;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  decoration: InputDecoration(labelText: l.authConfirmPassword, border: const OutlineInputBorder()),
                  validator: (v) {
                    if (v != _passwordController.text) return l.authPasswordMismatch;
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _handleRegister,
                    child: authState.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.authRegister),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l.authHaveAccount),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _handleRegister() {
    if (!_submitted) setState(() => _submitted = true);
    if (_formKey.currentState?.validate() != true) return;
    ref.read(authStateProvider.notifier).register(
      _usernameController.text,
      _emailController.text,
      _passwordController.text,
      _nicknameController.text,
    );
  }
}
