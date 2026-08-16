// Ejercita la implementación real de sockets TCP (`dart:io`) contra
// servidores/clientes locales — mismo espíritu que
// `session_service_test.dart`: nada de mocks, se prueba el protocolo de
// verdad (loopback, sin depender de red externa).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/services/p2p_transfer_service_io.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('p2p_transfer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('startServing + downloadFrom (round-trip completo)', () {
    test('baja un archivo que el servidor sí tiene', () async {
      final sourceFile = File('${tempDir.path}/origen.mp3')
        ..writeAsBytesSync(List.generate(50000, (i) => i % 256));
      final expectedBytes = sourceFile.readAsBytesSync();

      final server = P2pTransferServiceImpl();
      final port = await server.startServing(
        resolveLocalPath: (hash) async =>
            hash == 'hash-real' ? sourceFile.path : null,
      );
      addTearDown(server.stopServing);
      expect(port, isNotNull);

      final client = P2pTransferServiceImpl();
      final destPath = '${tempDir.path}/destino.mp3';
      final progressCalls = <(int, int)>[];

      await client.downloadFrom(
        hostIp: '127.0.0.1',
        hostPort: port!,
        fileHash: 'hash-real',
        expectedFileSize: expectedBytes.length,
        destPath: destPath,
        onProgress: (received, total) => progressCalls.add((received, total)),
      );

      final downloaded = File(destPath).readAsBytesSync();
      expect(downloaded, equals(expectedBytes));
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last.$1, expectedBytes.length);
    });

    test(
      'varias descargas concurrentes del mismo servidor no se pisan',
      () async {
        final fileA = File('${tempDir.path}/a.mp3')
          ..writeAsBytesSync(List.filled(20000, 0xAA));
        final fileB = File('${tempDir.path}/b.mp3')
          ..writeAsBytesSync(List.filled(30000, 0xBB));

        final server = P2pTransferServiceImpl();
        final port = await server.startServing(
          resolveLocalPath: (hash) async => switch (hash) {
            'a' => fileA.path,
            'b' => fileB.path,
            _ => null,
          },
        );
        addTearDown(server.stopServing);

        final clientA = P2pTransferServiceImpl();
        final clientB = P2pTransferServiceImpl();

        await Future.wait([
          clientA.downloadFrom(
            hostIp: '127.0.0.1',
            hostPort: port!,
            fileHash: 'a',
            expectedFileSize: fileA.lengthSync(),
            destPath: '${tempDir.path}/dest_a.mp3',
          ),
          clientB.downloadFrom(
            hostIp: '127.0.0.1',
            hostPort: port,
            fileHash: 'b',
            expectedFileSize: fileB.lengthSync(),
            destPath: '${tempDir.path}/dest_b.mp3',
          ),
        ]);

        expect(
          File('${tempDir.path}/dest_a.mp3').readAsBytesSync(),
          equals(fileA.readAsBytesSync()),
        );
        expect(
          File('${tempDir.path}/dest_b.mp3').readAsBytesSync(),
          equals(fileB.readAsBytesSync()),
        );
      },
    );
  });

  group('downloadFrom — casos de error', () {
    test(
      'lanza si el host no tiene el archivo (cierra sin mandar nada)',
      () async {
        late ServerSocket rawServer;
        rawServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        rawServer.listen((socket) {
          socket.close(); // "no lo tengo": cierra sin escribir bytes
        });
        addTearDown(rawServer.close);

        final client = P2pTransferServiceImpl();
        await expectLater(
          client.downloadFrom(
            hostIp: '127.0.0.1',
            hostPort: rawServer.port,
            fileHash: 'lo-que-sea',
            expectedFileSize: 1000,
            destPath: '${tempDir.path}/no-deberia-existir.mp3',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('lanza si la conexión se corta a mitad de la descarga', () async {
      late ServerSocket rawServer;
      rawServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      rawServer.listen((socket) async {
        socket.add(utf8.encode('solo esto y listo')); // menos de lo esperado
        await socket.flush();
        await socket.close();
      });
      addTearDown(rawServer.close);

      final client = P2pTransferServiceImpl();
      await expectLater(
        client.downloadFrom(
          hostIp: '127.0.0.1',
          hostPort: rawServer.port,
          fileHash: 'lo-que-sea',
          expectedFileSize: 999999, // mucho más de lo que el server manda
          destPath: '${tempDir.path}/parcial.mp3',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('localIpAddress', () {
    test('devuelve null o una IP con forma de rango privado', () async {
      final service = P2pTransferServiceImpl();
      final ip = await service.localIpAddress();

      if (ip != null) {
        final isPrivate =
            ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
        expect(isPrivate, isTrue, reason: '$ip no parece un rango LAN privado');
      }
    });
  });

  // resolveDownloadDestination usa `path_provider`, que exige un canal de
  // plataforma real (no disponible bajo `flutter test` — ver el README,
  // sección de integration_test/): queda sin cubrir acá a propósito, igual
  // que StorageService.init evita path_provider en sus propios tests.
}
