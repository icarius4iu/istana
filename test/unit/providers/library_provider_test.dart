import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mp3_player_flutter/hive_models/song_hive.dart';
import 'package:mp3_player_flutter/models/song.dart';
import 'package:mp3_player_flutter/providers/library_provider.dart';
import 'package:mp3_player_flutter/services/file_service.dart';
import 'package:mp3_player_flutter/services/storage_service.dart';

class MockFileService extends Mock implements FileService {}

class MockStorageService extends Mock implements StorageService {}

Song _song(
  String id, {
  String artist = 'Artist',
  String title = 'Title',
  int duration = 100,
}) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: title,
  artist: artist,
  album: 'Album',
  duration: duration,
  hash: id,
  fileSize: 100,
  dateAdded: DateTime(2026, 1, 1),
);

void main() {
  late MockFileService fileService;
  late MockStorageService storageService;

  setUpAll(() {
    registerFallbackValue(SongHive.fromSong(_song('fallback')));
  });

  setUp(() {
    fileService = MockFileService();
    storageService = MockStorageService();

    when(() => storageService.getAllSongs()).thenReturn([]);
    when(() => storageService.putSong(any())).thenAnswer((_) async {});
    when(() => storageService.deleteSong(any())).thenAnswer((_) async {});
    when(() => storageService.lastLibraryScan).thenReturn(null);
    when(() => storageService.setLastLibraryScan(any()))
        .thenAnswer((_) async {});
  });

  LibraryProvider build() =>
      LibraryProvider(fileService: fileService, storage: storageService);

  test('arranca leyendo lo que ya había en Hive, ordenado por artista', () {
    when(() => storageService.getAllSongs()).thenReturn([
      SongHive.fromSong(_song('1', artist: 'Zeta')),
      SongHive.fromSong(_song('2', artist: 'Alfa')),
    ]);

    final library = build();

    expect(library.songs.map((s) => s.artist), ['Alfa', 'Zeta']);
  });

  test('pickAndAddSong agrega la canción y la persiste', () async {
    when(() => fileService.pickSongFromDevice())
        .thenAnswer((_) async => _song('new'));

    final library = build();
    final result = await library.pickAndAddSong();

    expect(result?.id, 'new');
    expect(library.songs, hasLength(1));
    verify(() => storageService.putSong(any())).called(1);
  });

  test('agregar dos canciones con el mismo hash deduplica', () async {
    when(() => fileService.pickSongFromDevice())
        .thenAnswer((_) async => _song('dup', title: 'Original'));

    final library = build();
    await library.pickAndAddSong();
    await library.pickAndAddSong(); // mismo hash ('dup')

    expect(library.songs, hasLength(1));
  });

  test(
    'scanLibrary usa las carpetas sugeridas si no se pasan explícitas',
    () async {
      when(() => fileService.suggestedLibraryFolders())
          .thenAnswer((_) async => ['/music']);
      when(() => fileService.scanLocalLibrary(['/music']))
          .thenAnswer((_) async => [_song('scanned')]);

      final library = build();
      await library.scanLibrary();

      expect(library.songs, hasLength(1));
      expect(library.isLoading, isFalse);
      verify(() => storageService.setLastLibraryScan(any())).called(1);
    },
  );

  test(
    'filteredSongs busca por título, artista y álbum sin importar mayúsculas',
    () {
      when(() => storageService.getAllSongs()).thenReturn([
        SongHive.fromSong(
          _song('1', title: 'Bohemian Rhapsody', artist: 'Queen'),
        ),
        SongHive.fromSong(_song('2', title: 'Yellow', artist: 'Coldplay')),
      ]);

      final library = build();
      library.setSearchQuery('queen');

      expect(library.filteredSongs, hasLength(1));
      expect(library.filteredSongs.single.title, 'Bohemian Rhapsody');
    },
  );

  test(
    'removeSong saca la canción de la lista y la borra de storage',
    () async {
      when(() => storageService.getAllSongs())
          .thenReturn([SongHive.fromSong(_song('to-remove'))]);

      final library = build();
      expect(library.songs, hasLength(1));

      await library.removeSong('to-remove');

      expect(library.songs, isEmpty);
      verify(() => storageService.deleteSong('to-remove')).called(1);
    },
  );

  test('updateDuration solo persiste si la duración cambió', () async {
    when(() => storageService.getAllSongs())
        .thenReturn([SongHive.fromSong(_song('s', duration: 0))]);

    final library = build();
    final song = library.songs.single;

    await library.updateDuration(song, const Duration(seconds: 180));

    expect(library.songs.single.duration, 180);
    verify(() => storageService.putSong(any())).called(1);

    // Volver a "actualizar" con el mismo valor no debería escribir de nuevo.
    // El `verify` de arriba ya consumió la única llamada registrada hasta
    // ahora, así que si esto disparara una nueva, `verifyNever` la vería.
    await library.updateDuration(
      library.songs.single,
      const Duration(seconds: 180),
    );
    verifyNever(() => storageService.putSong(any()));
  });
}
