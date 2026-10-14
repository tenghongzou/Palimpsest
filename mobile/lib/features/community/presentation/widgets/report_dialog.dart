import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/community_repository.dart';
import '../../domain/entities/community.dart';
import '../../../../core/l10n/l10n.dart';

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
    if (context.mounted) showSnack(context, context.l10n.reportSent);
  } catch (e) {
    if (context.mounted) showSnack(context, context.l10n.reportFailed(describeError(e, context.l10n)));
  }
}

String reportReasonLabel(String reason, AppLocalizations l) => switch (reason) {
      'spam' => l.reportReasonSpam,
      'abuse' => l.reportReasonAbuse,
      'spoiler' => l.reportReasonSpoiler,
      'copyright' => l.reportReasonCopyright,
      'inappropriate' => l.reportReasonInappropriate,
      'other' => l.reportReasonOther,
      _ => reason,
    };

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
      title: Text(context.l10n.report),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: reportReasons
                  .map((e) => ChoiceChip(
                        label: Text(reportReasonLabel(e, context.l10n)),
                        selected: _reason == e,
                        onSelected: (_) => setState(() => _reason = e),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(hintText: context.l10n.reportDetailsHint, border: const OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_reason, _description.text)),
          child: Text(context.l10n.commonSubmit),
        ),
      ],
    );
  }
}
