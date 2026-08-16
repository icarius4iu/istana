import 'package:hive/hive.dart';

import '../models/playlist.dart';

part 'playlist_hive.g.dart';

@HiveType(typeId: 1)
class PlaylistHive extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> songIds;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? modifiedAt;

  @HiveField(5)
  String? description;

  PlaylistHive({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.modifiedAt,
    this.description,
  });

  factory PlaylistHive.fromPlaylist(Playlist playlist) => PlaylistHive(
    id: playlist.id,
    name: playlist.name,
    songIds: playlist.songIds,
    createdAt: playlist.createdAt,
    modifiedAt: playlist.modifiedAt,
    description: playlist.description,
  );

  Playlist toPlaylist() => Playlist(
    id: id,
    name: name,
    songIds: songIds,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    description: description,
  );
}
