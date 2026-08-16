/// Modelos de dominio de la jam session: sesión, miembros, cola compartida y
/// los eventos del WebSocket `/ws/session/{code}`.
///
/// Espejan exactamente lo que devuelve el backend (`SessionResponse`,
/// `SessionUserResponse`, `QueueItemResponse`, `ServerMessage` — ver
/// `core/session-core` en el repo del backend), campo a campo, incluidas sus
/// inconsistencias de naming reales: los mensajes del WebSocket mezclan
/// snake_case (`state_changed`, `heartbeat`, `user_joined`) con camelCase
/// (`play_scheduled`, `clock_sync_response`), y el cliente manda `localIP`
/// pero recibe `hostIP`. No se "normaliza" nada acá a propósito: cada evento
/// parsea sus propios campos tal cual los manda el servidor.
library;

enum JamPlaybackState { paused, playing }

JamPlaybackState _parsePlaybackState(String? raw) =>
    raw == 'playing' ? JamPlaybackState.playing : JamPlaybackState.paused;

enum SessionRole { host, peer }

SessionRole _parseRole(String? raw) =>
    raw?.toUpperCase() == 'HOST' ? SessionRole.host : SessionRole.peer;

enum MemberConnectionStatus { connecting, connected, disconnected }

MemberConnectionStatus _parseConnectionStatus(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'CONNECTED':
      return MemberConnectionStatus.connected;
    case 'DISCONNECTED':
      return MemberConnectionStatus.disconnected;
    default:
      return MemberConnectionStatus.connecting;
  }
}

enum QueueItemStatus { pending, downloading, playing, completed }

QueueItemStatus _parseQueueStatus(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'DOWNLOADING':
      return QueueItemStatus.downloading;
    case 'PLAYING':
      return QueueItemStatus.playing;
    case 'COMPLETED':
      return QueueItemStatus.completed;
    default:
      return QueueItemStatus.pending;
  }
}

extension QueueItemStatusWire on QueueItemStatus {
  /// El backend espera el enum en MAYÚSCULAS como query param (`?status=`).
  String get wireName => name.toUpperCase();
}

/// Espeja `SessionResponse` (`POST /api/sessions`, `GET /api/sessions/{code}`).
class JamSession {
  final String id;
  final String code;
  final String ownerId;
  final String? currentSongId;
  final int currentPositionMs;
  final JamPlaybackState state;
  final int maxUsers;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// PNG del QR en base64 (clave real: `qrCodePng`, no `qrCode`). Solo lo
  /// manda la creación; `GET /api/sessions/{code}` no lo repite.
  final String? qrCodePngBase64;

  const JamSession({
    required this.id,
    required this.code,
    required this.ownerId,
    this.currentSongId,
    required this.currentPositionMs,
    required this.state,
    required this.maxUsers,
    required this.createdAt,
    required this.expiresAt,
    this.qrCodePngBase64,
  });

  /// El WebSocket difunde `state_changed` con el nuevo estado/posición, pero
  /// no reemite la sesión entera — `SessionProvider` usa esto para
  /// mantenerla al día sin perder `qrCodePngBase64` (que solo viaja en la
  /// respuesta de creación).
  JamSession copyWith({
    JamPlaybackState? state,
    int? currentPositionMs,
    String? currentSongId,
  }) => JamSession(
    id: id,
    code: code,
    ownerId: ownerId,
    currentSongId: currentSongId ?? this.currentSongId,
    currentPositionMs: currentPositionMs ?? this.currentPositionMs,
    state: state ?? this.state,
    maxUsers: maxUsers,
    createdAt: createdAt,
    expiresAt: expiresAt,
    qrCodePngBase64: qrCodePngBase64,
  );

  factory JamSession.fromJson(Map<String, dynamic> json) => JamSession(
    id: json['id'] as String,
    code: json['code'] as String,
    ownerId: json['ownerId'] as String,
    currentSongId: json['currentSongId'] as String?,
    currentPositionMs: json['currentPositionMs'] as int? ?? 0,
    state: _parsePlaybackState(json['state'] as String?),
    maxUsers: json['maxUsers'] as int? ?? 5,
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    qrCodePngBase64: json['qrCodePng'] as String?,
  );
}

/// Espeja `SessionUserResponse` (`GET /api/sessions/{code}/users`).
class SessionMember {
  final String userId;
  final SessionRole role;
  final MemberConnectionStatus connectionStatus;
  final String? localIp;
  final int? localPort;
  final bool canServeFiles;
  final DateTime joinedAt;
  final DateTime lastHeartbeat;

  const SessionMember({
    required this.userId,
    required this.role,
    required this.connectionStatus,
    this.localIp,
    this.localPort,
    required this.canServeFiles,
    required this.joinedAt,
    required this.lastHeartbeat,
  });

  factory SessionMember.fromJson(Map<String, dynamic> json) => SessionMember(
    userId: json['userId'] as String,
    role: _parseRole(json['role'] as String?),
    connectionStatus: _parseConnectionStatus(
      json['connectionStatus'] as String?,
    ),
    localIp: json['localIp'] as String?,
    localPort: json['localPort'] as int?,
    canServeFiles: json['canServeFiles'] as bool? ?? false,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
    lastHeartbeat: DateTime.parse(json['lastHeartbeat'] as String),
  );
}

/// Espeja `QueueItemResponse` (`/api/sessions/{code}/queue...`).
class QueueEntry {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String fileHash;
  final int fileSize;
  final int durationSeconds;
  final String addedBy;
  final int position;
  final QueueItemStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  const QueueEntry({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.fileHash,
    required this.fileSize,
    required this.durationSeconds,
    required this.addedBy,
    required this.position,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory QueueEntry.fromJson(Map<String, dynamic> json) => QueueEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String?,
    fileHash: json['fileHash'] as String,
    fileSize: json['fileSize'] as int,
    durationSeconds: json['duration'] as int,
    addedBy: json['addedBy'] as String,
    position: json['position'] as int,
    status: _parseQueueStatus(json['status'] as String?),
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
  );
}

// ===== Eventos del WebSocket /ws/session/{code} =====

/// Base sellada de todo lo que puede llegar por el socket. Un `type` que no
/// reconocemos cae en [UnknownSessionEvent] en vez de tirar una excepción,
/// para que una versión más nueva del protocolo del backend no tumbe un
/// cliente viejo.
sealed class SessionServerEvent {
  final DateTime timestamp;
  const SessionServerEvent({required this.timestamp});

  factory SessionServerEvent.fromJson(Map<String, dynamic> json) {
    final ts = DateTime.fromMillisecondsSinceEpoch(
      (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
    switch (json['type'] as String?) {
      case 'state_changed':
        return StateChangedEvent(
          timestamp: ts,
          state: _parsePlaybackState(json['state'] as String?),
          positionMs: json['position_ms'] as int? ?? 0,
          currentSongId: json['current_song_id'] as String?,
          userId: json['userId'] as String?,
        );
      case 'play_scheduled':
        return PlayScheduledEvent(
          timestamp: ts,
          positionMs: json['positionMs'] as int? ?? 0,
          playAtUnixTimestampMs: (json['playAtUnixTimestamp'] as num).toInt(),
          bufferMs: json['buffer'] as int? ?? 0,
        );
      case 'user_joined':
        return UserJoinedEvent(
          timestamp: ts,
          userId: json['userId'] as String?,
          usersConnected: json['users_connected'] as int? ?? 0,
        );
      case 'heartbeat':
        final sessionState = json['session_state'] as Map<String, dynamic>?;
        return SessionHeartbeatEvent(
          timestamp: ts,
          usersConnected: json['users_connected'] as int? ?? 0,
          state: sessionState == null
              ? null
              : _parsePlaybackState(sessionState['state'] as String?),
          positionMs: sessionState?['position_ms'] as int?,
          currentSongId: sessionState?['current_song_id'] as String?,
        );
      case 'error':
        return SessionErrorEvent(
          timestamp: ts,
          message: json['message'] as String? ?? 'Error desconocido',
        );
      case 'clock_sync_response':
        return ClockSyncResponseEvent(
          timestamp: ts,
          clientTimeMs: (json['clientTime'] as num).toInt(),
          serverReceiveTimeMs: (json['serverReceiveTime'] as num).toInt(),
          serverSendTimeMs: (json['serverSendTime'] as num).toInt(),
        );
      case 'p2p_offer':
        return P2pOfferEvent(
          timestamp: ts,
          initiatorUserId: json['initiator'] as String,
          hostUserId: json['hostId'] as String,
          fileHash: json['fileHash'] as String,
          fileName: json['fileName'] as String?,
          fileSize: json['fileSize'] as int?,
        );
      case 'p2p_ready':
        return P2pReadyEvent(
          timestamp: ts,
          hostIp: json['hostIP'] as String,
          hostPort: json['hostPort'] as int,
          fileHash: json['fileHash'] as String,
        );
      default:
        return UnknownSessionEvent(timestamp: ts, raw: json);
    }
  }
}

class StateChangedEvent extends SessionServerEvent {
  final JamPlaybackState state;
  final int positionMs;
  final String? currentSongId;
  final String? userId;

  const StateChangedEvent({
    required super.timestamp,
    required this.state,
    required this.positionMs,
    this.currentSongId,
    this.userId,
  });
}

/// La cita de reproducción: `playAtUnixTimestampMs` está en el reloj del
/// SERVIDOR — hay que restarle el offset de clock sync para saber en qué
/// instante del reloj propio hay que arrancar (ver `SessionProvider`).
class PlayScheduledEvent extends SessionServerEvent {
  final int positionMs;
  final int playAtUnixTimestampMs;
  final int bufferMs;

  const PlayScheduledEvent({
    required super.timestamp,
    required this.positionMs,
    required this.playAtUnixTimestampMs,
    required this.bufferMs,
  });
}

class UserJoinedEvent extends SessionServerEvent {
  final String? userId;
  final int usersConnected;

  const UserJoinedEvent({
    required super.timestamp,
    this.userId,
    required this.usersConnected,
  });
}

class SessionHeartbeatEvent extends SessionServerEvent {
  final int usersConnected;
  final JamPlaybackState? state;
  final int? positionMs;
  final String? currentSongId;

  const SessionHeartbeatEvent({
    required super.timestamp,
    required this.usersConnected,
    this.state,
    this.positionMs,
    this.currentSongId,
  });
}

class SessionErrorEvent extends SessionServerEvent {
  final String message;

  const SessionErrorEvent({required super.timestamp, required this.message});
}

/// Los tres instantes crudos del intercambio NTP; `SessionService.syncClock`
/// hace la cuenta (ver `ClockSyncMeasurement`).
class ClockSyncResponseEvent extends SessionServerEvent {
  final int clientTimeMs;
  final int serverReceiveTimeMs;
  final int serverSendTimeMs;

  const ClockSyncResponseEvent({
    required super.timestamp,
    required this.clientTimeMs,
    required this.serverReceiveTimeMs,
    required this.serverSendTimeMs,
  });
}

class P2pOfferEvent extends SessionServerEvent {
  final String initiatorUserId;
  final String hostUserId;
  final String fileHash;
  final String? fileName;
  final int? fileSize;

  const P2pOfferEvent({
    required super.timestamp,
    required this.initiatorUserId,
    required this.hostUserId,
    required this.fileHash,
    this.fileName,
    this.fileSize,
  });
}

class P2pReadyEvent extends SessionServerEvent {
  final String hostIp;
  final int hostPort;
  final String fileHash;

  const P2pReadyEvent({
    required super.timestamp,
    required this.hostIp,
    required this.hostPort,
    required this.fileHash,
  });
}

class UnknownSessionEvent extends SessionServerEvent {
  final Map<String, dynamic> raw;

  const UnknownSessionEvent({required super.timestamp, required this.raw});
}

/// Medición de sincronización de reloj estilo NTP contra el servidor — ver
/// `ClockOffset` en el backend (`core/session-core/.../sync/ClockOffset.java`).
/// [offsetMs] es lo que hay que SUMAR al reloj local para obtener el del
/// servidor.
class ClockSyncMeasurement {
  final int offsetMs;
  final int roundTripMs;

  const ClockSyncMeasurement({
    required this.offsetMs,
    required this.roundTripMs,
  });

  /// El backend descarta medidas con RTT negativo o mayor a 300ms
  /// (`ClockOffset.MAX_RELIABLE_ROUND_TRIP_MS`): con latencia alta la
  /// suposición de simetría ida/vuelta deja de sostenerse.
  bool get isReliable => roundTripMs >= 0 && roundTripMs <= 300;
}
