import '../config/constants.dart';
import '../models/song.dart';

// Selecciona la implementación real según la plataforma en tiempo de
// compilación (no en runtime): `dart.library.io` es true en Android, iOS y
// Desktop; `dart.library.js_interop` es true en Web (JS y WASM). Así el
// código que usa `dart:io` nunca se incluye en el bundle Web, donde ni
// siquiera es válido importarlo.
import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_io.dart'
    if (dart.library.js_interop) 'file_service_web.dart'
    as impl;

/// Contrato común para "conseguir canciones reproducibles" en cualquier
/// plataforma. La implementación difiere mucho entre plataformas (ver
/// `file_service_io.dart` vs `file_service_web.dart`), pero los providers y
/// screens solo dependen de esta interfaz.
abstract class FileService {
  static const List<String> supportedFormats = AppConstants.supportedFormats;

  factory FileService() = impl.FileServiceImpl;

  /// Inicialización específica de plataforma (en io: arranca el runtime
  /// Rust/FFI de `metadata_god`; en Web es un no-op). Llamar una vez en
  /// `main()` antes de usar el resto de los métodos.
  Future<void> init();

  /// Recorre carpetas del filesystem en busca de audio. En Web devuelve
  /// siempre `[]` (no hay filesystem accesible) — ver [Env.canScanFilesystem].
  Future<List<Song>> scanLocalLibrary(List<String> folderPaths);

  /// Carpetas por defecto donde buscar música (Música, Descargas, etc.),
  /// ya resueltas para la plataforma actual. `[]` en Web.
  Future<List<String>> suggestedLibraryFolders();

  /// Abre el selector nativo de archivos y devuelve una única canción.
  Future<Song?> pickSongFromDevice();

  /// Abre el selector nativo de archivos en modo múltiple.
  Future<List<Song>> pickMultipleSongsFromDevice();
}
