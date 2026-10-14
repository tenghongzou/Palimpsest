import '../../../core/l10n/l10n.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/app_notification.dart';

/// Notification text in the UI language, written from `params`. The server's
/// zh-TW `title` and `body` are the fallback whenever a needed param is
/// missing (older notifications, `system` announcements, unknown types).
extension LocalizedNotification on AppNotification {
  String localizedTitle(AppLocalizations l) {
    switch (type) {
      case NotificationTypes.chapterUpdate:
        final novel = params[NotificationParams.novel];
        if (novel != null) return l.notificationChapterUpdateTitle(novel);
      case NotificationTypes.commentReply:
        final actor = params[NotificationParams.actor];
        if (actor != null) return l.notificationCommentReplyTitle(actor);
    }
    return title;
  }

  /// For comment replies the body is the reply's excerpt, shown as sent.
  String? localizedBody(AppLocalizations l) {
    if (type == NotificationTypes.chapterUpdate) {
      final chapter = params[NotificationParams.chapter];
      final number = int.tryParse(params[NotificationParams.chapterNumber] ?? '');
      if (number != null) return l.notificationChapterUpdateBody(chapterLabel(number, chapter ?? '', l));
      if (chapter != null) return l.notificationChapterUpdateBody(chapter);
    }
    return body;
  }
}
