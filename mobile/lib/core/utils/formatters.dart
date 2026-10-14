/// Display helpers shared across features (Traditional Chinese wording).
String formatWordCount(int count) {
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}萬字';
  return '$count字';
}

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String formatDuration(int seconds) {
  if (seconds >= 3600) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return minutes == 0 ? '$hours 小時' : '$hours 小時 $minutes 分';
  }
  if (seconds >= 60) return '${seconds ~/ 60} 分鐘';
  return '$seconds 秒';
}

String formatDateTime(DateTime? time) {
  if (time == null) return '';
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// Relative time such as "3 分鐘前", falling back to a date after a week.
String formatRelative(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inHours < 1) return '${diff.inMinutes} 分鐘前';
  if (diff.inDays < 1) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return formatDateTime(time).split(' ').first;
}

DateTime? parseDateTime(Object? value) => value is String ? DateTime.tryParse(value) : null;
