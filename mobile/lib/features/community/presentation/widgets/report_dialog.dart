import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/community_repository.dart';
import '../../domain/entities/community.dart';

/// Asks for a reason and reports [targetType]/[targetId] to moderators.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (context) => const _ReportDialog(),
  );
  if (result == null) return;
  try {
    await ref.read(communityRepositoryProvider).report(
          targetType: targetType,
          targetId: targetId,
          reason: result.$1,
          description: result.$2,
        );
    if (context.mounted) showSnack(context, '已送出檢舉，感謝您的回報');
  } catch (e) {
    if (context.mounted) showSnack(context, '檢舉失敗：${describeError(e)}');
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'spam';
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('檢舉'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: reportReasons.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _reason == e.key,
                        onSelected: (_) => setState(() => _reason = e.key),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '補充說明（選填）', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_reason, _description.text)),
          child: const Text('送出'),
        ),
      ],
    );
  }
}
