import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/playlist.dart';
import '../utils/formatters.dart';

class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const PlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.elevatedBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.queue_music, color: AppTheme.textSecondary),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        FormatUtils.songCountLabel(playlist.songCount),
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      trailing: onDelete == null
          ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
          : IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.textSecondary,
              ),
              onPressed: onDelete,
              tooltip: 'Eliminar playlist',
            ),
      onTap: onTap,
    );
  }
}
