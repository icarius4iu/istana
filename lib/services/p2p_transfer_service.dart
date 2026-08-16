// Selecciona la implementación real según la plataforma en tiempo de
// compilación — mismo patrón que `file_service.dart`: `dart:io` (sockets
// TCP crudos) no existe en Web, así que ese código nunca entra al bundle Web.
import 'p2p_transfer_service_stub.dart'
    if (dart.library.io) 'p2p_transfer_service_io.dart'
    if (dart.library.js_interop) 'p2p_transfer_service_web.dart'
    as impl;

/// Transporte de archivos punta a punta entre dispositivos de una jam
/// session, por TCP crudo directo — el backend (`SessionService`/
/// `P2PCoordinatorService`) solo coordina QUIÉN tiene el archivo y en qué
/// `IP:puerto`; "ni un byte de audio pasa por el servidor" (ver el
/// protocolo de señalización `p2p_request`/`p2p_offer`/`p2p_ready` en
/// `session_service.dart`). Esta clase es el otro extremo: abre el socket
/// servidor que sirve archivos, y el socket cliente que los descarga.
///
/// Protocolo propio sobre el socket (el backend no lo define, solo entrega
/// el `IP:puerto`): una conexión = un pedido. El cliente escribe
/// `GET <fileHash>\n` y se queda leyendo; el servidor, si tiene ese hash,
/// transmite el archivo entero y cierra; si no lo tiene, cierra sin mandar
/// nada (el cliente lo distingue de un corte a mitad de camino porque
/// conoce de antemano el tamaño esperado — `QueueEntry.fileSize` — y
/// `receivedBytes` da 0).
///
/// Solo funciona en la misma red local (las IPs que anuncia `p2p_ready` son
/// privadas, tipo `192.168.x.x`): no hay traversal de NAT para dispositivos
/// en redes distintas — ver [isSupported] para Web, donde ni siquiera hay
/// sockets TCP crudos disponibles.
abstract class P2pTransferService {
  factory P2pTransferService() = impl.P2pTransferServiceImpl;

  /// `false` en Web: no hay `dart:io`, no hay sockets TCP crudos posibles
  /// desde el navegador. La UI debe ocultar/deshabilitar todo lo que
  /// dependa de esto — ver `Env.canP2pTransfer`.
  bool get isSupported;

  /// Arranca el servidor TCP local (puerto elegido por el SO) que sirve
  /// archivos a pedido. [resolveLocalPath] traduce un hash pedido a una
  /// ruta de archivo local reproducible, o `null` si no lo tenemos — se
  /// vuelve a consultar en cada conexión entrante, así que refleja cambios
  /// en la biblioteca sin tener que reiniciar el servidor. Devuelve el
  /// puerto, o `null` si no se pudo abrir (p. ej. Web).
  Future<int?> startServing({
    required Future<String?> Function(String fileHash) resolveLocalPath,
  });

  Future<void> stopServing();

  /// Mejor esfuerzo: primera IP privada (LAN) no-loopback de este
  /// dispositivo, la misma que hay que anunciar en `p2p_ready`. `null` si
  /// no se pudo determinar (sin interfaces activas, Web, etc.).
  Future<String?> localIpAddress();

  /// Ruta de archivo local donde guardar una descarga P2P entrante (una
  /// subcarpeta propia del almacenamiento de la app). No se llama nunca en
  /// plataformas sin [isSupported].
  Future<String> resolveDownloadDestination(String fileHash);

  /// Se conecta a un host ya anunciado por `p2p_ready` y descarga
  /// [fileHash] a [destPath]. Lanza [StateError] si el host no lo tiene o
  /// si la conexión se corta antes de completar los [expectedFileSize]
  /// bytes (viene de `QueueEntry.fileSize`, no del wire — ver doc de clase).
  Future<void> downloadFrom({
    required String hostIp,
    required int hostPort,
    required String fileHash,
    required int expectedFileSize,
    required String destPath,
    void Function(int received, int total)? onProgress,
  });
}
