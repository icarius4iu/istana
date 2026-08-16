import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/song.dart';

/// Portada de una canción.
///
/// El MVP no extrae ni cachea la imagen embebida en el MP3 (aunque
/// `metadata_god` puede leerla vía `Metadata.picture`): guardar esos bytes
/// en `Song`/Hive por cada canción es una funcionalidad completa en sí
/// misma (caché en disco, invalidación, tamaño de la box). Por ahora se usa
/// un placeholder con gradiente + ícono, determinista por canción (mismo
/// hash -> mismo color) para que la biblioteca no se vea toda igual.
class AlbumArt extends StatelessWidget {
  final Song? song;
  final double size;
  final double borderRadius;

  const AlbumArt({
    super.key,
    required this.song,
    this.size = 64,
    this.borderRadius = AppConstants.albumArtCornerRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(song?.hash ?? song?.title ?? '');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: size * 0.5,
        ),
      ),
    );
  }

  List<Color> _gradientFor(String seed) {
    const palettes = [
      [Color(0xFF1DB954), Color(0xFF0D3B22)],
      [Color(0xFF8E44AD), Color(0xFF2C0A3E)],
      [Color(0xFFE91429), Color(0xFF3E0A10)],
      [Color(0xFF1E88E5), Color(0xFF0A2A4A)],
      [Color(0xFFF39C12), Color(0xFF3E2A0A)],
      [Color(0xFF16A085), Color(0xFF0A3E36)],
    ];
    final index = seed.isEmpty
        ? 0
        : seed.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length;
    return palettes[index];
  }
}
