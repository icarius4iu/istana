import 'package:flutter/foundation.dart';

/// Capacidades disponibles según la plataforma.
///
/// El mismo código Dart corre en las 6 plataformas, pero no todas exponen
/// las mismas APIs del sistema operativo:
/// - Web no tiene `dart:io` (no filesystem, no rutas absolutas): no se puede
///   escanear una carpeta de música, solo se puede pedir al usuario que
///   elija archivos con el file picker (y trabajar con sus bytes).
/// - `metadata_god` (lectura de tags ID3 vía Rust/FFI) no tiene build para
///   web; en web se cae a metadata derivada del nombre de archivo.
class Env {
  Env._();

  /// true en Web (sin dart:io, sin filesystem real).
  static bool get isWeb => kIsWeb;

  /// true en Android/iOS.
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// true en Windows/macOS/Linux.
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Se puede escanear directorios del filesystem en busca de MP3s.
  static bool get canScanFilesystem => !kIsWeb;

  /// Se puede leer metadata ID3 real (título/artista/álbum/duración) del
  /// archivo, en vez de derivarla solo del nombre.
  static bool get canReadId3Tags => !kIsWeb;

  /// Nombre corto de la plataforma actual, para logs/telemetría.
  static String get platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// URL sugerida del backend cuando el usuario todavía no configuró una
  /// propia (ver `StorageService.serverBaseUrl` — SessionProvider guarda la
  /// que el usuario tipeó, porque en Codespaces cambia por sesión y en
  /// dispositivos físicos nunca es `localhost`). Sirve tal cual en
  /// desktop/emulador contra un backend corriendo en la misma máquina.
  static const String defaultApiBaseUrl = 'http://localhost:8080';
}
