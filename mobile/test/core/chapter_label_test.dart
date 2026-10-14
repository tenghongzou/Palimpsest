import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:palimpsest/core/l10n/l10n.dart';
import 'package:palimpsest/core/utils/formatters.dart';

void main() {
  final zhTW = lookupAppLocalizations(const Locale('zh', 'TW'));
  final zhCN = lookupAppLocalizations(const Locale('zh', 'CN'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() => initializeDateFormatting());

  test('chapterLabel adds the number only when the title lacks one', () {
    expect(chapterLabel(3, '沒有旗的船', zhTW), '第3章 沒有旗的船');
    expect(chapterLabel(3, '第三章 沒有旗的船', zhTW), '第三章 沒有旗的船');
    expect(chapterLabel(12, '第12章 歸來', zhTW), '第12章 歸來');
    expect(chapterLabel(1, '第一回 起', zhTW), '第一回 起');
    expect(chapterLabel(5, '', zhTW), '第5章');
    // A title merely starting with 第 is not a chapter number.
    expect(chapterLabel(2, '第一次見面', zhTW), '第2章 第一次見面');
    // Simplified numbering is recognised too; English uses its own label.
    expect(chapterLabel(4, '第四节 归来', zhCN), '第四节 归来');
    expect(chapterLabel(5, '', en), 'Chapter 5');
    expect(chapterLabel(2, 'The Letter', en), 'Chapter 2: The Letter');
  });

  test('word counts use each language\'s units', () {
    expect(formatWordCount(281, zhTW), '281字');
    expect(formatWordCount(12345, zhTW), '1.2萬字');
    expect(formatWordCount(123456, zhCN), '12.3万字');
    expect(formatWordCount(12345, en), '12.3K words');
  });

  test('relative times and durations are localized', () {
    final now = DateTime(2026, 10, 14, 12);
    expect(formatRelative(now, zhTW, now: now), '剛剛');
    expect(formatRelative(now.subtract(const Duration(minutes: 3)), zhTW, now: now), '3 分鐘前');
    expect(formatRelative(now.subtract(const Duration(minutes: 3)), zhCN, now: now), '3 分钟前');
    expect(formatRelative(now.subtract(const Duration(minutes: 1)), en, now: now), '1 minute ago');
    expect(formatRelative(now.subtract(const Duration(hours: 5)), en, now: now), '5 hours ago');
    expect(formatRelative(now.subtract(const Duration(days: 2)), en, now: now), '2 days ago');
    // Older than a week: a date in the locale's order.
    final old = DateTime(2026, 9, 3, 8);
    expect(formatRelative(old, zhTW, now: now), '2026/9/3');
    expect(formatRelative(old, en, now: now), '9/3/2026');

    expect(formatDuration(3600, zhTW), '1 小時');
    expect(formatDuration(3660, zhCN), '1 小时 1 分');
    expect(formatDuration(7200, en), '2 hours');
    expect(formatDuration(90, en), '1 min');
    expect(formatNumber(1234567, en), '1,234,567');
  });
}
