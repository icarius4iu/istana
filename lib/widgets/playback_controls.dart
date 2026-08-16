// `RepeatMode` existe tanto acá (modo de repetición de la cola) como en
// `package:flutter/material.dart` (animaciones que se repiten) — se oculta
// la de Flutter porque en este widget la nuestra es la relevante.
import 'package:flutter/material.dart' hide RepeatMode;

import '../config/theme.dart';
import '../models/playback_state.dart';

class PlaybackControls extends StatelessWidget {
  final PlayerState playerState;
  final RepeatMode repeatMode;
  final bool shuffle;
  final bool hasNext;
  final bool hasPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const PlaybackControls({
    super.key,
    required this.playerState,
    required this.repeatMode,
    required this.shuffle,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    this.hasNext = true,
    this.hasPrevious = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = playerState == PlayerState.loading;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: shuffle ? AppTheme.spotifyGreen : AppTheme.textSecondary,
              ),
              onPressed: onShuffle,
              tooltip: 'Aleatorio',
            ),
            IconButton(
              icon: Icon(
                repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                color: repeatMode != RepeatMode.off
                    ? AppTheme.spotifyGreen
                    : AppTheme.textSecondary,
              ),
              onPressed: onRepeat,
              tooltip: 'Repetir',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: 36,
              color: hasPrevious
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              onPressed: onPrevious,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.spotifyGreen,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        playerState == PlayerState.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      iconSize: 32,
                      color: Colors.black,
                      onPressed: onPlayPause,
                    ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: 36,
              color: hasNext ? AppTheme.textPrimary : AppTheme.textSecondary,
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}
