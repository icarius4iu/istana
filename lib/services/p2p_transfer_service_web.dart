import 'p2p_transfer_service.dart' show P2pTransferService;

/// Web no tiene sockets TCP crudos (`dart:io` no existe en el navegador):
/// no hay forma de abrir un servidor local ni de conectarse directo a la IP
/// de otro dispositivo. `startServing`/`localIpAddress` devuelven `null`
/// (los llamadores ya están escritos defensivamente para ese caso, como en
/// `FileService`); `downloadFrom` no debería invocarse nunca acá — los
/// llamadores tienen que chequear [isSupported] antes.
class P2pTransferServiceImpl implements P2pTransferService {
  @override
  bool get isSupported => false;

  @override
  Future<int?> startServing({
    required Future<String?> Function(String fileHash) resolveLocalPath,
  }) async => null;

  @override
  Future<void> stopServing() async {}

  @override
  Future<String?> localIpAddress() async => null;

  @override
  Future<String> resolveDownloadDestination(String fileHash) {
    throw UnsupportedError(
      'La transferencia P2P no está disponible en Web (sin sockets TCP)',
    );
  }

  @override
  Future<void> downloadFrom({
    required String hostIp,
    required int hostPort,
    required String fileHash,
    required int expectedFileSize,
    required String destPath,
    void Function(int received, int total)? onProgress,
  }) {
    throw UnsupportedError(
      'La transferencia P2P no está disponible en Web (sin sockets TCP)',
    );
  }
}
