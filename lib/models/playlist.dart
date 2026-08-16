import 'package:equatable/equatable.dart';

/// Una playlist del usuario: nombre + lista ordenada de referencias a
/// [Song.id]. No incluye los objetos Song completos para evitar duplicar
/// datos — la resolución a Song vive en PlaylistProvider/LibraryProvider.
class Playlist extends Equatable {
  final String id; // UUID
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? description;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.modifiedAt,
    this.description,
  });

  int get songCount => songIds.length;

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? description,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [id, name, songIds];
}
