import 'package:hive/hive.dart';

import '../models/song.dart';

part 'song_hive.g.dart';

/// Modelo Hive para [Song]. Hive no puede persistir clases inmutables de
/// dominio directamente con anotaciones @HiveField, así que se mantiene un
/// modelo de persistencia separado y se convierte con [toSong]/[fromSong].
/// Esto evita que un cambio de esquema de storage obligue a tocar el modelo
/// de dominio (y viceversa).
@HiveType(typeId: 0)
class SongHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String path;

  @HiveField(2)
  String title;

  @HiveField(3)
  String artist;

  @HiveField(4)
  String album;

  @HiveField(5)
  int duration;

  @HiveField(6)
  String hash;

  @HiveField(7)
  int fileSize;

  @HiveField(8)
  DateTime dateAdded;

  SongHive({
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

  factory SongHive.fromSong(Song song) => SongHive(
    id: song.id,
    path: song.path,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
    hash: song.hash,
    fileSize: song.fileSize,
    dateAdded: song.dateAdded,
  );

  Song toSong() => Song(
    id: id,
    path: path,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    hash: hash,
    fileSize: fileSize,
    dateAdded: dateAdded,
  );
}
