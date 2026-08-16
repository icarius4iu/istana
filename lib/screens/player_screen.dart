import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/player_provider.dart';
import '../utils/extensions.dart';
import '../widgets/album_art.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/queue_view.dart';
import '../widgets/volume_control.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproduciendo ahora'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: 'Cola',
            onPressed: () => _showQueue(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          if (song == null) {
            return const Center(
              child: Text(
                'No hay canción seleccionada',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final artSize = isWide ? 320.0 : constraints.maxWidth * 0.75;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AlbumArt(
                            song: song,
                            size: artSize,
                            borderRadius: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      ProgressBar(
                        currentPosition: player.currentPosition,
                        duration: player.duration,
                        onSeek: player.seek,
                      ),
                      const SizedBox(height: 16),
                      PlaybackControls(
                        playerState: player.state,
                        repeatMode: player.repeatMode,
                        shuffle: player.shuffle,
                        hasNext: player.hasNext,
                        hasPrevious: player.hasPrevious,
                        onPlayPause: () =>
                            player.isPlaying ? player.pause() : player.resume(),
                        onNext: player.next,
                        onPrevious: player.previous,
                        onShuffle: player.toggleShuffle,
                        onRepeat: player.toggleRepeat,
                      ),
                      const SizedBox(height: 24),
                      VolumeControl(
                        volume: player.volume,
                        onVolumeChanged: player.setVolume,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerProvider>();
    if (player.queue.isEmpty) {
      context.showSnack('La cola está vacía');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: player,
        child: Consumer<PlayerProvider>(
          builder: (context, p, _) => QueueView(
            queue: p.queue,
            currentIndex: p.currentIndex,
            onSongSelected: (index) {
              p.playSongAt(index);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
