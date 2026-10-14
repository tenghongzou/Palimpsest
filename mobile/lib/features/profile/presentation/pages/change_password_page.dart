import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/user_repository.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
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
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).changePassword(_current.text, _next.text);
      if (!mounted) return;
      showSnack(context, '密碼已更新');
      context.pop();
    } catch (e) {
      final status = httpStatus(e);
      if (mounted) showSnack(context, status == 400 || status == 401 ? '目前密碼不正確' : describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密碼')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(labelText: '目前密碼', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? '請輸入目前密碼' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼', border: OutlineInputBorder(), hintText: '至少 8 個字元'),
                validator: (v) {
                  if (v == null || v.length < 8) return '密碼至少 8 個字元';
                  if (v.length > 72) return '密碼最多 72 個字元';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認新密碼', border: OutlineInputBorder()),
                validator: (v) => v != _next.text ? '兩次輸入的密碼不一致' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('更新密碼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
