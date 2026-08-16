// Ejercita la implementación real de `dart:io` directamente (sin pasar por
// el factory condicional de `FileService`): `flutter test` corre sobre la
// VM de Dart, donde `dart.library.io` es true, así que esto es exactamente
// el código que corre en Android/iOS/Desktop.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/services/file_service_io.dart';

void main() {
  late Directory tempDir;
  late FileServiceImpl service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mp3_player_test_');
    service = FileServiceImpl();
    // A propósito NO se llama a `service.init()`: eso arrancaría el runtime
    // FFI de metadata_god, que no está disponible corriendo bajo la VM de
    // test. Sin init, `_metadataGodReady` queda false y el servicio cae al
    // fallback de derivar el título del nombre de archivo — exactamente lo
    // que se quiere probar acá.
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'scanLocalLibrary encuentra formatos soportados e ignora el resto',
    () async {
      await File('${tempDir.path}/cancion uno.mp3').writeAsBytes([1, 2, 3, 4]);
      await File('${tempDir.path}/cancion dos.flac').writeAsBytes([5, 6, 7]);
      await File('${tempDir.path}/notas.txt').writeAsString('no es audio');

      final songs = await service.scanLocalLibrary([tempDir.path]);

      expect(songs.length, 2);
      expect(
        songs.map((s) => s.title),
        containsAll(['cancion uno', 'cancion dos']),
      );
    },
  );

  test('escanea subcarpetas de forma recursiva', () async {
    final subDir = Directory('${tempDir.path}/subcarpeta')..createSync();
    await File('${subDir.path}/anidada.mp3').writeAsBytes([9, 9, 9]);

    final songs = await service.scanLocalLibrary([tempDir.path]);

    expect(songs, hasLength(1));
    expect(songs.single.title, 'anidada');
  });

  test('carpeta inexistente no revienta el escaneo, solo la salta', () async {
    final songs = await service.scanLocalLibrary(['${tempDir.path}/no-existe']);
    expect(songs, isEmpty);
  });

  test('dos archivos con contenido idéntico deduplican por hash', () async {
    await File('${tempDir.path}/original.mp3').writeAsBytes([42, 42, 42]);
    await File('${tempDir.path}/copia.mp3').writeAsBytes([42, 42, 42]);

    final songs = await service.scanLocalLibrary([tempDir.path]);

    expect(songs, hasLength(1));
  });

  test('calculateHash es determinista para el mismo contenido', () async {
    final file = File('${tempDir.path}/x.mp3')..writeAsBytesSync([10, 20, 30]);

    final hash1 = await service.calculateHash(file);
    final hash2 = await service.calculateHash(file);

    expect(hash1, hash2);
    expect(hash1, matches(RegExp(r'^[0-9a-f]{64}$'))); // SHA-256 en hex
  });

  test(
    'sin metadata_god inicializado, el fileSize y el path igual quedan bien',
    () async {
      final file = File('${tempDir.path}/cancion.mp3')
        ..writeAsBytesSync(List.filled(100, 1));

      final songs = await service.scanLocalLibrary([tempDir.path]);

      expect(songs.single.fileSize, 100);
      expect(songs.single.path, file.path);
      expect(songs.single.artist, 'Artista desconocido');
      expect(songs.single.duration, 0);
    },
  );
}
