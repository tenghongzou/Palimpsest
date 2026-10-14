import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Display helpers shared across features, in the UI language [l].

/// A word count, abbreviated the local way: "1.2萬字", "1.2万字", "12.3K words".
String formatWordCount(int count, AppLocalizations l) {
  final format = NumberFormat.compact(locale: intlLocaleOf(l))..maximumFractionDigits = 1;
  return l.wordCount(format.format(count));
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

/// A count with the locale's digit grouping ("12,345").
String formatNumber(num value, AppLocalizations l) => NumberFormat.decimalPattern(intlLocaleOf(l)).format(value);

String formatDuration(int seconds, AppLocalizations l) {
  if (seconds >= 3600) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes == 0 ? l.durationHours(hours) : l.durationHoursMinutes(hours, minutes);
  }
  if (seconds >= 60) return l.durationMinutes(seconds ~/ 60);
  return l.durationSeconds(seconds);
}

/// A date in the locale's short form ("2026/10/3", "10/3/2026").
String formatDate(DateTime? time, AppLocalizations l) {
  if (time == null) return '';
  return DateFormat.yMd(intlLocaleOf(l)).format(time.toLocal());
}

/// A date and time in the locale's short form.
String formatDateTime(DateTime? time, AppLocalizations l) {
  if (time == null) return '';
  return DateFormat.yMd(intlLocaleOf(l)).add_Hm().format(time.toLocal());
}

/// Relative time such as "3 分鐘前" / "3 minutes ago", falling back to a
/// date after a week.
String formatRelative(DateTime? time, AppLocalizations l, {DateTime? now}) {
  if (time == null) return '';
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return l.relativeJustNow;
  if (diff.inHours < 1) return l.relativeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.relativeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.relativeDaysAgo(diff.inDays);
  return formatDate(time, l);
}

DateTime? parseDateTime(Object? value) => value is String ? DateTime.tryParse(value) : null;

final _numberedTitle = RegExp(r'^\s*第\s*[0-9０-９零〇一二兩两三四五六七八九十百千萬万]+\s*[章回節节卷]');

/// A chapter's label in lists: "第3章 標題" / "Chapter 3: Title", unless the
/// title already carries its own number (e.g. "第三章 沒有旗的船").
String chapterLabel(int number, String title, AppLocalizations l) {
  if (_numberedTitle.hasMatch(title)) return title;
  return title.isEmpty ? l.chapterNumber(number) : l.chapterNumberTitle(number, title);
}
