import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/playback_state.dart';
import '../models/song.dart';
import 'album_art.dart';

/// Barra inferior persistente con la canción actual. Incluye una franja
/// delgada de progreso arriba (estilo apps de streaming) para dar contexto
/// sin ocupar el espacio de un ProgressBar completo.
class MiniPlayer extends StatelessWidget {
  final Song song;
  final PlayerState state;
  final double progress; // 0.0 - 1.0
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.state,
    required this.onTap,
    required this.onPlayPause,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppConstants.miniPlayerHeight,
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: AppTheme.divider,
              valueColor: const AlwaysStoppedAnimation(AppTheme.spotifyGreen),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    AlbumArt(song: song, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: state == PlayerState.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              state == PlayerState.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                      color: AppTheme.textPrimary,
                      onPressed: state == PlayerState.loading
                          ? null
                          : onPlayPause,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
