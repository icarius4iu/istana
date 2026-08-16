import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/song.dart';
import 'album_art.dart';

/// Lista de "a continuación" — se abre como bottom sheet desde PlayerScreen.
class QueueView extends StatelessWidget {
  final List<Song> queue;
  final int currentIndex;
  final ValueChanged<int> onSongSelected;

  const QueueView({
    super.key,
    required this.queue,
    required this.currentIndex,
    required this.onSongSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'A continuación',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = index == currentIndex;
                    return ListTile(
                      leading: AlbumArt(song: song, size: 40),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? AppTheme.spotifyGreen
                              : AppTheme.textPrimary,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      trailing: isCurrent
                          ? const Icon(
                              Icons.equalizer,
                              color: AppTheme.spotifyGreen,
                              size: 18,
                            )
                          : null,
                      onTap: () => onSongSelected(index),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
