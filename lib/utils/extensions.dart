import 'package:flutter/material.dart';

import '../models/song.dart';

/// Extensiones puntuales que evitan boilerplate repetido en widgets/screens.
extension SongListX on List<Song> {
  /// Índice de una canción por id, o -1 si no está.
  int indexOfId(String songId) => indexWhere((s) => s.id == songId);

  List<Song> sortedByArtist() => [...this]
    ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));

  List<Song> sortedByTitle() => [...this]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  List<Song> sortedByDateAdded() =>
      [...this]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
}

extension BuildContextX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);

  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

extension StringX on String {
  String get orUnknownArtist => trim().isEmpty ? 'Artista desconocido' : this;
  String get orUnknownAlbum => trim().isEmpty ? 'Álbum desconocido' : this;

  /// Recorta a [max] caracteres añadiendo "…" (para títulos muy largos en
  /// listas de ancho fijo, como fallback cuando no hay overflow ellipsis).
  String truncate(int max) => length <= max ? this : '${substring(0, max)}…';
}
