import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../data/auth_repository.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('忘記密碼')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    '若此電子郵件已註冊，我們已寄出重設密碼的連結，請至信箱查收。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/reset-password'),
                    child: const Text('輸入重設代碼'),
                  ),
                  TextButton(onPressed: () => context.go('/login'), child: const Text('返回登入')),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('請輸入註冊時使用的電子郵件，我們會寄送重設密碼的連結給您。'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '電子郵件', border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '請輸入電子郵件';
                        if (!v.contains('@')) return '電子郵件格式不正確';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('寄送重設連結'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/reset-password'),
                      child: const Text('已經有重設代碼？'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
