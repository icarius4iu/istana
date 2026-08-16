import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../config/theme.dart';
import '../models/song.dart';
import '../utils/formatters.dart';
import 'album_art.dart';

/// Fila de canción en listas (biblioteca, playlist, resultados de
/// búsqueda). El swipe-to-delete/add-to-playlist usa `flutter_slidable`
/// (ya en pubspec) en vez de un `Dismissible` a mano, así se consigue el
/// patrón de acciones múltiples de un swipe sin reinventar gestos.
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isPlaying;
  final VoidCallback? onRemove;
  final VoidCallback? onAddToPlaylist;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isPlaying = false,
    this.onRemove,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: AlbumArt(song: song, size: 48),
      title: Text(
        song.title,
        style: TextStyle(
          color: isPlaying ? AppTheme.spotifyGreen : AppTheme.textPrimary,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: const TextStyle(color: AppTheme.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.equalizer,
                color: AppTheme.spotifyGreen,
                size: 18,
              ),
            ),
          Text(
            FormatUtils.formatDuration(song.durationObj),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
      onTap: onTap,
    );

    if (onRemove == null && onAddToPlaylist == null) return tile;

    return Slidable(
      key: ValueKey(song.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: onRemove != null && onAddToPlaylist != null ? 0.5 : 0.25,
        children: [
          if (onAddToPlaylist != null)
            SlidableAction(
              onPressed: (_) => onAddToPlaylist!(),
              backgroundColor: AppTheme.spotifyGreen,
              foregroundColor: Colors.black,
              icon: Icons.playlist_add,
              label: 'Playlist',
            ),
          if (onRemove != null)
            SlidableAction(
              onPressed: (_) => onRemove!(),
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Quitar',
            ),
        ],
      ),
      child: tile,
    );
  }
}
