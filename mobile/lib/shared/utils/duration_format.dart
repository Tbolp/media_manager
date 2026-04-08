// lib/shared/utils/duration_format.dart
// 时长格式化工具

class DurationFormat {
  DurationFormat._();

  /// 将秒数格式化为 HH:MM:SS 或 MM:SS
  static String format(double? seconds) {
    if (seconds == null) return '';
    final dur = Duration(seconds: seconds.round());
    final h = dur.inHours;
    final m = dur.inMinutes.remainder(60);
    final s = dur.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
