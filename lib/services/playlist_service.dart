import 'package:uuid/uuid.dart';

import '../hive_models/playlist_hive.dart';
import '../models/playlist.dart';
import 'storage_service.dart';

/// CRUD de playlists. Traduce entre el modelo de dominio [Playlist]
/// (inmutable, usado por la UI) y [PlaylistHive] (persistencia), delegando
/// el acceso a boxes en [StorageService] para no duplicar la apertura de
/// boxes de Hive en dos sitios distintos.
class PlaylistService {
  final StorageService _storage;
  static const _uuid = Uuid();

  PlaylistService({required StorageService storage}) : _storage = storage;

  Future<Playlist> createPlaylist(String name, {String? description}) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name.trim(),
      songIds: const [],
      createdAt: DateTime.now(),
      description: description,
    );
    await _storage.putPlaylist(PlaylistHive.fromPlaylist(playlist));
    return playlist;
  }

  Future<List<Playlist>> getAllPlaylists() async {
    return _storage.getAllPlaylists().map((h) => h.toPlaylist()).toList();
  }

  Future<Playlist?> getPlaylist(String id) async {
    final all = await getAllPlaylists();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Playlist> renamePlaylist(String id, String newName) async {
    final playlist = await _requirePlaylist(id);
    final updated = playlist.copyWith(
      name: newName.trim(),
      modifiedAt: DateTime.now(),
    );
    await _storage.putPlaylist(PlaylistHive.fromPlaylist(updated));
    return updated;
  }

  Future<Playlist> addSongToPlaylist(String playlistId, String songId) async {
    final playlist = await _requirePlaylist(playlistId);
    if (playlist.songIds.contains(songId)) return playlist;

    final updated = playlist.copyWith(
      songIds: [...playlist.songIds, songId],
      modifiedAt: DateTime.now(),
    );
    await _storage.putPlaylist(PlaylistHive.fromPlaylist(updated));
    return updated;
  }

  Future<Playlist> removeSongFromPlaylist(
    String playlistId,
    String songId,
  ) async {
    final playlist = await _requirePlaylist(playlistId);
    final updated = playlist.copyWith(
      songIds: playlist.songIds.where((id) => id != songId).toList(),
      modifiedAt: DateTime.now(),
    );
    await _storage.putPlaylist(PlaylistHive.fromPlaylist(updated));
    return updated;
  }

  Future<Playlist> reorderSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = await _requirePlaylist(playlistId);
    final songIds = [...playlist.songIds];
    final item = songIds.removeAt(oldIndex);
    songIds.insert(newIndex, item);

    final updated = playlist.copyWith(
      songIds: songIds,
      modifiedAt: DateTime.now(),
    );
    await _storage.putPlaylist(PlaylistHive.fromPlaylist(updated));
    return updated;
  }

  Future<void> deletePlaylist(String playlistId) =>
      _storage.deletePlaylist(playlistId);

  Future<Playlist> _requirePlaylist(String id) async {
    final playlist = await getPlaylist(id);
    if (playlist == null) {
      throw StateError('Playlist no encontrada: $id');
    }
    return playlist;
  }
}
