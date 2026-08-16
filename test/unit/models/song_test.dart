import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/models/song.dart';

Song _song({String id = 'hash-1', String path = '/music/a.mp3'}) => Song(
  id: id,
  path: path,
  title: 'Título',
  artist: 'Artista',
  album: 'Álbum',
  duration: 180,
  hash: id,
  fileSize: 1024,
  dateAdded: DateTime(2026, 1, 1),
);

void main() {
  test('dos Song con mismo id/hash/path son iguales (Equatable)', () {
    expect(_song(), _song());
  });

  test('un id distinto rompe la igualdad', () {
    expect(_song(id: 'hash-1'), isNot(_song(id: 'hash-2')));
  });

  test('copyWith solo cambia los campos pasados', () {
    final original = _song();
    final renamed = original.copyWith(title: 'Otro título');

    expect(renamed.title, 'Otro título');
    expect(renamed.artist, original.artist);
    expect(renamed.id, original.id);
  });

  test('toJson/fromJson hacen un round-trip fiel', () {
    final original = _song();
    final decoded = Song.fromJson(original.toJson());

    expect(decoded, original);
    expect(decoded.dateAdded, original.dateAdded);
  });

  test('durationObj convierte segundos a Duration', () {
    expect(_song().durationObj, const Duration(seconds: 180));
  });
}
