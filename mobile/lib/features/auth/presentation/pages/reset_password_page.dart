import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../data/auth_repository.dart';
import '../../../../core/l10n/l10n.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  /// Token from the reset link, when opened from it.
  final String? token;

  const ResetPasswordPage({super.key, this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _tokenController = TextEditingController(text: widget.token ?? '');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await ref.read(authRepositoryProvider).resetPassword(_tokenController.text.trim(), _passwordController.text);
      messenger.showSnackBar(SnackBar(content: Text(l.authResetDone)));
      if (mounted) context.go('/login');
    } catch (e) {
      final status = httpStatus(e);
      messenger.showSnackBar(SnackBar(
        content: Text(status == 400 ? l.authResetCodeInvalid : describeError(e, l)),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.authResetTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(labelText: l.authResetCode, border: const OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? l.authResetCodeRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: l.authNewPassword, border: const OutlineInputBorder(), hintText: l.authPasswordHint),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.authNewPasswordRequired;
                  if (v.length < 8) return l.authPasswordTooShort;
                  if (v.length > 72) return l.authPasswordTooLong;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: l.authConfirmNewPassword, border: const OutlineInputBorder()),
                validator: (v) => v != _passwordController.text ? l.authPasswordMismatch : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.authResetTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
