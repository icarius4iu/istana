import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/playback_state.dart' as domain;
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

/// Controla la reproducción: cola actual, orden (normal/shuffle), repeat,
/// volumen y el estado en vivo que llega desde [AudioService].
///
/// Nota sobre shuffle: no se reordena `_queue` (eso rompería "canción 3 de
/// 10" en la UI); se mantiene un `_order` — permutación de índices de
/// `_queue` — y `_position` es el índice dentro de `_order`. Así togglear
/// shuffle a mitad de reproducción no salta de canción: la actual queda
/// fija en `_order[_position]` y solo se reordena el resto.
class PlayerProvider extends ChangeNotifier {
  final AudioService _audioService;
  final StorageService? _storage;

  /// Se invoca cuando just_audio resuelve una duración real distinta de la
  /// que traía la canción (0 en Web hasta que se carga el audio — ver
  /// `file_service_web.dart`), para que LibraryProvider la persista.
  void Function(Song song, Duration duration)? onDurationResolved;

  List<Song> _queue = [];
  List<int> _order = [];
  int _position = 0;

  domain.PlayerState _state = domain.PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _shuffle = false;
  domain.RepeatMode _repeatMode = domain.RepeatMode.off;
  double _volume = 1.0;
  String? _errorMessage;

  StreamSubscription<domain.PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<void>? _completeSub;

  PlayerProvider({required AudioService audioService, StorageService? storage})
    : _audioService = audioService,
      _storage = storage {
    _listenToAudioService();
    unawaited(_restoreSettings());
  }

  Future<void> _restoreSettings() async {
    final settings = _storage?.getSettings();
    if (settings == null) return;

    _volume = settings.volume;
    _shuffle = settings.shuffle;
    final repeatValues = domain.RepeatMode.values;
    _repeatMode =
        repeatValues[settings.repeatModeIndex.clamp(
          0,
          repeatValues.length - 1,
        )];
    await _audioService.setVolume(_volume);
    notifyListeners();
  }

  Future<void> _persistSettings() async {
    final storage = _storage;
    if (storage == null) return;
    final settings = storage.getSettings()
      ..volume = _volume
      ..shuffle = _shuffle
      ..repeatModeIndex = _repeatMode.index;
    await storage.saveSettings(settings);
  }

  // ===== GETTERS =====

  Song? get currentSong => _order.isEmpty ? null : _queue[_order[_position]];

  /// Índice de la canción actual dentro de `queue` (orden original), útil
  /// para resaltar la fila activa en HomeScreen/PlaylistScreen.
  int get currentIndex => _order.isEmpty ? -1 : _order[_position];

  List<Song> get queue => List.unmodifiable(_queue);

  domain.PlayerState get state => _state;
  Duration get currentPosition => _currentPosition;
  Duration get duration => _duration;
  bool get shuffle => _shuffle;
  domain.RepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;

  bool get isPlaying => _state == domain.PlayerState.playing;
  bool get hasNext =>
      _order.isNotEmpty &&
      (_position < _order.length - 1 || _repeatMode == domain.RepeatMode.all);
  bool get hasPrevious => _order.isNotEmpty && _position > 0;

  // ===== COLA =====

  /// [autoPlay] en `false` carga la canción (queda "lista") sin arrancar el
  /// audio — la usa la jam session para precargar en pausa la canción que
  /// va a sonar en el instante exacto de una cita de reproducción
  /// (`play_scheduled`), en vez de escucharla un instante localmente antes
  /// de pausarla.
  Future<void> loadQueue(
    List<Song> songs, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) return;

    _queue = songs;
    _order = List.generate(songs.length, (i) => i);
    _position = startIndex.clamp(0, songs.length - 1);
    if (_shuffle) _reshuffleKeepingCurrent();
    notifyListeners();

    await _playCurrent(autoPlay: autoPlay);
  }

  Future<void> playSongAt(int queueIndex) async {
    final orderPos = _order.indexOf(queueIndex);
    if (orderPos == -1) return;
    _position = orderPos;
    await _playCurrent();
  }

  Future<void> _playCurrent({bool autoPlay = true}) async {
    final song = currentSong;
    if (song == null) return;

    _errorMessage = null;
    _state = domain.PlayerState.loading;
    notifyListeners();

    try {
      final loadedDuration = await _audioService.loadSong(song.path);
      _duration = loadedDuration ?? song.durationObj;
      if (autoPlay) {
        await _audioService.play();
        await _storage?.addRecentlyPlayed(song.id);
      } else {
        _state = domain.PlayerState.paused;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'No se pudo reproducir "${song.title}": $e';
      _state = domain.PlayerState.stopped;
      notifyListeners();
    }
  }

  // ===== CONTROLES =====

  Future<void> play() => _audioService.play();

  Future<void> pause() => _audioService.pause();

  Future<void> resume() => _audioService.play();

  Future<void> stop() async {
    await _audioService.stop();
    _state = domain.PlayerState.stopped;
    notifyListeners();
  }

  Future<void> seek(Duration position) => _audioService.seek(position);

  Future<void> next({bool userInitiated = true}) async {
    if (_order.isEmpty) return;

    if (_position < _order.length - 1) {
      _position++;
    } else if (_repeatMode == domain.RepeatMode.all) {
      _position = 0;
    } else {
      return; // fin de la cola, sin repeat: no hacer nada
    }
    await _playCurrent();
  }

  /// Estilo Spotify: si llevamos más de 3s de la canción, "anterior" la
  /// reinicia en vez de saltar a la previa.
  Future<void> previous() async {
    if (_order.isEmpty) return;

    if (_currentPosition > const Duration(seconds: 3) || _position == 0) {
      await seek(Duration.zero);
      return;
    }
    _position--;
    await _playCurrent();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) {
      _reshuffleKeepingCurrent();
    } else {
      final currentSongIndex = _order.isEmpty ? 0 : _order[_position];
      _order = List.generate(_queue.length, (i) => i);
      _position = currentSongIndex;
    }
    notifyListeners();
    unawaited(_persistSettings());
  }

  void _reshuffleKeepingCurrent() {
    final currentSongIndex = _order.isEmpty ? 0 : _order[_position];
    final rest = [for (var i = 0; i < _queue.length; i++) i]
      ..remove(currentSongIndex);
    rest.shuffle();
    _order = [currentSongIndex, ...rest];
    _position = 0;
  }

  void toggleRepeat() {
    final values = domain.RepeatMode.values;
    _repeatMode = values[(_repeatMode.index + 1) % values.length];
    notifyListeners();
    unawaited(_persistSettings());
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioService.setVolume(_volume);
    notifyListeners();
    unawaited(_persistSettings());
  }

  // ===== EVENTOS DEL REPRODUCTOR =====

  void _listenToAudioService() {
    _stateSub = _audioService.playerStateStream.listen((state) {
      _state = state;
      notifyListeners();
    });

    _posSub = _audioService.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _durSub = _audioService.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
        final song = currentSong;
        if (song != null && song.duration == 0 && duration.inSeconds > 0) {
          onDurationResolved?.call(song, duration);
        }
      }
    });

    _completeSub = _audioService.onSongComplete.listen(
      (_) => _onSongComplete(),
    );
  }

  Future<void> _onSongComplete() async {
    if (_repeatMode == domain.RepeatMode.one) {
      await seek(Duration.zero);
      await play();
      return;
    }
    await next(userInitiated: false);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
