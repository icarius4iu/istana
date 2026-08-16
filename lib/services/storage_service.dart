import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../hive_models/app_settings.dart';
import '../hive_models/playlist_hive.dart';
import '../hive_models/song_hive.dart';

/// Punto único de acceso a la persistencia local.
///
/// - Hive: estado de dominio estructurado (canciones, playlists, settings).
/// - SharedPreferences: flags simples de infraestructura.
///
/// `init()` debe llamarse una vez en `main()` antes de `runApp`, y antes de
/// construir cualquier provider (todos dependen de que las boxes ya estén
/// abiertas).
class StorageService {
  late final Box<SongHive> _songsBox;
  late final Box<PlaylistHive> _playlistsBox;
  late final Box<AppSettings> _settingsBox;
  late final Box<String> _recentlyPlayedBox;
  late final SharedPreferences _prefs;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PlaylistHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    _songsBox = await Hive.openBox<SongHive>(AppConstants.songsBox);
    _playlistsBox = await Hive.openBox<PlaylistHive>(AppConstants.playlistsBox);
    _settingsBox = await Hive.openBox<AppSettings>(AppConstants.settingsBox);
    _recentlyPlayedBox = await Hive.openBox<String>(
      AppConstants.recentlyPlayedBox,
    );
    _prefs = await SharedPreferences.getInstance();

    _initialized = true;
  }

  // ===== SONGS =====

  Box<SongHive> get songsBox => _songsBox;

  Future<void> putSong(SongHive song) => _songsBox.put(song.id, song);

  Future<void> putSongs(Iterable<SongHive> songs) =>
      _songsBox.putAll({for (final s in songs) s.id: s});

  Future<void> deleteSong(String id) => _songsBox.delete(id);

  List<SongHive> getAllSongs() => _songsBox.values.toList();

  // ===== PLAYLISTS =====

  Box<PlaylistHive> get playlistsBox => _playlistsBox;

  Future<void> putPlaylist(PlaylistHive playlist) =>
      _playlistsBox.put(playlist.id, playlist);

  Future<void> deletePlaylist(String id) => _playlistsBox.delete(id);

  List<PlaylistHive> getAllPlaylists() => _playlistsBox.values.toList();

  // ===== SETTINGS (single instance, key fija) =====

  static const String _settingsKey = 'app_settings';

  AppSettings getSettings() =>
      _settingsBox.get(_settingsKey) ?? AppSettings.defaults();

  Future<void> saveSettings(AppSettings settings) =>
      _settingsBox.put(_settingsKey, settings);

  // ===== RECENTLY PLAYED =====

  List<String> getRecentlyPlayed() => _recentlyPlayedBox.values.toList();

  Future<void> addRecentlyPlayed(String songId) async {
    final current = getRecentlyPlayed()..remove(songId);
    current.insert(0, songId);
    final trimmed = current.take(AppConstants.maxRecentlyPlayed).toList();
    await _recentlyPlayedBox.clear();
    await _recentlyPlayedBox.addAll(trimmed);
  }

  // ===== SHARED PREFERENCES =====

  bool get onboardingSeen =>
      _prefs.getBool(AppConstants.prefOnboardingSeen) ?? false;

  Future<void> setOnboardingSeen(bool value) =>
      _prefs.setBool(AppConstants.prefOnboardingSeen, value);

  DateTime? get lastLibraryScan {
    final iso = _prefs.getString(AppConstants.prefLastLibraryScanIso);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> setLastLibraryScan(DateTime time) => _prefs.setString(
    AppConstants.prefLastLibraryScanIso,
    time.toIso8601String(),
  );

  // ===== SESIÓN DE JAM (auth + servidor) =====
  //
  // Flags de infraestructura simples (no ameritan un modelo Hive): el JWT y
  // la identidad local del usuario logueado, y la URL del backend que el
  // usuario configuró (ver Env.defaultApiBaseUrl para el valor sugerido).

  String? get authToken => _prefs.getString(AppConstants.prefAuthToken);
  String? get authUserId => _prefs.getString(AppConstants.prefAuthUserId);
  String? get authUsername => _prefs.getString(AppConstants.prefAuthUsername);

  Future<void> saveAuthSession({
    required String token,
    required String userId,
    required String username,
  }) async {
    await _prefs.setString(AppConstants.prefAuthToken, token);
    await _prefs.setString(AppConstants.prefAuthUserId, userId);
    await _prefs.setString(AppConstants.prefAuthUsername, username);
  }

  Future<void> clearAuthSession() async {
    await _prefs.remove(AppConstants.prefAuthToken);
    await _prefs.remove(AppConstants.prefAuthUserId);
    await _prefs.remove(AppConstants.prefAuthUsername);
  }

  String? get serverBaseUrl => _prefs.getString(AppConstants.prefServerBaseUrl);

  Future<void> setServerBaseUrl(String url) =>
      _prefs.setString(AppConstants.prefServerBaseUrl, url);

  Future<void> dispose() async {
    await _songsBox.close();
    await _playlistsBox.close();
    await _settingsBox.close();
    await _recentlyPlayedBox.close();
  }
}
