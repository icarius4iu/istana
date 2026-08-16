import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/session_models.dart';
import '../../utils/formatters.dart';

/// Fila de la cola compartida. 100% presentacional (callbacks, sin
/// providers adentro), mismo patrón que `SongTile`. [ownedLocally] marca si
/// el dispositivo ya tiene el archivo (por hash); si no y [isDownloading]
/// es `true`, se está bajando de otro miembro por P2P ahora mismo (ver
/// `SessionProvider.isDownloading`) — si no, todavía no se pidió.
class QueueEntryTile extends StatelessWidget {
  final QueueEntry entry;
  final bool ownedLocally;
  final bool isDownloading;
  final VoidCallback? onRemove;

  const QueueEntryTile({
    super.key,
    required this.entry,
    required this.ownedLocally,
    this.isDownloading = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isDownloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.spotifyGreen,
              ),
            )
          : Icon(
              _statusIcon,
              color: entry.status == QueueItemStatus.playing
                  ? AppTheme.spotifyGreen
                  : AppTheme.textSecondary,
            ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.artist} · ${FormatUtils.formatDuration(Duration(seconds: entry.durationSeconds))}'
        '${_subtitleSuffix()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _subtitleColor()),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRemove,
            ),
    );
  }

  String _subtitleSuffix() {
    if (ownedLocally) return '';
    return isDownloading
        ? ' · descargando de otro dispositivo…'
        : ' · no está en tu biblioteca';
  }

  Color _subtitleColor() {
    if (ownedLocally) return AppTheme.textSecondary;
    return isDownloading ? AppTheme.spotifyGreen : AppTheme.error;
  }

  IconData get _statusIcon {
    switch (entry.status) {
      case QueueItemStatus.playing:
        return Icons.graphic_eq;
      case QueueItemStatus.downloading:
        return Icons.downloading;
      case QueueItemStatus.completed:
        return Icons.check_circle_outline;
      case QueueItemStatus.pending:
        return Icons.schedule;
    }
  }
}
