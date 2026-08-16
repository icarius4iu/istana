import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/constants.dart';
import '../models/session_models.dart';
import 'api_client.dart';

/// Resultado de `POST /api/sessions/{code}/join`: sesión + snapshot de
/// miembros en el mismo viaje (el backend los devuelve juntos).
typedef JoinResult = ({JamSession session, List<SessionMember> members});

/// Coordina una jam session: REST para sesión/miembros/cola compartida,
/// WebSocket para reproducción sincronizada, clock sync y señalización P2P.
///
/// El canal de WebSocket queda envuelto acá — nadie fuera de esta clase
/// importa `web_socket_channel`, igual que `AudioService` envuelve
/// `just_audio` — e inyectable por el mismo motivo: testear sin abrir un
/// socket real (ver el parámetro [connect]).
class SessionService {
  final ApiClient _api;
  final WebSocketChannel Function(Uri uri) _connect;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  final _eventsController = StreamController<SessionServerEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  String? _sessionCode;

  SessionService({
    required ApiClient api,
    WebSocketChannel Function(Uri uri)? connect,
  }) : _api = api,
       _connect = connect ?? WebSocketChannel.connect;

  /// Eventos del servidor ya tipados (ver `SessionServerEvent.fromJson`).
  Stream<SessionServerEvent> get events => _eventsController.stream;

  /// `true`/`false` cuando el socket abre/cierra, para que el provider
  /// muestre "conectando"/"desconectado" y decida si reconectar. El backend
  /// no manda ping ni detecta cierres a medias: la única señal de vida real
  /// es el heartbeat que el propio cliente manda (ver `sendHeartbeat`).
  Stream<bool> get connectionState => _connectionController.stream;

  bool get isConnected => _channel != null;

  // ===== REST: sesión =====

  Future<JamSession> createSession({
    required String ownerId,
    int? ttlMinutes,
  }) async {
    final json = await _api.post(
      '/api/sessions',
      body: {
        'ownerId': ownerId,
        if (ttlMinutes != null) 'ttlMinutes': ttlMinutes,
      },
    ) as Map<String, dynamic>;
    return JamSession.fromJson(json);
  }

  /// Idempotente en el backend: re-unirse a una sesión de la que ya se es
  /// miembro solo refresca el latido, no consume plaza ni cambia el rol —
  /// por eso también sirve para que el creador "entre" a su propia sesión
  /// recién creada sin una llamada aparte.
  Future<JoinResult> joinSession({
    required String code,
    required String userId,
  }) async {
    final json = await _api.post(
      '/api/sessions/$code/join',
      body: {'userId': userId},
    ) as Map<String, dynamic>;
    final session = JamSession.fromJson(
      json['session'] as Map<String, dynamic>,
    );
    final members = (json['users'] as List<dynamic>)
        .map((e) => SessionMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return (session: session, members: members);
  }

  Future<void> leaveSession({required String code, required String userId}) {
    return _api.delete('/api/sessions/$code/leave', query: {'userId': userId});
  }

  Future<List<SessionMember>> getMembers(String code) async {
    final json = await _api.get('/api/sessions/$code/users') as List<dynamic>;
    return json
        .map((e) => SessionMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ===== REST: cola compartida (SIN push por WebSocket — hay que pollear) =====

  Future<QueueEntry> addToQueue({
    required String code,
    required String addedByUserId,
    required String title,
    required String artist,
    String? album,
    required String fileHash,
    required int fileSize,
    required int durationSeconds,
  }) async {
    final json = await _api.post(
      '/api/sessions/$code/queue/add',
      query: {'addedBy': addedByUserId},
      body: {
        'title': title,
        'artist': artist,
        if (album != null) 'album': album,
        'fileHash': fileHash,
        'fileSize': fileSize,
        'duration': durationSeconds,
      },
    ) as Map<String, dynamic>;
    return QueueEntry.fromJson(json);
  }

  Future<List<QueueEntry>> getQueue(String code) async {
    final json = await _api.get('/api/sessions/$code/queue') as List<dynamic>;
    return json
        .map((e) => QueueEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// El backend puede devolver 200 con body vacío cuando no queda ninguna
  /// pendiente, a pesar de que su javadoc promete 404 (es un `Mono` vacío
  /// en WebFlux, no una excepción): tratamos ambos casos como "no hay
  /// siguiente".
  Future<QueueEntry?> getNextInQueue(String code) async {
    try {
      final json = await _api.get('/api/sessions/$code/queue/next');
      if (json == null) return null;
      return QueueEntry.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<QueueEntry> setQueueItemStatus({
    required String code,
    required String queueItemId,
    required QueueItemStatus status,
  }) async {
    final json = await _api.post(
      '/api/sessions/$code/queue/$queueItemId/status',
      query: {'status': status.wireName},
    ) as Map<String, dynamic>;
    return QueueEntry.fromJson(json);
  }

  Future<void> removeFromQueue({
    required String code,
    required String queueItemId,
  }) {
    return _api.delete('/api/sessions/$code/queue/$queueItemId');
  }

  // ===== WebSocket =====

  /// Abre el socket de la sesión. La identidad viaja como `?userId=` en la
  /// URL del handshake — el backend no autentica el WS con JWT (cualquiera
  /// con el código de sala y un userId ajeno podría suplantarlo; deuda
  /// documentada del MVP, no de este cliente).
  void connect({
    required Uri wsBaseUri,
    required String code,
    required String userId,
  }) {
    disconnect();
    _sessionCode = code;
    final uri = wsBaseUri.replace(
      path: '/ws/session/$code',
      queryParameters: {'userId': userId},
    );
    final channel = _connect(uri);
    _channel = channel;
    _connectionController.add(true);
    _channelSub = channel.stream.listen(
      _handleRaw,
      onDone: () {
        _channel = null;
        _connectionController.add(false);
      },
      onError: (_) {
        _channel = null;
        _connectionController.add(false);
      },
      cancelOnError: false,
    );
  }

  void _handleRaw(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _eventsController.add(SessionServerEvent.fromJson(json));
    } on FormatException {
      // Mensaje ilegible: se ignora en vez de tumbar la suscripción entera.
    }
  }

  void _send(Map<String, dynamic> command) {
    final channel = _channel;
    final code = _sessionCode;
    if (channel == null || code == null) return;
    channel.sink.add(jsonEncode({...command, 'sessionCode': code}));
  }

  void sendPlay({int? positionMs}) => _send({
    'action': 'play',
    if (positionMs != null) 'positionMs': positionMs,
  });

  void sendPause({int? positionMs}) => _send({
    'action': 'pause',
    if (positionMs != null) 'positionMs': positionMs,
  });

  void sendSeek(int positionMs) =>
      _send({'action': 'seek', 'positionMs': positionMs});

  void sendHeartbeat() => _send({'action': 'heartbeat'});

  void sendClockSyncRequest(int clientTimeMs) =>
      _send({'action': 'clock_sync_request', 'timestamp': clientTimeMs});

  void sendP2pRequest({
    required String fileHash,
    required String fileName,
    required int fileSize,
  }) => _send({
    'action': 'p2p_request',
    'fileHash': fileHash,
    'fileName': fileName,
    'fileSize': fileSize,
  });

  void sendP2pReady({
    required String fileHash,
    required String localIp,
    required int localPort,
  }) => _send({
    'action': 'p2p_ready',
    'fileHash': fileHash,
    'localIP': localIp, // clave EXACTA que espera el backend (mayúsculas)
    'localPort': localPort,
  });

  void sendTransferProgress({
    required String fileHash,
    required int bytesSent,
    required int totalBytes,
  }) => _send({
    'action': 'transfer_progress',
    'fileHash': fileHash,
    'bytesSent': bytesSent,
    'totalBytes': totalBytes,
  });

  /// Sincronización de reloj estilo NTP (t0 cliente -> t1/t2 servidor -> t3
  /// cliente). El servidor es stateless por intercambio: el número de
  /// rondas es decisión del cliente. Reintenta hasta [maxAttempts] veces
  /// buscando una medida confiable (RTT <= 300ms) y devuelve la de menor
  /// RTT si ninguna lo fue.
  Future<ClockSyncMeasurement?> syncClock({
    int maxAttempts = AppConstants.clockSyncMaxAttempts,
  }) async {
    ClockSyncMeasurement? best;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final measurement = await _oneClockSyncRound();
      if (measurement == null) continue;
      if (best == null || measurement.roundTripMs < best.roundTripMs) {
        best = measurement;
      }
      if (measurement.isReliable) return measurement;
    }
    return best;
  }

  Future<ClockSyncMeasurement?> _oneClockSyncRound() async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final responseFuture = events
        .where((e) => e is ClockSyncResponseEvent)
        .cast<ClockSyncResponseEvent>()
        .first
        .timeout(AppConstants.clockSyncRoundTimeout);
    sendClockSyncRequest(t0);
    try {
      final response = await responseFuture;
      final t3 = DateTime.now().millisecondsSinceEpoch;
      final offset =
          ((response.serverReceiveTimeMs - t0) +
              (response.serverSendTimeMs - t3)) ~/
          2;
      final roundTrip =
          (t3 - t0) -
          (response.serverSendTimeMs - response.serverReceiveTimeMs);
      return ClockSyncMeasurement(offsetMs: offset, roundTripMs: roundTrip);
    } on TimeoutException {
      return null;
    }
  }

  void disconnect() {
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _sessionCode = null;
  }

  Future<void> dispose() async {
    disconnect();
    await _eventsController.close();
    await _connectionController.close();
  }
}
