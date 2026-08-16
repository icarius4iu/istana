import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/models/playback_state.dart';

void main() {
  test('PlaybackState.initial arranca detenido, sin shuffle ni repeat', () {
    const state = PlaybackState.initial();

    expect(state.state, PlayerState.stopped);
    expect(state.currentPosition, Duration.zero);
    expect(state.duration, Duration.zero);
    expect(state.currentIndex, 0);
    expect(state.shuffle, isFalse);
    expect(state.repeatMode, RepeatMode.off);
  });

  test('copyWith solo pisa los campos indicados', () {
    const initial = PlaybackState.initial();
    final playing = initial.copyWith(state: PlayerState.playing, shuffle: true);

    expect(playing.state, PlayerState.playing);
    expect(playing.shuffle, isTrue);
    expect(playing.repeatMode, RepeatMode.off); // sin cambios
  });

  test(
    'RepeatMode tiene exactamente 3 valores en el orden que usa toggleRepeat',
    () {
      expect(RepeatMode.values, [
        RepeatMode.off,
        RepeatMode.one,
        RepeatMode.all,
      ]);
    },
  );
}
