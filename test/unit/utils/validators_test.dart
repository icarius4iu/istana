import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/utils/validators.dart';

void main() {
  group('Validators.playlistName', () {
    test('rechaza vacío o solo espacios', () {
      expect(Validators.playlistName(''), isNotNull);
      expect(Validators.playlistName('   '), isNotNull);
      expect(Validators.playlistName(null), isNotNull);
    });

    test('acepta un nombre válido', () {
      expect(Validators.playlistName('Mis favoritas'), isNull);
    });

    test('rechaza más de 60 caracteres', () {
      final tooLong = 'a' * 61;
      expect(Validators.playlistName(tooLong), isNotNull);
    });

    test('acepta exactamente 60 caracteres', () {
      final exact = 'a' * 60;
      expect(Validators.playlistName(exact), isNull);
    });
  });

  group('Validators.isSupportedAudioFile', () {
    const formats = ['mp3', 'wav', 'flac', 'm4a'];

    test('extensión soportada, sin importar mayúsculas', () {
      expect(Validators.isSupportedAudioFile('cancion.MP3', formats), isTrue);
      expect(Validators.isSupportedAudioFile('cancion.flac', formats), isTrue);
    });

    test('extensión no soportada', () {
      expect(Validators.isSupportedAudioFile('imagen.png', formats), isFalse);
    });
  });
}
