import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/user_repository.dart';
import '../../../../core/l10n/l10n.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  /// Set by the first submit: from then on, field errors update as the
  /// user types instead of lingering until the next submit.
  bool _submitted = false;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_submitted) setState(() => _submitted = true);
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).changePassword(_current.text, _next.text);
      if (!mounted) return;
      showSnack(context, context.l10n.passwordChanged);
      context.pop();
    } catch (e) {
      final status = httpStatus(e);
      if (mounted) {
        showSnack(context, status == 400 || status == 401 ? context.l10n.passwordCurrentWrong : describeError(e, context.l10n));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.passwordChangeTitle)),
      body: ReadableInset(
        maxWidth: ReadableWidths.form + 48,
        builder: (context, inset) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24 + inset, vertical: 24),
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(labelText: l.passwordCurrent, border: const OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? l.passwordCurrentRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: l.authNewPassword, border: const OutlineInputBorder(), hintText: l.authPasswordHint),
                validator: (v) {
                  if (v == null || v.length < 8) return l.authPasswordTooShort;
                  if (v.length > 72) return l.authPasswordTooLong;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: l.authConfirmNewPassword, border: const OutlineInputBorder()),
                validator: (v) => v != _next.text ? l.authPasswordMismatch : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.passwordUpdate),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
