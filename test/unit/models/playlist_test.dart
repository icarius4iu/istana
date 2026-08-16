import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/models/playlist.dart';

void main() {
  test('songCount refleja la cantidad de songIds', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Rock',
      songIds: const ['a', 'b', 'c'],
      createdAt: DateTime(2026, 1, 1),
    );
    expect(playlist.songCount, 3);
  });

  test('copyWith reemplaza songIds sin mutar el original', () {
    final original = Playlist(
      id: 'p1',
      name: 'Rock',
      songIds: const ['a'],
      createdAt: DateTime(2026, 1, 1),
    );
    final updated = original.copyWith(songIds: const ['a', 'b']);

    expect(original.songIds, const ['a']);
    expect(updated.songIds, const ['a', 'b']);
  });

  test('igualdad por id/name/songIds (Equatable)', () {
    final createdAt = DateTime(2026, 1, 1);
    final a = Playlist(
      id: 'p1',
      name: 'Rock',
      songIds: const ['a'],
      createdAt: createdAt,
    );
    final b = Playlist(
      id: 'p1',
      name: 'Rock',
      songIds: const ['a'],
      createdAt: createdAt.add(
        const Duration(days: 1),
      ), // no participa de props
    );
    expect(a, b);
  });
}
