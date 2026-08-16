/// Formateo de duración, tamaño de archivo y fechas para la UI.
class FormatUtils {
  FormatUtils._();

  /// `Duration(seconds: 65)` -> "1:05". Con horas: "1:02:03".
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
    }
    return '$minutes:${_twoDigits(seconds)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 1536000 -> "1.5 MB"
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final formatted = unitIndex == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$formatted ${units[unitIndex]}';
  }

  /// Fecha relativa corta: "hoy", "ayer", "12/03/2026".
  static String formatDateAdded(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 7) return 'hace $diff días';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// "3 canciones" / "1 canción"
  static String songCountLabel(int count) {
    return count == 1 ? '1 canción' : '$count canciones';
  }
}
