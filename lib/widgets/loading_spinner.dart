import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../config/theme.dart';

/// Spinner central estándar, para pantallas completas cargando.
class LoadingSpinner extends StatelessWidget {
  final String? message;

  const LoadingSpinner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.spotifyGreen),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder shimmer para filas de canción mientras carga la biblioteca —
/// evita el salto brusco de "spinner -> lista completa".
class SongTileShimmer extends StatelessWidget {
  const SongTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.cardBg,
      highlightColor: AppTheme.elevatedBg,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Container(height: 14, width: 160, color: Colors.white),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(height: 12, width: 100, color: Colors.white),
        ),
      ),
    );
  }
}
