import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'p2p_transfer_service.dart' show P2pTransferService;

/// Implementación real con sockets TCP (`dart:io`) — Android, iOS y
/// Desktop. Ver el protocolo propio documentado en `p2p_transfer_service.dart`.
class P2pTransferServiceImpl implements P2pTransferService {
  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSub;

  @override
  bool get isSupported => true;

  @override
  Future<int?> startServing({
    required Future<String?> Function(String fileHash) resolveLocalPath,
  }) async {
    await stopServing();
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _server = server;
      _serverSub = server.listen((socket) {
        unawaited(_serveOne(socket, resolveLocalPath));
      });
      return server.port;
    } on SocketException {
      return null;
    }
  }

  Future<void> _serveOne(
    Socket socket,
    Future<String?> Function(String fileHash) resolveLocalPath,
  ) async {
    try {
      final requestLine = await _readLine(socket);
      final fileHash = requestLine.startsWith('GET ')
          ? requestLine.substring(4).trim()
          : '';
      final path = fileHash.isEmpty ? null : await resolveLocalPath(fileHash);
      if (path == null) return; // cerrar sin mandar nada: "no lo tengo"

      await socket.addStream(File(path).openRead());
      await socket.flush();
    } catch (_) {
      // El peer se fue a mitad de camino, el archivo se borró entre el
      // pedido y la lectura, etc.: no hay nada más que hacer que cerrar.
    } finally {
      await socket.close();
    }
  }

  /// El cliente de este protocolo manda UNA sola línea y después solo lee
  /// (nunca vuelve a escribir en esa conexión), así que consumir todo el
  /// stream entrante hasta el primer `\n` es seguro: no se pierde nada que
  /// venga después, porque no hay nada después.
  Future<String> _readLine(Socket socket) async {
    final bytes = <int>[];
    await for (final chunk in socket) {
      for (final byte in chunk) {
        if (byte == 10 /* \n */ ) return String.fromCharCodes(bytes);
        bytes.add(byte);
      }
      if (bytes.length > 256) break; // pedido mal formado: cortar
    }
    return String.fromCharCodes(bytes);
  }

  @override
  Future<String> resolveDownloadDestination(String fileHash) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${docsDir.path}/p2p_downloads');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    return '${destDir.path}/$fileHash.mp3';
  }

  @override
  Future<void> stopServing() async {
    await _serverSub?.cancel();
    _serverSub = null;
    await _server?.close();
    _server = null;
  }

  @override
  Future<String?> localIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isPrivateLan(addr.address)) return addr.address;
        }
      }
    } on SocketException {
      // sin permisos de red o sin interfaces activas: se maneja como "no
      // se pudo determinar", igual que el resultado de una lista vacía.
    }
    return null;
  }

  bool _isPrivateLan(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      final second = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  @override
  Future<void> downloadFrom({
    required String hostIp,
    required int hostPort,
    required String fileHash,
    required int expectedFileSize,
    required String destPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final socket = await Socket.connect(
      hostIp,
      hostPort,
      timeout: const Duration(seconds: 10),
    );
    final sink = File(destPath).openWrite();
    final completer = Completer<void>();
    var received = 0;

    socket.write('GET $fileHash\n');
    unawaited(socket.flush());

    final sub = socket.listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, expectedFileSize);
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (completer.isCompleted) return;
        if (received == 0) {
          completer.completeError(
            StateError('El host no tiene el archivo $fileHash'),
          );
        } else if (received < expectedFileSize) {
          completer.completeError(
            StateError(
              'Conexión cortada a mitad de la descarga '
              '($received/$expectedFileSize bytes)',
            ),
          );
        } else {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      await sub.cancel();
      await sink.close();
      await socket.close();
    }
  }
}
