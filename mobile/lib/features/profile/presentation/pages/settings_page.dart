import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/user_repository.dart';
import '../providers/app_language_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final l = context.l10n;
    final language = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          if (user != null) ...[
            _SectionTitle(l.settingsProfile),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null ? const Icon(Icons.person_outline) : null,
              ),
              title: Text(l.settingsAvatar),
              subtitle: Text(l.settingsAvatarPick),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _pickAvatar(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l.authNickname),
              subtitle: Text(user.nickname.isEmpty ? l.settingsNotSet : user.nickname),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editField(context, ref, title: l.settingsEditNickname, initial: user.nickname, maxLength: 50, field: 'nickname'),
            ),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: Text(l.settingsBio),
              subtitle: Text(user.bio == null || user.bio!.isEmpty ? l.settingsNotSet : user.bio!, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editField(context, ref, title: l.settingsEditBio, initial: user.bio ?? '', maxLength: 500, field: 'bio'),
            ),
            _SectionTitle(l.settingsSecurity),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l.passwordChangeTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/password'),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(l.devicesTitle),
              subtitle: Text(l.settingsDevicesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/devices'),
            ),
          ],
          _SectionTitle(l.settingsReading),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(l.readingSettings),
            subtitle: Text(user == null ? l.settingsReadingSubtitle : l.settingsReadingSubtitleSynced),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/reading'),
          ),
          _SectionTitle(l.settingsGeneral),
          ListTile(
            key: const ValueKey('settings-language'),
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            subtitle: Text(languageOptionLabel(language.setting, l)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, ref),
          ),
          _SectionTitle(l.settingsStorage),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l.settingsDownloads),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/downloads'),
          ),
        ],
      ),
    );
  }

  /// The UI language: follow the device, or one of the app's languages.
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appLanguageProvider).setting;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.settingsLanguage),
        children: [
          for (final option in [followSystemLanguage, ...appLanguages])
            ListTile(
              key: ValueKey('language-$option'),
              title: Text(languageOptionLabel(option, context.l10n)),
              trailing: option == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, option),
            ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    final result = await ref.read(appLanguageProvider.notifier).select(picked);
    if (!context.mounted) return;
    if (result == LanguageChange.reverted) {
      showSnack(context, context.l10n.settingsLanguageSaveFailed(context.l10n.errorServer));
    } else if (result == LanguageChange.savedLater && ref.read(authStateProvider).valueOrNull != null) {
      showSnack(context, context.l10n.settingsLanguageSavedLater);
    }
  }

  /// Picks a photo, scaled down so it stays well under the server's 2 MB limit.
  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    } catch (_) {
      if (context.mounted) showSnack(context, context.l10n.settingsGalleryFailed);
      return;
    }
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final updated = await ref.read(userRepositoryProvider).uploadAvatar(bytes, picked.name);
      ref.read(authStateProvider.notifier).updateUser(updated);
      if (context.mounted) showSnack(context, context.l10n.settingsAvatarUpdated);
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e, context.l10n));
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(context.l10n.commonSave)),
        ],
      ),
    );
    if (value == null || value == initial) return;
    if (field == 'nickname' && value.isEmpty) {
      if (context.mounted) showSnack(context, context.l10n.settingsNicknameEmpty);
      return;
    }
    try {
      final repo = ref.read(userRepositoryProvider);
      final updated = field == 'nickname' ? await repo.updateProfile(nickname: value) : await repo.updateProfile(bio: value);
      ref.read(authStateProvider.notifier).updateUser(updated);
      if (context.mounted) showSnack(context, context.l10n.settingsUpdated);
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e, context.l10n));
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

/// A language option's name: languages are named in themselves.
String languageOptionLabel(String option, AppLocalizations l) => switch (option) {
      'zh-TW' => '繁體中文',
      'zh-CN' => '简体中文',
      'en' => 'English',
      _ => l.settingsLanguageSystem,
    };
