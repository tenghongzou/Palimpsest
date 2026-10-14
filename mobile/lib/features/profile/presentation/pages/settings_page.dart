import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/user_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          if (user != null) ...[
            const _SectionTitle('個人資料'),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null ? const Icon(Icons.person_outline) : null,
              ),
              title: const Text('頭像'),
              subtitle: const Text('從相簿選擇圖片'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _pickAvatar(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('暱稱'),
              subtitle: Text(user.nickname.isEmpty ? '未設定' : user.nickname),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editField(context, ref, title: '修改暱稱', initial: user.nickname, maxLength: 50, field: 'nickname'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('個人簡介'),
              subtitle: Text(user.bio == null || user.bio!.isEmpty ? '未設定' : user.bio!, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editField(context, ref, title: '修改個人簡介', initial: user.bio ?? '', maxLength: 500, field: 'bio'),
            ),
            const _SectionTitle('帳號安全'),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('修改密碼'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/password'),
            ),
          ],
          const _SectionTitle('閱讀'),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('閱讀設定'),
            subtitle: Text(user == null ? '字體、行距、背景主題' : '字體、行距、背景主題（與雲端同步）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reading'),
          ),
          const _SectionTitle('儲存空間'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('離線下載與快取'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/downloads'),
          ),
        ],
      ),
    );
  }

  /// Picks a photo, scaled down so it stays well under the server's 2 MB limit.
  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    } catch (_) {
      if (context.mounted) showSnack(context, '無法開啟相簿');
      return;
    }
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final updated = await ref.read(userRepositoryProvider).uploadAvatar(bytes, picked.name);
      ref.read(authStateProvider.notifier).updateUser(updated);
      if (context.mounted) showSnack(context, '頭像已更新');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e));
    }
  }

  Future<void> _editField(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required int maxLength,
    required String field,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: field == 'bio' ? 4 : 1,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('儲存')),
        ],
      ),
    );
    if (value == null || value == initial) return;
    if (field == 'nickname' && value.isEmpty) {
      if (context.mounted) showSnack(context, '暱稱不可為空白');
      return;
    }
    try {
      final repo = ref.read(userRepositoryProvider);
      final updated = field == 'nickname' ? await repo.updateProfile(nickname: value) : await repo.updateProfile(bio: value);
      ref.read(authStateProvider.notifier).updateUser(updated);
      if (context.mounted) showSnack(context, '已更新');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
      );
}
