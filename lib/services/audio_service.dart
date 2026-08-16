import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../models/playback_state.dart' as domain;

/// Envuelve `just_audio` y traduce su modelo de estado al propio de la app
/// ([domain.PlayerState]), para que providers/widgets nunca dependan
/// directamente del paquete de terceros.
///
/// Reproduce en cualquier plataforma a partir de un [Uri] — ver
/// [resolveUri] para cómo se arma ese Uri a partir de `Song.path`, que en
/// io es una ruta de filesystem y en Web una `data:` URI.
class AudioService {
  final ja.AudioPlayer _player;

  AudioService({ja.AudioPlayer? player})
    : _player = player ?? ja.AudioPlayer() {
    _configureAudioSession();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // audio_session no tiene una implementación completa en todas las
      // plataformas desktop/web; fallar en silencio no debe romper la
      // reproducción, que sigue funcionando sin la sesión configurada.
    }
  }

  /// Convierte lo guardado en `Song.path` a un [Uri] reproducible por
  /// just_audio en cualquier plataforma:
  /// - Si ya trae esquema real (`data:`, `blob:`, `http(s):`, `file:`) se usa
  ///   tal cual.
  /// - Si es una ruta absoluta de filesystem (Android/iOS/Desktop) se
  ///   envuelve con `Uri.file`. Ojo: en Windows una ruta como `C:\...`
  ///   también "parsea" como si tuviera esquema de 1 letra ("c"), por eso se
  ///   exige `scheme.length > 1` para no confundirlo con un URI real.
  static Uri resolveUri(String source) {
    final parsed = Uri.tryParse(source);
    if (parsed != null && parsed.hasScheme && parsed.scheme.length > 1) {
      return parsed;
    }
    return Uri.file(source);
  }

  /// Carga una canción y devuelve su duración si just_audio pudo calcularla
  /// de entrada (no siempre: en Web a veces llega null hasta que hay más
  /// buffer, ver [durationStream]).
  Future<Duration?> loadSong(String source) async {
    return _player.setAudioSource(ja.AudioSource.uri(resolveUri(source)));
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ===== STREAMS =====

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Stream<domain.PlayerState> get playerStateStream =>
      _player.playerStateStream.map(_mapState);

  /// Emite una vez cuando la canción actual terminó de sonar sola (no por
  /// `stop()` manual), para que el provider dispare "siguiente"/"repetir".
  Stream<void> get onSongComplete => _player.processingStateStream
      .where((state) => state == ja.ProcessingState.completed)
      .map((_) {});

  // ===== GETTERS SINCRÓNICOS =====

  Duration get currentPosition => _player.position;

  Duration? get duration => _player.duration;

  bool get isPlaying => _player.playing;

  double get volume => _player.volume;

  domain.PlayerState _mapState(ja.PlayerState state) {
    switch (state.processingState) {
      case ja.ProcessingState.idle:
        return domain.PlayerState.stopped;
      case ja.ProcessingState.loading:
      case ja.ProcessingState.buffering:
        return domain.PlayerState.loading;
      case ja.ProcessingState.ready:
        return state.playing
            ? domain.PlayerState.playing
            : domain.PlayerState.paused;
      case ja.ProcessingState.completed:
        return domain.PlayerState.stopped;
    }
  }

  Future<void> dispose() => _player.dispose();
}
