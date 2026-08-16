import 'package:flutter/foundation.dart';

import '../hive_models/song_hive.dart';
import '../models/song.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../utils/extensions.dart';

/// Biblioteca local: la lista de [Song] disponibles, cacheada en Hive para
/// no tener que re-escanear el filesystem (o pedirle archivos al usuario de
/// nuevo, en Web) en cada arranque.
class LibraryProvider extends ChangeNotifier {
  final FileService _fileService;
  final StorageService _storage;

  List<Song> _songs = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  LibraryProvider({
    required FileService fileService,
    required StorageService storage,
  }) : _fileService = fileService,
       _storage = storage {
    _loadFromCache();
  }

  // ===== GETTERS =====

  List<Song> get songs => List.unmodifiable(_songs);

  List<Song> get filteredSongs {
    if (_searchQuery.trim().isEmpty) return songs;
    final query = _searchQuery.toLowerCase();
    return _songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(query) ||
              s.artist.toLowerCase().contains(query) ||
              s.album.toLowerCase().contains(query),
        )
        .toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _songs.isEmpty;
  DateTime? get lastScan => _storage.lastLibraryScan;

  void _loadFromCache() {
    _songs = _storage
        .getAllSongs()
        .map((h) => h.toSong())
        .toList()
        .sortedByArtist();
    notifyListeners();
  }

  // ===== ESCANEO (solo io: en Web `scanLocalLibrary` siempre da []) =====

  Future<void> scanLibrary({List<String>? folders}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetFolders =
          folders ?? await _fileService.suggestedLibraryFolders();
      final found = await _fileService.scanLocalLibrary(targetFolders);
      for (final song in found) {
        await _addOrUpdate(song);
      }
      await _storage.setLastLibraryScan(DateTime.now());
    } catch (e) {
      _errorMessage = 'Error escaneando la biblioteca: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ===== FILE PICKER (todas las plataformas) =====

  Future<Song?> pickAndAddSong() async {
    try {
      final song = await _fileService.pickSongFromDevice();
      if (song != null) await _addOrUpdate(song);
      return song;
    } catch (e) {
      _errorMessage = 'No se pudo agregar el archivo: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<Song>> pickAndAddMultipleSongs() async {
    try {
      final songs = await _fileService.pickMultipleSongsFromDevice();
      for (final song in songs) {
        await _addOrUpdate(song);
      }
      return songs;
    } catch (e) {
      _errorMessage = 'No se pudieron agregar los archivos: $e';
      notifyListeners();
      return const [];
    }
  }

  // ===== CRUD =====

  Future<void> _addOrUpdate(Song song) async {
    final index = _songs.indexWhere((s) => s.hash == song.hash);
    if (index != -1) return; // dedupe: mismo contenido ya en biblioteca

    _songs.add(song);
    await _storage.putSong(SongHive.fromSong(song));
    notifyListeners();
  }

  Future<void> removeSong(String songId) async {
    _songs.removeWhere((s) => s.id == songId);
    await _storage.deleteSong(songId);
    notifyListeners();
  }

  /// Se llama cuando el reproductor descubre la duración real de una
  /// canción que no la traía (típico en Web, donde no se puede leer del tag
  /// ID3 antes de reproducir — ver FileServiceImpl en `file_service_web.dart`).
  Future<void> updateDuration(Song song, Duration duration) async {
    final index = _songs.indexWhere((s) => s.id == song.id);
    if (index == -1 || song.duration == duration.inSeconds) return;

    final updated = _songs[index].copyWith(duration: duration.inSeconds);
    _songs[index] = updated;
    await _storage.putSong(SongHive.fromSong(updated));
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Song? getSongById(String id) {
    for (final song in _songs) {
      if (song.id == id) return song;
    }
    return null;
  }

  List<Song> getSongsByArtist(String artist) =>
      _songs.where((s) => s.artist == artist).toList();

  List<String> get artists =>
      _songs.map((s) => s.artist).toSet().toList()..sort();
}
