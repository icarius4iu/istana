import 'package:equatable/equatable.dart';

/// Una canción de la biblioteca local.
///
/// [path] es la fuente reproducible de audio:
/// - En Android/iOS/Desktop es una ruta absoluta del filesystem
///   (`/storage/emulated/0/Music/song.mp3`).
/// - En Web es una blob URL (`blob:http://localhost/...`) creada a partir de
///   los bytes que el usuario eligió con el file picker, porque el navegador
///   no expone rutas de archivo reales. Ver [AudioService.resolveUri] en
///   `audio_service.dart`.
class Song extends Equatable {
  final String id; // SHA-256 hash (o UUID en Web si no se pudo hashear)
  final String path;
  final String title;
  final String artist;
  final String album;
  final int duration; // segundos
  final String hash; // SHA-256 del contenido, usado para dedupe y caché
  final int fileSize; // bytes
  final DateTime dateAdded;

  const Song({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.hash,
    required this.fileSize,
    required this.dateAdded,
  });

  Duration get durationObj => Duration(seconds: duration);

  Song copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? hash,
    int? fileSize,
    DateTime? dateAdded,
  }) {
    return Song(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      hash: hash ?? this.hash,
      fileSize: fileSize ?? this.fileSize,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration,
    'hash': hash,
    'fileSize': fileSize,
    'dateAdded': dateAdded.toIso8601String(),
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    path: json['path'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    duration: json['duration'] as int,
    hash: json['hash'] as String,
    fileSize: json['fileSize'] as int,
    dateAdded: DateTime.parse(json['dateAdded'] as String),
  );

  @override
  List<Object?> get props => [id, hash, path];
}
