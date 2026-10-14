import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../data/auth_repository.dart';
import '../../../../core/l10n/l10n.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  /// Set by the first submit: from then on, field errors update as the
  /// user types instead of lingering until the next submit.
  bool _submitted = false;
  final _emailController = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_submitted) setState(() => _submitted = true);
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e, context.l10n))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.authForgotTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(l.authResetSent, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/reset-password'),
                    child: Text(l.authEnterResetCode),
                  ),
                  TextButton(onPressed: () => context.go('/login'), child: Text(l.authBackToLogin)),
                ],
              )
            : Form(
                key: _formKey,
                autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.authForgotIntro),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l.authEmail, border: const OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l.authEmailRequired;
                        if (!v.contains('@')) return l.authEmailInvalid;
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.authSendResetLink),
                    ),
                    TextButton(
                      onPressed: () => context.push('/reset-password'),
                      child: Text(l.authHaveResetCode),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
