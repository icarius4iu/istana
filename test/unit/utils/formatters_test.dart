import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/utils/formatters.dart';

void main() {
  group('FormatUtils.formatDuration', () {
    test('formatea segundos y minutos sin horas', () {
      expect(FormatUtils.formatDuration(const Duration(seconds: 5)), '0:05');
      expect(FormatUtils.formatDuration(const Duration(seconds: 65)), '1:05');
      expect(
        FormatUtils.formatDuration(const Duration(minutes: 9, seconds: 9)),
        '9:09',
      );
    });

    test('formatea horas cuando corresponde', () {
      expect(
        FormatUtils.formatDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });

    test('duración negativa cae a 0:00', () {
      expect(FormatUtils.formatDuration(const Duration(seconds: -5)), '0:00');
    });

    test('cero exacto', () {
      expect(FormatUtils.formatDuration(Duration.zero), '0:00');
    });
  });

  group('FormatUtils.formatFileSize', () {
    test('bytes, KB, MB y GB', () {
      expect(FormatUtils.formatFileSize(0), '0 B');
      expect(FormatUtils.formatFileSize(500), '500 B');
      expect(FormatUtils.formatFileSize(1536), '1.5 KB');
      expect(FormatUtils.formatFileSize(5 * 1024 * 1024), '5.0 MB');
      expect(FormatUtils.formatFileSize(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });

  group('FormatUtils.songCountLabel', () {
    test('singular vs plural', () {
      expect(FormatUtils.songCountLabel(0), '0 canciones');
      expect(FormatUtils.songCountLabel(1), '1 canción');
      expect(FormatUtils.songCountLabel(2), '2 canciones');
    });
  });

  group('FormatUtils.formatDateAdded', () {
    test('hoy y ayer', () {
      final now = DateTime.now();
      expect(FormatUtils.formatDateAdded(now), 'hoy');
      expect(
        FormatUtils.formatDateAdded(now.subtract(const Duration(days: 1))),
        'ayer',
      );
    });

    test('fecha lejana cae al formato dd/mm/yyyy', () {
      final farAway = DateTime.now().subtract(const Duration(days: 400));
      final formatted = FormatUtils.formatDateAdded(farAway);
      expect(formatted, matches(RegExp(r'^\d{2}/\d{2}/\d{4}$')));
    });
  });
}
