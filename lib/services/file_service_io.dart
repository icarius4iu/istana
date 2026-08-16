import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';
import '../models/song.dart';
import 'file_service.dart';

/// Implementación Android / iOS / Desktop: filesystem real vía `dart:io`,
/// tags ID3 reales vía `metadata_god` (FFI/Rust).
class FileServiceImpl implements FileService {
  bool _metadataGodReady = false;

  @override
  Future<void> init() async {
    try {
      await MetadataGod.initialize();
      _metadataGodReady = true;
    } catch (e) {
      // Falla en plataformas donde la librería nativa no se pudo cargar
      // (build mal empaquetado, etc.). No debe tumbar el arranque de la
      // app: sin esto, `_parseSong` cae al título derivado del nombre de
      // archivo en vez de tags ID3 reales.
      _metadataGodReady = false;
    }
  }

  @override
  Future<List<Song>> scanLocalLibrary(List<String> folderPaths) async {
    final songs = <Song>[];
    final seenHashes = <String>{};

    for (final folderPath in folderPaths) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(recursive: true, followLinks: false);
      } catch (e) {
        // Carpeta sin permisos de lectura, o borrada entre el `exists()` y
        // el listado: se salta en vez de tumbar todo el escaneo.
        continue;
      }

      for (final entity in entries) {
        if (entity is! File || !_isSupportedFormat(entity.path)) continue;
        final song = await _parseSong(entity);
        if (song != null && seenHashes.add(song.hash)) {
          songs.add(song);
        }
      }
    }

    return songs;
  }

  @override
  Future<List<String>> suggestedLibraryFolders() async {
    final dirs = <Directory>[];

    if (Platform.isAndroid) {
      dirs.addAll([
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
      ]);
    } else if (Platform.isIOS) {
      dirs.add(await getApplicationDocumentsDirectory());
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) dirs.add(downloads);
      dirs.add(await getApplicationDocumentsDirectory());
    }

    final existing = <String>[];
    for (final dir in dirs) {
      if (await dir.exists()) existing.add(dir.path);
    }
    return existing;
  }

  @override
  Future<Song?> pickSongFromDevice() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    final path = file?.path;
    if (path == null) return null;
    return _parseSong(File(path));
  }

  @override
  Future<List<Song>> pickMultipleSongsFromDevice() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);

    final songs = <Song>[];
    for (final file in files) {
      if (file.path == null) continue;
      final song = await _parseSong(File(file.path!));
      if (song != null) songs.add(song);
    }
    return songs;
  }

  // ===== HELPERS =====

  Future<String> calculateHash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<Song?> _parseSong(File file) async {
    try {
      final hash = await calculateHash(file);
      Metadata? metadata;
      if (_metadataGodReady) {
        try {
          metadata = await MetadataGod.readMetadata(file: file.path);
        } catch (_) {
          // Archivo con tags corruptos/no soportados: se sigue con lo que se
          // puede deducir del nombre en vez de descartar la canción entera.
        }
      }

      return Song(
        id: hash,
        path: file.path,
        title: _nonBlank(metadata?.title) ?? _titleFromPath(file.path),
        artist: _nonBlank(metadata?.artist) ?? 'Artista desconocido',
        album: _nonBlank(metadata?.album) ?? 'Álbum desconocido',
        duration: metadata?.duration?.inSeconds ?? 0,
        hash: hash,
        fileSize: await file.length(),
        dateAdded: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  String? _nonBlank(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value.trim();

  bool _isSupportedFormat(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return AppConstants.supportedFormats.contains(ext);
  }

  String _titleFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }
}
