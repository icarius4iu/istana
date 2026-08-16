import '../models/song.dart';
import 'file_service.dart';

/// Fallback si el compilador no reconoce ni `dart.library.io` ni
/// `dart.library.js_interop` (no debería pasar en Flutter estándar; existe
/// para que la resolución condicional de imports siempre tenga un default).
class FileServiceImpl implements FileService {
  @override
  Future<void> init() async {}

  @override
  Future<List<Song>> scanLocalLibrary(List<String> folderPaths) async =>
      const [];

  @override
  Future<List<String>> suggestedLibraryFolders() async => const [];

  @override
  Future<Song?> pickSongFromDevice() async => null;

  @override
  Future<List<Song>> pickMultipleSongsFromDevice() async => const [];
}
