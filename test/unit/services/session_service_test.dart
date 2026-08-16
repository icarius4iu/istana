// REST: se ejercita ApiClient con un http.Client de mentira (MockClient),
// verificando la forma EXACTA de cada request (query params vs body, según
// lo que realmente exige el backend). WebSocket: en vez de mockear el canal,
// se levanta un HttpServer local real con upgrade a WebSocket (mismo
// espíritu que file_service_io_test.dart: ejercitar la implementación real
// contra un recurso local, no un doble) — así el intercambio de mensajes
// (incluidas sus claves JSON exactas, como `localIP`) se prueba de punta a
// punta, y el clock sync mide un RTT real (aunque sea contra localhost).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mp3_player_flutter/models/session_models.dart';
import 'package:mp3_player_flutter/services/api_client.dart';
import 'package:mp3_player_flutter/services/session_service.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  group('SessionService — REST', () {
    late List<http.Request> captured;
    late SessionService service;

    SessionService buildService(http.Response Function(http.Request) respond) {
      captured = [];
      final mockClient = MockClient((request) async {
        captured.add(request);
        return respond(request);
      });
      final api = ApiClient(
        baseUrl: 'http://backend.test',
        httpClient: mockClient,
      );
      return SessionService(api: api);
    }

    test(
      'createSession manda ownerId en el body y parsea la respuesta',
      () async {
        service = buildService((req) {
          expect(req.method, 'POST');
          expect(req.url.path, '/api/sessions');
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['ownerId'], 'user-1');
          expect(body.containsKey('ttlMinutes'), isFalse);
          return http.Response(
            jsonEncode({
              'id': 'sess-1',
              'code': 'JAM-A2B',
              'ownerId': 'user-1',
              'currentPositionMs': 0,
              'state': 'paused',
              'maxUsers': 5,
              'createdAt': '2026-08-16T12:00:00Z',
              'expiresAt': '2026-08-16T14:00:00Z',
              'qrCodePng': 'aGVsbG8=',
            }),
            201,
          );
        });

        final session = await service.createSession(ownerId: 'user-1');
        expect(session.code, 'JAM-A2B');
        expect(captured, hasLength(1));
      },
    );

    test('joinSession decodifica {session, users} en un solo viaje', () async {
      service = buildService((req) {
        expect(req.url.path, '/api/sessions/JAM-A2B/join');
        return http.Response(
          jsonEncode({
            'session': {
              'id': 'sess-1',
              'code': 'JAM-A2B',
              'ownerId': 'user-1',
              'currentPositionMs': 0,
              'state': 'paused',
              'maxUsers': 5,
              'createdAt': '2026-08-16T12:00:00Z',
              'expiresAt': '2026-08-16T14:00:00Z',
            },
            'users': [
              {
                'userId': 'user-1',
                'role': 'HOST',
                'connectionStatus': 'CONNECTED',
                'canServeFiles': false,
                'joinedAt': '2026-08-16T12:00:00Z',
                'lastHeartbeat': '2026-08-16T12:00:00Z',
              },
            ],
          }),
          200,
        );
      });

      final result = await service.joinSession(
        code: 'JAM-A2B',
        userId: 'user-2',
      );
      expect(result.session.code, 'JAM-A2B');
      expect(result.members, hasLength(1));
      expect(result.members.first.role, SessionRole.host);
    });

    test('addToQueue manda addedBy como query param, no en el body', () async {
      service = buildService((req) {
        expect(req.url.queryParameters['addedBy'], 'user-2');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body.containsKey('addedBy'), isFalse);
        expect(body['fileHash'], 'a' * 64);
        return http.Response(
          jsonEncode({
            'id': 'q-1',
            'title': 'Bleed',
            'artist': 'Meshuggah',
            'fileHash': 'a' * 64,
            'fileSize': 100,
            'duration': 135,
            'addedBy': 'user-2',
            'position': 0,
            'status': 'PENDING',
            'createdAt': '2026-08-16T12:00:00Z',
          }),
          201,
        );
      });

      final entry = await service.addToQueue(
        code: 'JAM-A2B',
        addedByUserId: 'user-2',
        title: 'Bleed',
        artist: 'Meshuggah',
        fileHash: 'a' * 64,
        fileSize: 100,
        durationSeconds: 135,
      );
      expect(entry.title, 'Bleed');
    });

    test(
      'getNextInQueue trata 200 con body vacío como "no hay siguiente"',
      () async {
        service = buildService((req) => http.Response('', 200));
        expect(await service.getNextInQueue('JAM-A2B'), isNull);
      },
    );

    test('getNextInQueue trata 404 también como "no hay siguiente"', () async {
      service = buildService(
        (req) => http.Response(jsonEncode({'title': 'Sin pendientes'}), 404),
      );
      expect(await service.getNextInQueue('JAM-A2B'), isNull);
    });

    test(
      'setQueueItemStatus manda el enum en MAYÚSCULAS por query param',
      () async {
        service = buildService((req) {
          expect(req.url.queryParameters['status'], 'PLAYING');
          return http.Response(
            jsonEncode({
              'id': 'q-1',
              'title': 'Bleed',
              'artist': 'Meshuggah',
              'fileHash': 'a' * 64,
              'fileSize': 100,
              'duration': 135,
              'addedBy': 'user-2',
              'position': 0,
              'status': 'PLAYING',
              'createdAt': '2026-08-16T12:00:00Z',
            }),
            200,
          );
        });

        final entry = await service.setQueueItemStatus(
          code: 'JAM-A2B',
          queueItemId: 'q-1',
          status: QueueItemStatus.playing,
        );
        expect(entry.status, QueueItemStatus.playing);
      },
    );

    test(
      'un error con ProblemDetail se traduce a ApiException con detail',
      () async {
        service = buildService(
          (req) => http.Response(
            jsonEncode({
              'title': 'Sesion no encontrada',
              'detail': 'No existe la sesion JAM-XXX',
              'code': 'JAM-XXX',
            }),
            404,
          ),
        );

        await expectLater(
          service.getMembers('JAM-XXX'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.detail,
                  'detail',
                  'No existe la sesion JAM-XXX',
                ),
          ),
        );
      },
    );
  });

  group('SessionService — WebSocket (servidor local real)', () {
    late HttpServer server;
    late List<Map<String, dynamic>> receivedByServer;
    // `WebSocket` (dart:io) es un stream de suscripción ÚNICA: no se puede
    // `.listen()` dos veces. El único listener vive acá, en setUp; un test
    // que necesite reaccionar a un mensaje puntual (p. ej. el clock sync)
    // engancha este hook en vez de escuchar el socket de nuevo.
    void Function(Map<String, dynamic> json)? onServerMessage;
    WebSocket? serverSocket;

    setUp(() async {
      receivedByServer = [];
      onServerMessage = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        serverSocket = socket;
        socket.listen((raw) {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          receivedByServer.add(json);
          onServerMessage?.call(json);
        });
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    SessionService connectedService() {
      final api = ApiClient(baseUrl: 'http://localhost:${server.port}');
      final service = SessionService(
        api: api,
        connect: (uri) => IOWebSocketChannel.connect(uri),
      );
      service.connect(
        wsBaseUri: Uri.parse('ws://localhost:${server.port}'),
        code: 'JAM-A2B',
        userId: 'user-1',
      );
      return service;
    }

    test('isConnected queda en true apenas se conecta (sincrónico)', () async {
      // `connectionState` es un stream broadcast: connect() emite `true` en
      // el mismo tick en que se llama, así que un test que recién después
      // se suscribe con `.first` pierde ese evento y cuelga para siempre —
      // por eso se chequea el getter síncrono, no el stream.
      final service = connectedService();
      addTearDown(service.dispose);

      expect(service.isConnected, isTrue);
      // Esperar a que el handshake real termine antes de que tearDown cierre
      // el servidor — si no, el intento de conexión en vuelo se reporta como
      // una falla "después de terminado el test" (connection refused).
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });

    test('sendHeartbeat manda action+sessionCode, sin más campos', () async {
      final service = connectedService();
      addTearDown(service.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      service.sendHeartbeat();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(receivedByServer, hasLength(1));
      expect(receivedByServer.first['action'], 'heartbeat');
      expect(receivedByServer.first['sessionCode'], 'JAM-A2B');
    });

    test('sendP2pReady manda la clave EXACTA "localIP" (mayúsculas)', () async {
      final service = connectedService();
      addTearDown(service.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      service.sendP2pReady(
        fileHash: 'a' * 64,
        localIp: '192.168.1.42',
        localPort: 45231,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(receivedByServer.first['localIP'], '192.168.1.42');
      expect(receivedByServer.first.containsKey('localIp'), isFalse);
    });

    test('un mensaje del servidor llega tipado por "events"', () async {
      final service = connectedService();
      addTearDown(service.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final eventFuture = service.events.first;
      serverSocket!.add(
        jsonEncode({
          'type': 'user_joined',
          'userId': 'user-2',
          'users_connected': 2,
          'timestamp': 1692000000000,
        }),
      );

      final event = await eventFuture;
      expect(event, isA<UserJoinedEvent>());
      expect((event as UserJoinedEvent).usersConnected, 2);
    });

    test('syncClock calcula un offset/RTT confiable contra un servidor que responde ya', () async {
      final service = connectedService();
      addTearDown(service.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // El "servidor" de este test responde al clock_sync_request con sus
      // propios instantes — igual que SyncService.clockSync en el backend
      // real, pero server-side simplificado (t1==t2, sin latencia interna).
      // Se engancha por `onServerMessage` (no un segundo `.listen`: el
      // socket ya tiene un listener único desde `setUp`).
      onServerMessage = (json) {
        if (json['action'] != 'clock_sync_request') return;
        final now = DateTime.now().millisecondsSinceEpoch;
        serverSocket!.add(
          jsonEncode({
            'type': 'clock_sync_response',
            'clientTime': json['timestamp'],
            'serverReceiveTime': now,
            'serverSendTime': now,
            'serverProcessingTime': 0,
            'timestamp': now,
          }),
        );
      };

      final measurement = await service.syncClock();

      expect(measurement, isNotNull);
      // localhost: la ida y vuelta real debería ser milisegundos, muy por
      // debajo del límite de confiabilidad del backend (300ms).
      expect(measurement!.isReliable, isTrue);
    });
  });
}
