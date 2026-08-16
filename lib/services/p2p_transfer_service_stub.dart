import 'p2p_transfer_service.dart' show P2pTransferService;

/// Fallback si el compilador no reconoce ni `dart.library.io` ni
/// `dart.library.js_interop` — mismo rol que `file_service_stub.dart`.
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
    throw UnsupportedError('La transferencia P2P no está disponible acá');
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
    throw UnsupportedError('La transferencia P2P no está disponible acá');
  }
}
