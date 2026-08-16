/// Constantes globales: nombres de storage, tamaños, timeouts y formatos
/// soportados. Centralizado para no tener "magic strings/numbers" repartidos
/// por servicios, providers y widgets.
class AppConstants {
  AppConstants._();

  // ===== APP =====
  static const String appName = 'MP3 Player';

  // ===== FORMATOS SOPORTADOS =====
  static const List<String> supportedFormats = [
    'mp3',
    'wav',
    'flac',
    'm4a',
    'aac',
    'ogg',
  ];

  // ===== HIVE BOXES =====
  static const String songsBox = 'songs_box';
  static const String playlistsBox = 'playlists_box';
  static const String settingsBox = 'settings_box';
  static const String recentlyPlayedBox = 'recently_played_box';

  // ===== SHARED PREFERENCES KEYS =====
  // Todo lo que es "estado de dominio" (volumen, shuffle, repeat, carpetas
  // de biblioteca) vive en el box `settingsBox` de Hive (ver AppSettings).
  // SharedPreferences queda solo para flags simples de infraestructura que
  // no ameritan un modelo Hive.
  static const String prefOnboardingSeen = 'pref_onboarding_seen';
  static const String prefLastLibraryScanIso = 'pref_last_library_scan_iso';

  // ===== LÍMITES =====
  static const int maxRecentlyPlayed = 50;
  static const int maxSearchResults = 200;

  // ===== TIMEOUTS =====
  static const Duration seekDebounce = Duration(milliseconds: 150);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // ===== TAMAÑOS UI =====
  static const double miniPlayerHeight = 64;
  static const double albumArtCornerRadius = 8;
  static const double songTileLeadingSize = 50;

  // ===== BREAKPOINTS RESPONSIVE =====
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
}
