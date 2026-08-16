import 'package:equatable/equatable.dart';

/// Estado propio de reproducción de la app (independiente del enum interno
/// de just_audio, para no acoplar toda la UI a una librería de terceros).
enum PlayerState { playing, paused, stopped, loading }

enum RepeatMode { off, one, all }

class PlaybackState extends Equatable {
  final PlayerState state;
  final Duration currentPosition;
  final Duration duration;
  final int currentIndex;
  final bool shuffle;
  final RepeatMode repeatMode;

  const PlaybackState({
    required this.state,
    required this.currentPosition,
    required this.duration,
    required this.currentIndex,
    required this.shuffle,
    required this.repeatMode,
  });

  const PlaybackState.initial()
    : state = PlayerState.stopped,
      currentPosition = Duration.zero,
      duration = Duration.zero,
      currentIndex = 0,
      shuffle = false,
      repeatMode = RepeatMode.off;

  PlaybackState copyWith({
    PlayerState? state,
    Duration? currentPosition,
    Duration? duration,
    int? currentIndex,
    bool? shuffle,
    RepeatMode? repeatMode,
  }) {
    return PlaybackState(
      state: state ?? this.state,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  @override
  List<Object?> get props => [
    state,
    currentPosition,
    duration,
    currentIndex,
    shuffle,
    repeatMode,
  ];
}
