// El protocolo real del backend mezcla convenciones (snake_case en
// state_changed/heartbeat/user_joined, camelCase en play_scheduled/
// clock_sync_response, y 'localIP' vs 'hostIP'): estos tests fijan que cada
// evento parsea EXACTAMENTE esos campos, no una convención global.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/models/session_models.dart';

void main() {
  group('JamSession.fromJson', () {
    test('parsea una sesión recién creada, con QR', () {
      final session = JamSession.fromJson({
        'id': 'sess-1',
        'code': 'JAM-A2B',
        'ownerId': 'user-1',
        'currentSongId': null,
        'currentPositionMs': 0,
        'state': 'paused',
        'maxUsers': 5,
        'createdAt': '2026-08-16T12:00:00Z',
        'expiresAt': '2026-08-16T14:00:00Z',
        'qrCodePng': 'aGVsbG8=',
      });

      expect(session.code, 'JAM-A2B');
      expect(session.state, JamPlaybackState.paused);
      expect(session.qrCodePngBase64, 'aGVsbG8=');
    });

    test('state "playing" se distingue de cualquier otro valor', () {
      final session = JamSession.fromJson(_baseSessionJson('playing'));
      expect(session.state, JamPlaybackState.playing);
    });
  });

  group('SessionMember.fromJson', () {
    test('HOST con endpoint anunciado', () {
      final member = SessionMember.fromJson({
        'userId': 'user-1',
        'role': 'HOST',
        'connectionStatus': 'CONNECTED',
        'localIp': '192.168.1.42',
        'localPort': 45231,
        'canServeFiles': true,
        'joinedAt': '2026-08-16T12:00:00Z',
        'lastHeartbeat': '2026-08-16T12:00:05Z',
      });

      expect(member.role, SessionRole.host);
      expect(member.connectionStatus, MemberConnectionStatus.connected);
      expect(member.canServeFiles, isTrue);
    });

    test('PEER sin endpoint todavía', () {
      final member = SessionMember.fromJson({
        'userId': 'user-2',
        'role': 'PEER',
        'connectionStatus': 'CONNECTING',
        'canServeFiles': false,
        'joinedAt': '2026-08-16T12:00:00Z',
        'lastHeartbeat': '2026-08-16T12:00:00Z',
      });

      expect(member.role, SessionRole.peer);
      expect(member.localIp, isNull);
    });
  });

  group('QueueEntry.fromJson', () {
    test('mapea "duration" del backend a durationSeconds', () {
      final entry = QueueEntry.fromJson({
        'id': 'q-1',
        'title': 'Bleed',
        'artist': 'Meshuggah',
        'album': 'demo',
        'fileHash': 'a' * 64,
        'fileSize': 4301635,
        'duration': 135,
        'addedBy': 'user-2',
        'position': 0,
        'status': 'PENDING',
        'createdAt': '2026-08-16T12:00:00Z',
        'completedAt': null,
      });

      expect(entry.durationSeconds, 135);
      expect(entry.status, QueueItemStatus.pending);
    });

    test('QueueItemStatus.wireName manda el enum en MAYÚSCULAS', () {
      expect(QueueItemStatus.playing.wireName, 'PLAYING');
      expect(QueueItemStatus.pending.wireName, 'PENDING');
    });
  });

  group('SessionServerEvent.fromJson', () {
    test('state_changed usa snake_case (position_ms, current_song_id)', () {
      final event = SessionServerEvent.fromJson({
        'type': 'state_changed',
        'state': 'playing',
        'position_ms': 30000,
        'current_song_id': null,
        'userId': 'user-1',
        'timestamp': 1692000000000,
      });

      expect(event, isA<StateChangedEvent>());
      final e = event as StateChangedEvent;
      expect(e.state, JamPlaybackState.playing);
      expect(e.positionMs, 30000);
    });

    test('play_scheduled usa camelCase (positionMs, playAtUnixTimestamp)', () {
      final event = SessionServerEvent.fromJson({
        'type': 'play_scheduled',
        'positionMs': 30000,
        'playAtUnixTimestamp': 1692000000200,
        'buffer': 200,
        'timestamp': 1692000000000,
      });

      expect(event, isA<PlayScheduledEvent>());
      final e = event as PlayScheduledEvent;
      expect(e.positionMs, 30000);
      expect(e.playAtUnixTimestampMs, 1692000000200);
      expect(e.bufferMs, 200);
    });

    test('heartbeat trae session_state anidado', () {
      final event = SessionServerEvent.fromJson({
        'type': 'heartbeat',
        'users_connected': 2,
        'session_state': {
          'state': 'paused',
          'position_ms': 500,
          'current_song_id': null,
        },
        'timestamp': 1692000000000,
      });

      expect(event, isA<SessionHeartbeatEvent>());
      final e = event as SessionHeartbeatEvent;
      expect(e.usersConnected, 2);
      expect(e.state, JamPlaybackState.paused);
      expect(e.positionMs, 500);
    });

    test('heartbeat sin session_state deja los campos derivados en null', () {
      final event = SessionServerEvent.fromJson({
        'type': 'heartbeat',
        'users_connected': 1,
        'timestamp': 1692000000000,
      }) as SessionHeartbeatEvent;

      expect(event.state, isNull);
      expect(event.positionMs, isNull);
    });

    test('p2p_ready recibe "hostIP", no "localIP"', () {
      final event = SessionServerEvent.fromJson({
        'type': 'p2p_ready',
        'hostIP': '192.168.1.42',
        'hostPort': 45231,
        'fileHash': 'a' * 64,
        'timestamp': 1692000000000,
      });

      expect(event, isA<P2pReadyEvent>());
      expect((event as P2pReadyEvent).hostIp, '192.168.1.42');
    });

    test('p2p_offer trae initiator y hostId', () {
      final event = SessionServerEvent.fromJson({
        'type': 'p2p_offer',
        'initiator': 'user-2',
        'hostId': 'user-1',
        'fileHash': 'a' * 64,
        'fileName': 'bleed.mp3',
        'fileSize': 4301635,
        'timestamp': 1692000000000,
      }) as P2pOfferEvent;

      expect(event.initiatorUserId, 'user-2');
      expect(event.hostUserId, 'user-1');
    });

    test('error trae el mensaje privado', () {
      final event = SessionServerEvent.fromJson({
        'type': 'error',
        'message': 'Accion desconocida: stop',
        'timestamp': 1692000000000,
      }) as SessionErrorEvent;

      expect(event.message, 'Accion desconocida: stop');
    });

    test('clock_sync_response expone los tres instantes crudos', () {
      final event = SessionServerEvent.fromJson({
        'type': 'clock_sync_response',
        'clientTime': 1000,
        'serverReceiveTime': 1010,
        'serverSendTime': 1015,
        'serverProcessingTime': 5,
        'timestamp': 1015,
      }) as ClockSyncResponseEvent;

      expect(event.clientTimeMs, 1000);
      expect(event.serverReceiveTimeMs, 1010);
      expect(event.serverSendTimeMs, 1015);
    });

    test('un "type" desconocido no revienta: cae en UnknownSessionEvent', () {
      final event = SessionServerEvent.fromJson({
        'type': 'algo_del_futuro',
        'timestamp': 1692000000000,
        'campoRaro': 42,
      });

      expect(event, isA<UnknownSessionEvent>());
      expect((event as UnknownSessionEvent).raw['campoRaro'], 42);
    });
  });

  group('ClockSyncMeasurement.isReliable', () {
    test('RTT dentro de [0, 300] es confiable', () {
      expect(
        const ClockSyncMeasurement(offsetMs: 10, roundTripMs: 0).isReliable,
        isTrue,
      );
      expect(
        const ClockSyncMeasurement(offsetMs: 10, roundTripMs: 300).isReliable,
        isTrue,
      );
    });

    test('RTT negativo o mayor a 300 no es confiable', () {
      expect(
        const ClockSyncMeasurement(offsetMs: 10, roundTripMs: -1).isReliable,
        isFalse,
      );
      expect(
        const ClockSyncMeasurement(offsetMs: 10, roundTripMs: 301).isReliable,
        isFalse,
      );
    });
  });
}

Map<String, dynamic> _baseSessionJson(String state) => {
  'id': 'sess-1',
  'code': 'JAM-A2B',
  'ownerId': 'user-1',
  'currentPositionMs': 0,
  'state': state,
  'maxUsers': 5,
  'createdAt': '2026-08-16T12:00:00Z',
  'expiresAt': '2026-08-16T14:00:00Z',
};
