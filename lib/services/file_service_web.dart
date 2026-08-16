import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../models/song.dart';
import 'file_service.dart';

/// Implementación Web: el navegador no expone el filesystem del SO (no
/// `dart:io`, no rutas absolutas), así que no hay "escanear biblioteca". El
/// único punto de entrada es el file picker.
///
/// `file_picker` en Web ya arma internamente una `blob:` URL por archivo
/// elegido (`PlatformFile.uri`, vía `URL.createObjectURL`) — es lo que se
/// guarda en `Song.path` y lo que `AudioService` le pasa a just_audio_web
/// para reproducir. No hace falta construir esa URL a mano.
///
/// La metadata (título/artista/álbum) no se puede leer de tags ID3 en Web
/// (`metadata_god` es un plugin FFI que no compila a Web), así que se
/// deriva del nombre de archivo; ver [Env.canReadId3Tags].
class FileServiceImpl implements FileService {
  @override
  Future<void> init() async {}

  @override
  Future<List<Song>> scanLocalLibrary(List<String> folderPaths) async =>
      const [];

  @override
  Future<List<String>> suggestedLibraryFolders() async => const [];

  @override
  Future<Song?> pickSongFromDevice() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return null;
    return _songFromPlatformFile(file);
  }

  @override
  Future<List<Song>> pickMultipleSongsFromDevice() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final songs = <Song>[];
    for (final file in files) {
      songs.add(await _songFromPlatformFile(file));
    }
    return songs;
  }

  Future<Song> _songFromPlatformFile(PlatformFile file) async {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    return Song(
      id: hash,
      path: file.uri.toString(),
      title: title.trim().isEmpty ? 'Pista sin título' : title,
      artist: 'Artista desconocido',
      album: 'Álbum desconocido',
      // La duración real se completa al cargar el audio en el reproductor
      // (ver PlayerProvider.onDurationResolved), porque en Web no hay forma
      // de leerla de los tags sin decodificar el archivo primero.
      duration: 0,
      hash: hash,
      fileSize: bytes.length,
      dateAdded: DateTime.now(),
    );
  }
}
