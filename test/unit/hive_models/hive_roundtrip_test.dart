// Prueba la serialización binaria real de Hive (no solo la conversión
// Dart<->Hive en memoria), con `Hive.init` apuntando a un directorio
// temporal — a diferencia de `Hive.initFlutter()` (lo que usa
// StorageService), esto no depende del plugin `path_provider`, que no
// tiene canal de plataforma real corriendo bajo `flutter test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mp3_player_flutter/hive_models/app_settings.dart';
import 'package:mp3_player_flutter/hive_models/playlist_hive.dart';
import 'package:mp3_player_flutter/hive_models/song_hive.dart';
import 'package:mp3_player_flutter/models/playlist.dart';
import 'package:mp3_player_flutter/models/song.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    // Los adapters se registran una sola vez para todo el archivo: Hive
    // guarda el registro en un singleton global, y un segundo
    // `registerAdapter` con el mismo typeId revienta con
    // "There is already a TypeAdapter for typeId 0".
    Hive.registerAdapter(SongHiveAdapter());
    Hive.registerAdapter(PlaylistHiveAdapter());
    Hive.registerAdapter(AppSettingsAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mp3_player_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'SongHive sobrevive a un ciclo completo de escritura/lectura en disco',
    () async {
      final box = await Hive.openBox<SongHive>('songs');
      final song = Song(
        id: 'hash-abc',
        path: '/music/a.mp3',
        title: 'Título',
        artist: 'Artista',
        album: 'Álbum',
        duration: 210,
        hash: 'hash-abc',
        fileSize: 2048,
        dateAdded: DateTime(2026, 3, 1, 10, 30),
      );

      await box.put(song.id, SongHive.fromSong(song));
      await box.close();

      final reopened = await Hive.openBox<SongHive>('songs');
      final restored = reopened.get('hash-abc')!.toSong();

      expect(restored, song);
      expect(restored.dateAdded, song.dateAdded);
    },
  );

  test('PlaylistHive conserva el orden de songIds', () async {
    final box = await Hive.openBox<PlaylistHive>('playlists');
    final playlist = Playlist(
      id: 'p1',
      name: 'Para correr',
      songIds: const ['s3', 's1', 's2'],
      createdAt: DateTime(2026, 1, 1),
    );

    await box.put(playlist.id, PlaylistHive.fromPlaylist(playlist));
    final restored = box.get('p1')!.toPlaylist();

    expect(restored.songIds, const ['s3', 's1', 's2']);
    expect(restored.name, 'Para correr');
  });

  test(
    'AppSettings.defaults tiene valores razonables y persiste cambios',
    () async {
      final box = await Hive.openBox<AppSettings>('settings');
      final defaults = AppSettings.defaults();

      expect(defaults.volume, 1.0);
      expect(defaults.shuffle, isFalse);
      expect(defaults.repeatModeIndex, 0);
      expect(defaults.libraryFolders, isEmpty);

      defaults.volume = 0.4;
      defaults.shuffle = true;
      await box.put('app_settings', defaults);

      final restored = box.get('app_settings')!;
      expect(restored.volume, 0.4);
      expect(restored.shuffle, isTrue);
    },
  );
}
