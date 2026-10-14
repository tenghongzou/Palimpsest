import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../data/auth_repository.dart';

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
    try {
      await ref.read(authRepositoryProvider).resetPassword(_tokenController.text.trim(), _passwordController.text);
      messenger.showSnackBar(const SnackBar(content: Text('密碼已重設，請使用新密碼登入')));
      if (mounted) context.go('/login');
    } catch (e) {
      final status = httpStatus(e);
      messenger.showSnackBar(SnackBar(
        content: Text(status == 400 ? '重設代碼無效或已過期' : describeError(e)),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重設密碼')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: '重設代碼', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? '請輸入信件中的重設代碼' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼', border: OutlineInputBorder(), hintText: '至少 8 個字元'),
                validator: (v) {
                  if (v == null || v.isEmpty) return '請輸入新密碼';
                  if (v.length < 8) return '密碼至少 8 個字元';
                  if (v.length > 72) return '密碼最多 72 個字元';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認新密碼', border: OutlineInputBorder()),
                validator: (v) => v != _passwordController.text ? '兩次輸入的密碼不一致' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('重設密碼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
