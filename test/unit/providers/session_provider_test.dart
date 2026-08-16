// SessionProvider enlaza AuthService/SessionService (red) con
// PlayerProvider/LibraryProvider (reproducción local): se prueba con las
// cuatro dependencias de mentira (mocktail), igual que player_provider_test
// mockea AudioService/StorageService — StreamController.broadcast simula
// los eventos del WebSocket.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mp3_player_flutter/models/session_models.dart';
import 'package:mp3_player_flutter/models/song.dart';
import 'package:mp3_player_flutter/providers/library_provider.dart';
import 'package:mp3_player_flutter/providers/player_provider.dart';
import 'package:mp3_player_flutter/providers/session_provider.dart';
import 'package:mp3_player_flutter/services/api_client.dart';
import 'package:mp3_player_flutter/services/auth_service.dart';
import 'package:mp3_player_flutter/services/p2p_transfer_service.dart';
import 'package:mp3_player_flutter/services/session_service.dart';
import 'package:mp3_player_flutter/services/storage_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockSessionService extends Mock implements SessionService {}

class MockPlayerProvider extends Mock implements PlayerProvider {}

class MockLibraryProvider extends Mock implements LibraryProvider {}

class MockStorageService extends Mock implements StorageService {}

class MockP2pTransferService extends Mock implements P2pTransferService {}

Song _song(String hash) => Song(
  id: hash,
  path: '/music/$hash.mp3',
  title: 'Song $hash',
  artist: 'Artist',
  album: 'Album',
  duration: 200,
  hash: hash,
  fileSize: 100,
  dateAdded: DateTime(2026, 1, 1),
);

const _user = AuthUser(id: 'user-1', username: 'ana');

QueueEntry _queueEntry({
  required String id,
  required String fileHash,
  QueueItemStatus status = QueueItemStatus.pending,
}) => QueueEntry(
  id: id,
  title: 'Bleed',
  artist: 'Meshuggah',
  fileHash: fileHash,
  fileSize: 100,
  durationSeconds: 135,
  addedBy: 'user-1',
  position: 0,
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockAuthService auth;
  late MockSessionService sessionService;
  late MockPlayerProvider playerProvider;
  late MockLibraryProvider libraryProvider;
  late MockStorageService storage;
  late MockP2pTransferService p2p;
  late ApiClient apiClient;
  late StreamController<SessionServerEvent> eventsController;
  late StreamController<bool> connectionController;

  setUpAll(() {
    registerFallbackValue(_song('fallback'));
    registerFallbackValue(QueueItemStatus.pending);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Uri.parse('http://fallback.test'));
  });

  setUp(() {
    auth = MockAuthService();
    sessionService = MockSessionService();
    playerProvider = MockPlayerProvider();
    libraryProvider = MockLibraryProvider();
    storage = MockStorageService();
    p2p = MockP2pTransferService();
    apiClient = ApiClient(baseUrl: 'http://backend.test');

    eventsController = StreamController<SessionServerEvent>.broadcast();
    connectionController = StreamController<bool>.broadcast();

    when(() => sessionService.events)
        .thenAnswer((_) => eventsController.stream);
    when(() => sessionService.connectionState)
        .thenAnswer((_) => connectionController.stream);
    when(() => sessionService.isConnected).thenReturn(true);
    when(
      () => sessionService.connect(
        wsBaseUri: any(named: 'wsBaseUri'),
        code: any(named: 'code'),
        userId: any(named: 'userId'),
      ),
    ).thenReturn(null);
    when(() => sessionService.disconnect()).thenReturn(null);
    when(() => sessionService.sendPlay(positionMs: any(named: 'positionMs')))
        .thenReturn(null);
    when(() => sessionService.sendPause(positionMs: any(named: 'positionMs')))
        .thenReturn(null);
    when(() => sessionService.sendSeek(any())).thenReturn(null);
    when(() => sessionService.dispose()).thenAnswer((_) async {});
    when(() => sessionService.syncClock()).thenAnswer(
      (_) async => const ClockSyncMeasurement(offsetMs: 0, roundTripMs: 5),
    );
    when(() => sessionService.getQueue(any()))
        .thenAnswer((_) async => const []);
    when(() => sessionService.getMembers(any()))
        .thenAnswer((_) async => const []);

    when(() => auth.currentUser).thenReturn(_user);
    when(() => auth.isLoggedIn).thenReturn(true);

    when(() => playerProvider.currentSong).thenReturn(null);
    when(() => playerProvider.currentPosition).thenReturn(Duration.zero);
    when(() => playerProvider.isPlaying).thenReturn(false);
    when(
      () => playerProvider.loadQueue(
        any(),
        startIndex: any(named: 'startIndex'),
        autoPlay: any(named: 'autoPlay'),
      ),
    ).thenAnswer((_) async {});
    when(() => playerProvider.seek(any())).thenAnswer((_) async {});
    when(() => playerProvider.play()).thenAnswer((_) async {});

    when(() => libraryProvider.getSongById(any())).thenReturn(null);
    when(() => libraryProvider.songs).thenReturn(const []);
    when(() => libraryProvider.addSong(any())).thenAnswer((_) async {});

    // Por defecto, "sin P2P disponible" (como si no hubiera nada que
    // anunciar todavía) — los tests que sí ejercitan la descarga lo
    // sobreescriben explícitamente.
    when(
      () => p2p.startServing(resolveLocalPath: any(named: 'resolveLocalPath')),
    ).thenAnswer((_) async => null);
    when(() => p2p.stopServing()).thenAnswer((_) async {});
    when(() => p2p.localIpAddress()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await eventsController.close();
    await connectionController.close();
  });

  SessionProvider build() => SessionProvider(
    auth: auth,
    sessionService: sessionService,
    playerProvider: playerProvider,
    libraryProvider: libraryProvider,
    apiClient: apiClient,
    storage: storage,
    p2p: p2p,
  );

  group('auth', () {
    test('login exitoso deja isBusy en false y sin error', () async {
      when(
        () => auth.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _user);

      final provider = build();
      final ok = await provider.login(username: 'ana', password: 'secreta1');

      expect(ok, isTrue);
      expect(provider.isBusy, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test(
      'login fallido (ApiException) deja el mensaje en errorMessage',
      () async {
        when(
          () => auth.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(401, detail: 'Usuario o contrasena incorrectos'),
        );

        final provider = build();
        final ok = await provider.login(username: 'ana', password: 'mala');

        expect(ok, isFalse);
        expect(provider.errorMessage, contains('incorrectos'));
      },
    );
  });

  group('crear / unirse a sesión', () {
    test('createSession conecta el WS y corre el clock sync', () async {
      when(() => sessionService.createSession(ownerId: any(named: 'ownerId')))
          .thenAnswer(
            (_) async => JamSession(
              id: 's1',
              code: 'JAM-A2B',
              ownerId: 'user-1',
              currentPositionMs: 0,
              state: JamPlaybackState.paused,
              maxUsers: 5,
              createdAt: DateTime(2026, 1, 1),
              expiresAt: DateTime(2026, 1, 1, 2),
            ),
          );
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.paused,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );

      final provider = build();
      addTearDown(provider.dispose);

      final ok = await provider.createSession();
      await _settle();

      expect(ok, isTrue);
      expect(provider.hasActiveSession, isTrue);
      expect(provider.session?.code, 'JAM-A2B');
      verify(
        () => sessionService.connect(
          wsBaseUri: any(named: 'wsBaseUri'),
          code: 'JAM-A2B',
          userId: 'user-1',
        ),
      ).called(1);
      verify(() => sessionService.syncClock()).called(1);
    });

    test(
      'sin usuario logueado, createSession falla sin llamar al backend',
      () async {
        when(() => auth.currentUser).thenReturn(null);
        when(() => auth.isLoggedIn).thenReturn(false);

        final provider = build();
        final ok = await provider.createSession();

        expect(ok, isFalse);
        expect(provider.errorMessage, isNotNull);
        verifyNever(
          () => sessionService.createSession(ownerId: any(named: 'ownerId')),
        );
      },
    );
  });

  group('cola compartida', () {
    test(
      'addSongToQueue manda los campos del Song y refresca la cola',
      () async {
        when(
          () => sessionService.addToQueue(
            code: any(named: 'code'),
            addedByUserId: any(named: 'addedByUserId'),
            title: any(named: 'title'),
            artist: any(named: 'artist'),
            album: any(named: 'album'),
            fileHash: any(named: 'fileHash'),
            fileSize: any(named: 'fileSize'),
            durationSeconds: any(named: 'durationSeconds'),
          ),
        ).thenAnswer((_) async => _queueEntry(id: 'q1', fileHash: 'hash1'));

        final provider = build();
        // El provider exige sesión activa: se fuerza estado interno vía
        // createSession simulada más simple: reutilizamos joinSession.
        when(
          () => sessionService.joinSession(
            code: any(named: 'code'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => (
            session: JamSession(
              id: 's1',
              code: 'JAM-A2B',
              ownerId: 'user-1',
              currentPositionMs: 0,
              state: JamPlaybackState.paused,
              maxUsers: 5,
              createdAt: DateTime(2026, 1, 1),
              expiresAt: DateTime(2026, 1, 1, 2),
            ),
            members: <SessionMember>[],
          ),
        );
        await provider.joinSession('jam-a2b');
        await _settle();

        final song = _song('hash1');
        final ok = await provider.addSongToQueue(song);

        expect(ok, isTrue);
        verify(
          () => sessionService.addToQueue(
            code: 'JAM-A2B',
            addedByUserId: 'user-1',
            title: song.title,
            artist: song.artist,
            album: song.album,
            fileHash: 'hash1',
            fileSize: song.fileSize,
            durationSeconds: song.duration,
          ),
        ).called(1);
      },
    );

    test('advanceQueue con archivo faltante avanza igual (no bloquea a los '
        'demás) y dispara el pedido P2P', () async {
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.paused,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );
      final entry = _queueEntry(id: 'q1', fileHash: 'faltante');
      when(() => sessionService.getNextInQueue(any()))
          .thenAnswer((_) async => entry);
      when(() => libraryProvider.getSongById('faltante')).thenReturn(null);
      when(
        () => sessionService.setQueueItemStatus(
          code: any(named: 'code'),
          queueItemId: any(named: 'queueItemId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => entry);
      when(
        () => sessionService.sendP2pRequest(
          fileHash: any(named: 'fileHash'),
          fileName: any(named: 'fileName'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenReturn(null);

      final provider = build();
      await provider.joinSession('jam-a2b');
      await _settle();

      final ok = await provider.advanceQueue();
      await _settle();

      expect(ok, isTrue); // avanza igual: no bloquea a quien sí lo tiene
      expect(provider.isDownloading('faltante'), isTrue);
      verify(
        () => sessionService.setQueueItemStatus(
          code: 'JAM-A2B',
          queueItemId: 'q1',
          status: QueueItemStatus.playing,
        ),
      ).called(1);
      verify(
        () => sessionService.sendP2pRequest(
          fileHash: 'faltante',
          fileName: entry.title,
          fileSize: entry.fileSize,
        ),
      ).called(1);
      verify(() => sessionService.sendPlay()).called(1);
    });

    test('cuando llega el p2p_ready, se descarga el archivo y se agrega a la biblioteca', () async {
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.paused,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );
      final entry = _queueEntry(id: 'q1', fileHash: 'faltante');
      when(() => sessionService.getNextInQueue(any()))
          .thenAnswer((_) async => entry);
      when(() => libraryProvider.getSongById('faltante')).thenReturn(null);
      when(
        () => sessionService.setQueueItemStatus(
          code: any(named: 'code'),
          queueItemId: any(named: 'queueItemId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => entry);
      when(
        () => sessionService.sendP2pRequest(
          fileHash: any(named: 'fileHash'),
          fileName: any(named: 'fileName'),
          fileSize: any(named: 'fileSize'),
        ),
      ).thenReturn(null);
      when(() => p2p.resolveDownloadDestination('faltante'))
          .thenAnswer((_) async => '/tmp/faltante.mp3');
      when(
        () => p2p.downloadFrom(
          hostIp: any(named: 'hostIp'),
          hostPort: any(named: 'hostPort'),
          fileHash: any(named: 'fileHash'),
          expectedFileSize: any(named: 'expectedFileSize'),
          destPath: any(named: 'destPath'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sessionService.sendTransferProgress(
          fileHash: any(named: 'fileHash'),
          bytesSent: any(named: 'bytesSent'),
          totalBytes: any(named: 'totalBytes'),
        ),
      ).thenReturn(null);

      final provider = build();
      await provider.joinSession('jam-a2b');
      await _settle();
      await provider.advanceQueue();
      await _settle();
      expect(provider.isDownloading('faltante'), isTrue);

      eventsController.add(
        P2pReadyEvent(
          timestamp: DateTime.now(),
          hostIp: '192.168.1.5',
          hostPort: 5555,
          fileHash: 'faltante',
        ),
      );
      await _settle();
      await _settle();

      verify(
        () => p2p.downloadFrom(
          hostIp: '192.168.1.5',
          hostPort: 5555,
          fileHash: 'faltante',
          expectedFileSize: entry.fileSize,
          destPath: '/tmp/faltante.mp3',
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      verify(
        () => libraryProvider.addSong(
          any(
            that: isA<Song>()
                .having((s) => s.hash, 'hash', 'faltante')
                .having((s) => s.path, 'path', '/tmp/faltante.mp3'),
          ),
        ),
      ).called(1);
      expect(provider.isDownloading('faltante'), isFalse);
    });

    test('advanceQueue con el archivo presente: marca PLAYING, precarga en pausa y manda play', () async {
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.paused,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );
      final entry = _queueEntry(id: 'q1', fileHash: 'hash1');
      when(() => sessionService.getNextInQueue(any()))
          .thenAnswer((_) async => entry);
      when(() => libraryProvider.getSongById('hash1'))
          .thenReturn(_song('hash1'));
      when(
        () => sessionService.setQueueItemStatus(
          code: any(named: 'code'),
          queueItemId: any(named: 'queueItemId'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => entry);

      final provider = build();
      await provider.joinSession('jam-a2b');
      await _settle();

      final ok = await provider.advanceQueue();

      expect(ok, isTrue);
      verify(
        () => sessionService.setQueueItemStatus(
          code: 'JAM-A2B',
          queueItemId: 'q1',
          status: QueueItemStatus.playing,
        ),
      ).called(1);
      verify(() => playerProvider.loadQueue([_song('hash1')], autoPlay: false))
          .called(1);
      verify(() => sessionService.sendPlay()).called(1);
    });
  });

  group('eventos del servidor', () {
    Future<SessionProvider> joinedProvider() async {
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.playing,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );
      final provider = build();
      await provider.joinSession('jam-a2b');
      await _settle();
      return provider;
    }

    test(
      'PlayScheduledEvent hace seek + play en el instante programado',
      () async {
        final provider = await joinedProvider();
        addTearDown(provider.dispose);

        final now = DateTime.now().millisecondsSinceEpoch;
        eventsController.add(
          PlayScheduledEvent(
            timestamp: DateTime.now(),
            positionMs: 30000,
            playAtUnixTimestampMs: now, // ya vencida: dispara ~inmediato
            bufferMs: 0,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(() => playerProvider.seek(const Duration(milliseconds: 30000)))
            .called(1);
        verify(() => playerProvider.play()).called(1);
      },
    );

    test('StateChangedEvent actualiza session.state (sin esto, togglePlayPause '
        'queda leyendo para siempre el estado de cuando se entró)', () async {
      final provider = await joinedProvider();
      addTearDown(provider.dispose);
      expect(provider.session?.state, JamPlaybackState.playing);

      eventsController.add(
        StateChangedEvent(
          timestamp: DateTime.now(),
          state: JamPlaybackState.paused,
          positionMs: 5000,
        ),
      );
      await _settle();

      expect(provider.session?.state, JamPlaybackState.paused);
      expect(provider.session?.currentPositionMs, 5000);
    });

    test('SessionErrorEvent deja el mensaje en errorMessage', () async {
      final provider = await joinedProvider();
      addTearDown(provider.dispose);

      eventsController.add(
        SessionErrorEvent(
          timestamp: DateTime.now(),
          message: 'Accion desconocida',
        ),
      );
      await _settle();

      expect(provider.errorMessage, 'Accion desconocida');
    });

    test(
      'un heartbeat con deriva grande corrige con seek; con deriva chica no',
      () async {
        when(() => playerProvider.isPlaying).thenReturn(true);
        when(() => playerProvider.currentPosition)
            .thenReturn(const Duration(milliseconds: 1000));

        final provider = await joinedProvider();
        addTearDown(provider.dispose);

        eventsController.add(
          SessionHeartbeatEvent(
            timestamp: DateTime.now(),
            usersConnected: 2,
            positionMs: 1100, // 100ms de deriva: por debajo del umbral (250ms)
          ),
        );
        await _settle();
        verifyNever(() => playerProvider.seek(any()));

        eventsController.add(
          SessionHeartbeatEvent(
            timestamp: DateTime.now(),
            usersConnected: 2,
            positionMs: 2000, // 1000ms de deriva: por encima del umbral
          ),
        );
        await _settle();
        verify(() => playerProvider.seek(const Duration(milliseconds: 2000)))
            .called(1);
      },
    );
  });

  group('salir de la sesión', () {
    test('leaveSession desconecta el WS y limpia el estado local', () async {
      when(
        () => sessionService.joinSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => (
          session: JamSession(
            id: 's1',
            code: 'JAM-A2B',
            ownerId: 'user-1',
            currentPositionMs: 0,
            state: JamPlaybackState.paused,
            maxUsers: 5,
            createdAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2026, 1, 1, 2),
          ),
          members: <SessionMember>[],
        ),
      );
      when(
        () => sessionService.leaveSession(
          code: any(named: 'code'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      final provider = build();
      await provider.joinSession('jam-a2b');
      await _settle();
      expect(provider.hasActiveSession, isTrue);

      await provider.leaveSession();

      expect(provider.hasActiveSession, isFalse);
      verify(() => sessionService.disconnect()).called(1);
      verify(
        () => sessionService.leaveSession(code: 'JAM-A2B', userId: 'user-1'),
      ).called(1);
    });
  });
}
