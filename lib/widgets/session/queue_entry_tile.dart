import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/session_models.dart';
import '../../utils/formatters.dart';

/// Fila de la cola compartida. 100% presentacional (callbacks, sin
/// providers adentro), mismo patrón que `SongTile`. [ownedLocally] marca si
/// el dispositivo ya tiene el archivo (por hash) — si no, todavía no se
/// puede reproducir acá (v1: sin transferencia P2P).
class QueueEntryTile extends StatelessWidget {
  final QueueEntry entry;
  final bool ownedLocally;
  final VoidCallback? onRemove;

  const QueueEntryTile({
    super.key,
    required this.entry,
    required this.ownedLocally,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _statusIcon,
        color: entry.status == QueueItemStatus.playing
            ? AppTheme.spotifyGreen
            : AppTheme.textSecondary,
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.artist} · ${FormatUtils.formatDuration(Duration(seconds: entry.durationSeconds))}'
        '${ownedLocally ? '' : ' · no está en tu biblioteca'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ownedLocally ? AppTheme.textSecondary : AppTheme.error,
        ),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRemove,
            ),
    );
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
