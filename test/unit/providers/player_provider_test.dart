// PlayerProvider es la pieza con más lógica del MVP (cola, shuffle, repeat,
// auto-avance), así que se prueba con un AudioService/StorageService de
// mentira (mocktail) en vez de depender de un reproductor real.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mp3_player_flutter/hive_models/app_settings.dart';
import 'package:mp3_player_flutter/models/playback_state.dart';
import 'package:mp3_player_flutter/models/song.dart';
import 'package:mp3_player_flutter/providers/player_provider.dart';
import 'package:mp3_player_flutter/services/audio_service.dart';
import 'package:mp3_player_flutter/services/storage_service.dart';

class MockAudioService extends Mock implements AudioService {}

class MockStorageService extends Mock implements StorageService {}

Song _song(String id) => Song(
  id: id,
  path: '/music/$id.mp3',
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  duration: 200,
  hash: id,
  fileSize: 100,
  dateAdded: DateTime(2026, 1, 1),
);

/// Deja pasar un tick de microtasks — suficiente para que se asiente
/// cualquier `Future` fire-and-forget (p. ej. `_restoreSettings()` desde el
/// constructor) antes de que el test siga interactuando con el provider.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockAudioService audioService;
  late MockStorageService storageService;
  late StreamController<PlayerState> stateController;
  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;
  late StreamController<void> completeController;

  setUpAll(() {
    registerFallbackValue(AppSettings.defaults());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    audioService = MockAudioService();
    storageService = MockStorageService();

    stateController = StreamController<PlayerState>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    completeController = StreamController<void>.broadcast();

    when(() => audioService.playerStateStream)
        .thenAnswer((_) => stateController.stream);
    when(() => audioService.positionStream)
        .thenAnswer((_) => positionController.stream);
    when(() => audioService.durationStream)
        .thenAnswer((_) => durationController.stream);
    when(() => audioService.onSongComplete)
        .thenAnswer((_) => completeController.stream);
    when(() => audioService.loadSong(any()))
        .thenAnswer((_) async => const Duration(seconds: 200));
    when(() => audioService.play()).thenAnswer((_) async {});
    when(() => audioService.pause()).thenAnswer((_) async {});
    when(() => audioService.stop()).thenAnswer((_) async {});
    when(() => audioService.seek(any())).thenAnswer((_) async {});
    when(() => audioService.setVolume(any())).thenAnswer((_) async {});
    when(() => audioService.dispose()).thenAnswer((_) async {});

    when(() => storageService.getSettings()).thenReturn(AppSettings.defaults());
    when(() => storageService.saveSettings(any())).thenAnswer((_) async {});
    when(() => storageService.addRecentlyPlayed(any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await stateController.close();
    await positionController.close();
    await durationController.close();
    await completeController.close();
  });

  Future<PlayerProvider> build() async {
    final provider = PlayerProvider(
      audioService: audioService,
      storage: storageService,
    );
    await _settle(); // deja resolver `_restoreSettings()` del constructor
    return provider;
  }

  test('loadQueue reproduce la primera canción y expone currentSong', () async {
    final provider = await build();
    final songs = [_song('a'), _song('b'), _song('c')];

    await provider.loadQueue(songs);

    expect(provider.currentSong?.id, 'a');
    expect(provider.currentIndex, 0);
    verify(() => audioService.loadSong('/music/a.mp3')).called(1);
    verify(() => audioService.play()).called(1);
  });

  test(
    'next avanza en la cola; en el último sin repeat no hace nada',
    () async {
      final provider = await build();
      await provider.loadQueue([_song('a'), _song('b')]);

      await provider.next();
      expect(provider.currentSong?.id, 'b');
      expect(provider.hasNext, isFalse);

      await provider.next(); // ya está en la última: no debería cambiar nada
      expect(provider.currentSong?.id, 'b');
    },
  );

  test('con repeatMode.all, next() en la última vuelve a la primera', () async {
    final provider = await build();
    await provider.loadQueue([_song('a'), _song('b')]);

    provider.toggleRepeat(); // off -> one
    provider.toggleRepeat(); // one -> all
    expect(provider.repeatMode, RepeatMode.all);

    await provider.next(); // a -> b
    await provider.next(); // b -> vuelve a a (wrap)

    expect(provider.currentSong?.id, 'a');
  });

  test('toggleShuffle mantiene la canción actual fija', () async {
    final provider = await build();
    await provider.loadQueue([
      _song('a'),
      _song('b'),
      _song('c'),
    ], startIndex: 1);

    expect(provider.currentSong?.id, 'b');

    provider.toggleShuffle();

    expect(provider.shuffle, isTrue);
    expect(provider.currentSong?.id, 'b'); // no salta de canción al togglear
  });

  test(
    'al completarse con repeatMode.one, reinicia la misma canción',
    () async {
      final provider = await build();
      await provider.loadQueue([_song('a'), _song('b')]);
      provider.toggleRepeat(); // off -> one

      completeController.add(null);
      await _settle();

      verify(() => audioService.seek(Duration.zero)).called(1);
      expect(provider.currentSong?.id, 'a');
    },
  );

  test('al completarse la última canción sin repeat, no avanza', () async {
    final provider = await build();
    await provider.loadQueue([_song('a')]);

    completeController.add(null);
    await _settle();

    expect(provider.currentSong?.id, 'a');
  });

  test('previous() reinicia la canción si ya sonó más de 3s', () async {
    final provider = await build();
    await provider.loadQueue([_song('a'), _song('b')], startIndex: 1);

    positionController.add(const Duration(seconds: 10));
    await _settle();

    await provider.previous();

    verify(() => audioService.seek(Duration.zero))
        .called(greaterThanOrEqualTo(1));
    expect(
      provider.currentSong?.id,
      'b',
    ); // no cambió de canción, solo hizo seek
  });

  test('setVolume clampea a [0,1] y persiste en storage', () async {
    final provider = await build();

    await provider.setVolume(1.5);
    expect(provider.volume, 1.0);

    await provider.setVolume(-1);
    expect(provider.volume, 0.0);

    verify(() => storageService.saveSettings(any()))
        .called(greaterThanOrEqualTo(1));
  });
}
