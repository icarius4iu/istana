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

  // Sesión de jam: token JWT + identidad local (ver AuthService) y la URL
  // del backend (configurable: en Codespaces cambia por sesión, así que no
  // puede ser una constante — ver Env.defaultApiBaseUrl para el fallback).
  static const String prefAuthToken = 'pref_auth_token';
  static const String prefAuthUserId = 'pref_auth_user_id';
  static const String prefAuthUsername = 'pref_auth_username';
  static const String prefServerBaseUrl = 'pref_server_base_url';

  // ===== LÍMITES =====
  static const int maxRecentlyPlayed = 50;
  static const int maxSearchResults = 200;

  // ===== TIMEOUTS =====
  static const Duration seekDebounce = Duration(milliseconds: 150);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // ===== JAM SESSION =====
  // Cadencia esperada por el backend: SessionService.DEFAULT_HEARTBEAT_TIMEOUT
  // expulsa a un miembro tras 3 latidos perdidos (30s), así que 5s da margen.
  static const Duration sessionHeartbeatInterval = Duration(seconds: 5);
  // La cola compartida no tiene push por WebSocket (solo REST) — hay que
  // pollearla. Ver docs/mapa de integración: "sync por polling de GET".
  static const Duration sessionQueuePollInterval = Duration(seconds: 8);
  static const int clockSyncMaxAttempts = 5;
  static const Duration clockSyncRoundTimeout = Duration(seconds: 3);
  // SyncService.DEFAULT_DRIFT_TOLERANCE_MS en el backend: corregir por menos
  // produce saltos audibles perceptibles.
  static const int driftToleranceMs = 250;

  // ===== TAMAÑOS UI =====
  static const double miniPlayerHeight = 64;
  static const double albumArtCornerRadius = 8;
  static const double songTileLeadingSize = 50;

  // ===== BREAKPOINTS RESPONSIVE =====
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
}
