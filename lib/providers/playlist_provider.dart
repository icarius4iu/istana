import 'package:flutter/foundation.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/playlist_service.dart';
import 'library_provider.dart';

/// Gestión de playlists del usuario. Resuelve `Playlist.songIds` a objetos
/// [Song] completos consultando [LibraryProvider], en vez de guardar copias
/// de Song dentro de la playlist (una sola fuente de verdad para los datos
/// de la canción).
class PlaylistProvider extends ChangeNotifier {
  final PlaylistService _playlistService;
  final LibraryProvider _libraryProvider;

  List<Playlist> _playlists = [];
  String? _selectedPlaylistId;
  bool _isLoading = false;
  String? _errorMessage;

  PlaylistProvider({
    required PlaylistService playlistService,
    required LibraryProvider libraryProvider,
  }) : _playlistService = playlistService,
       _libraryProvider = libraryProvider {
    loadPlaylists();
  }

  // ===== GETTERS =====

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Playlist? get selectedPlaylist {
    if (_selectedPlaylistId == null) return null;
    for (final p in _playlists) {
      if (p.id == _selectedPlaylistId) return p;
    }
    return null;
  }

  /// Canciones de una playlist, resueltas y en el orden de `songIds`.
  /// Ids que ya no existen en la biblioteca (canción borrada) se omiten.
  List<Song> songsInPlaylist(Playlist playlist) {
    final songs = <Song>[];
    for (final id in playlist.songIds) {
      final song = _libraryProvider.getSongById(id);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  // ===== CRUD =====

  Future<void> loadPlaylists() async {
    _isLoading = true;
    notifyListeners();
    try {
      _playlists = await _playlistService.getAllPlaylists();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error cargando playlists: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createPlaylist(String name, {String? description}) async {
    final playlist = await _playlistService.createPlaylist(
      name,
      description: description,
    );
    _playlists = [..._playlists, playlist];
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final updated = await _playlistService.renamePlaylist(playlistId, newName);
    _replace(updated);
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final updated = await _playlistService.addSongToPlaylist(
      playlistId,
      songId,
    );
    _replace(updated);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final updated = await _playlistService.removeSongFromPlaylist(
      playlistId,
      songId,
    );
    _replace(updated);
  }

  Future<void> reorderSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final updated = await _playlistService.reorderSong(
      playlistId,
      oldIndex,
      newIndex,
    );
    _replace(updated);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _playlistService.deletePlaylist(playlistId);
    _playlists = _playlists.where((p) => p.id != playlistId).toList();
    if (_selectedPlaylistId == playlistId) _selectedPlaylistId = null;
    notifyListeners();
  }

  void selectPlaylist(String playlistId) {
    _selectedPlaylistId = playlistId;
    notifyListeners();
  }

  void _replace(Playlist updated) {
    _playlists = [for (final p in _playlists) p.id == updated.id ? updated : p];
    notifyListeners();
  }
}
