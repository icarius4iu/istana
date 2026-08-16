import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../config/env.dart';
import '../models/session_models.dart';
import '../models/song.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/p2p_transfer_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import 'library_provider.dart';
import 'player_provider.dart';

/// Orquesta una jam session: login, crear/unirse, cola compartida y
/// reproducción sincronizada — enlazando [AuthService]/[SessionService] (red)
/// con [PlayerProvider]/[LibraryProvider] (reproducción local), igual que
/// `PlayerProvider.onDurationResolved` enlaza con `LibraryProvider`.
///
/// Un ítem de la cola se reproduce directo si el dispositivo YA tiene el
/// archivo localmente (`LibraryProvider.getSongById(fileHash)` — `Song.id`
/// es el hash SHA-256, el mismo identificador que usa el backend); si no,
/// se pide por transferencia P2P (`_requestFileP2p`, ver
/// `P2pTransferService`) a algún otro miembro conectado que sí lo tenga —
/// el backend solo coordina el `IP:puerto`, el audio viaja directo entre
/// dispositivos de la misma red local. La cola no tiene push por WebSocket
/// (solo REST, ver `SessionService`), así que se pollea periódicamente y
/// también se refresca ante eventos del socket.
class SessionProvider extends ChangeNotifier {
  final AuthService _auth;
  final SessionService _sessionService;
  final PlayerProvider _playerProvider;
  final LibraryProvider _libraryProvider;
  final ApiClient _apiClient;
  final StorageService _storage;
  final P2pTransferService _p2p;

  StreamSubscription<SessionServerEvent>? _eventsSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _heartbeatTimer;
  Timer? _queuePollTimer;
  Timer? _playScheduleTimer;

  JamSession? _session;
  List<SessionMember> _members = const [];
  List<QueueEntry> _queue = const [];
  ClockSyncMeasurement? _clockSync;
  String? _errorMessage;
  bool _isBusy = false;
  bool _isConnected = false;

  // Endpoint propio anunciado por p2p_ready, para responder de nuevo cuando
  // el backend nos elige como host de un p2p_offer (ver _onServerEvent).
  String? _localP2pIp;
  int? _localP2pPort;
  final Set<String> _downloadingHashes = {};

  SessionProvider({
    required AuthService auth,
    required SessionService sessionService,
    required PlayerProvider playerProvider,
    required LibraryProvider libraryProvider,
    required ApiClient apiClient,
    required StorageService storage,
    required P2pTransferService p2p,
  }) : _auth = auth,
       _sessionService = sessionService,
       _playerProvider = playerProvider,
       _libraryProvider = libraryProvider,
       _apiClient = apiClient,
       _storage = storage,
       _p2p = p2p {
    _eventsSub = _sessionService.events.listen(_onServerEvent);
    _connectionSub = _sessionService.connectionState.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });
  }

  // ===== GETTERS =====

  AuthUser? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.isLoggedIn;
  JamSession? get session => _session;
  bool get hasActiveSession => _session != null;
  List<SessionMember> get members => List.unmodifiable(_members);
  List<QueueEntry> get queue => List.unmodifiable(_queue);
  bool get isConnected => _isConnected;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  ClockSyncMeasurement? get clockSync => _clockSync;

  String get serverUrl => _apiClient.baseUrl;

  Future<void> setServerUrl(String url) async {
    _apiClient.baseUrl = url;
    await _storage.setServerBaseUrl(url);
    notifyListeners();
  }

  // ===== AUTH =====

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) => _guard(() async {
    await _auth.register(username: username, email: email, password: password);
    await _auth.login(username: username, password: password);
  });

  Future<bool> login({required String username, required String password}) =>
      _guard(() => _auth.login(username: username, password: password));

  Future<void> logout() async {
    await leaveSession();
    await _auth.logout();
    notifyListeners();
  }

  // ===== SESIÓN =====

  Future<bool> createSession() => _guard(() async {
    final user = _requireUser();
    final created = await _sessionService.createSession(ownerId: user.id);
    await _enterSession(created.code);
  });

  Future<bool> joinSession(String code) => _guard(() async {
    _requireUser();
    await _enterSession(code.trim().toUpperCase());
  });

  AuthUser _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Tenés que iniciar sesión primero');
    }
    return user;
  }

  Future<void> _enterSession(String code) async {
    final user = _requireUser();
    final joined = await _sessionService.joinSession(
      code: code,
      userId: user.id,
    );
    _session = joined.session;
    _members = joined.members;
    _sessionService.connect(
      wsBaseUri: _wsUriFromApiBaseUrl(),
      code: code,
      userId: user.id,
    );
    await _refreshQueue();
    _startTimers();
    notifyListeners();
    unawaited(_runClockSync());
    unawaited(_startP2pServing());
  }

  /// Abre el servidor TCP local que sirve archivos a otros miembros (ver
  /// `P2pTransferService`) y anuncia el endpoint (`p2p_ready`) para quedar
  /// "CONNECTED" — condición que exige el backend para ser elegido como
  /// fuente de CUALQUIER pedido P2P (no valida el hash en el momento de
  /// elegir, ver el mapa de integración), así que alcanza con anunciar una
  /// vez con cualquier canción propia. Si la biblioteca está vacía no hay
  /// nada que anunciar todavía; igual el servidor queda escuchando por si
  /// se agrega música más tarde.
  Future<void> _startP2pServing() async {
    if (!Env.canP2pTransfer) return;

    final port = await _p2p.startServing(
      resolveLocalPath: (hash) async =>
          _libraryProvider.getSongById(hash)?.path,
    );
    if (port == null) return;
    final ip = await _p2p.localIpAddress();
    if (ip == null) return;

    _localP2pIp = ip;
    _localP2pPort = port;

    if (_libraryProvider.songs.isEmpty) return;
    _sessionService.sendP2pReady(
      fileHash: _libraryProvider.songs.first.hash,
      localIp: ip,
      localPort: port,
    );
  }

  Uri _wsUriFromApiBaseUrl() {
    final httpUri = Uri.parse(_apiClient.baseUrl);
    return httpUri.replace(scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
  }

  Future<void> _runClockSync() async {
    if (!_sessionService.isConnected) {
      await _sessionService.connectionState.firstWhere((c) => c);
    }
    _clockSync = await _sessionService.syncClock();
    notifyListeners();
  }

  Future<void> leaveSession() async {
    final user = _auth.currentUser;
    final session = _session;
    _stopTimers();
    _sessionService.disconnect();
    unawaited(_p2p.stopServing());
    if (user != null && session != null) {
      try {
        await _sessionService.leaveSession(code: session.code, userId: user.id);
      } catch (_) {
        // Best-effort: si falla la salida remota igual limpiamos el estado
        // local — el barrido de latidos silenciosos del backend termina de
        // expulsarnos solo.
      }
    }
    _session = null;
    _members = const [];
    _queue = const [];
    _clockSync = null;
    _localP2pIp = null;
    _localP2pPort = null;
    _downloadingHashes.clear();
    notifyListeners();
  }

  Future<void> refreshMembers() async {
    final session = _session;
    if (session == null) return;
    try {
      _members = await _sessionService.getMembers(session.code);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = '$e';
      notifyListeners();
    }
  }

  // ===== COLA COMPARTIDA =====

  Future<bool> addSongToQueue(Song song) => _guard(() async {
    final user = _requireUser();
    final session = _session;
    if (session == null) throw StateError('No hay sesión activa');
    await _sessionService.addToQueue(
      code: session.code,
      addedByUserId: user.id,
      title: song.title,
      artist: song.artist,
      album: song.album.isEmpty ? null : song.album,
      fileHash: song.hash,
      fileSize: song.fileSize,
      durationSeconds: song.duration,
    );
    await _refreshQueue();
  });

  Future<void> _refreshQueue() async {
    final session = _session;
    if (session == null) return;
    _queue = await _sessionService.getQueue(session.code);
    notifyListeners();
  }

  /// Avanza la cola: toma la siguiente pendiente, la marca `PLAYING` (así
  /// los demás miembros la descubren por REST) y dispara la reproducción
  /// sincronizada. Si el archivo no está en la biblioteca local, la
  /// avanzamos igual (para no bloquear a los demás miembros que sí lo
  /// tienen) y lo pedimos por P2P en paralelo — `_ensureCurrentSongLoaded`
  /// lo carga solo apenas termine de bajar, y la corrección de deriva por
  /// heartbeat nos vuelve a poner en fase con el resto.
  Future<bool> advanceQueue() => _guard(() async {
    final session = _session;
    if (session == null) throw StateError('No hay sesión activa');

    final next = await _sessionService.getNextInQueue(session.code);
    if (next == null) throw StateError('La cola compartida está vacía');

    await _sessionService.setQueueItemStatus(
      code: session.code,
      queueItemId: next.id,
      status: QueueItemStatus.playing,
    );

    final song = _libraryProvider.getSongById(next.fileHash);
    if (song != null) {
      await _playerProvider.loadQueue([song], autoPlay: false);
    } else {
      unawaited(_requestFileP2p(next));
    }
    _sessionService.sendPlay();
    await _refreshQueue();
  });

  /// Play/pausa sobre lo que ya está sonando/cargado; si todavía no hay
  /// nada cargado, avanza la cola.
  Future<void> togglePlayPause() async {
    if (_playerProvider.currentSong == null) {
      await advanceQueue();
      return;
    }
    if (_session?.state == JamPlaybackState.playing) {
      _sessionService.sendPause(
        positionMs: _playerProvider.currentPosition.inMilliseconds,
      );
    } else {
      _sessionService.sendPlay(
        positionMs: _playerProvider.currentPosition.inMilliseconds,
      );
    }
  }

  void seekTo(Duration position) =>
      _sessionService.sendSeek(position.inMilliseconds);

  /// Precarga (en pausa) el ítem `PLAYING` de la cola si todavía no es la
  /// canción actual del reproductor — para que, cuando llegue la cita de
  /// reproducción por WebSocket, solo haga falta hacer seek + play en el
  /// instante exacto, sin depender de cuánto tarde en cargar el archivo.
  /// Si el archivo no está local, dispara (o deja seguir) su descarga P2P.
  Future<void> _ensureCurrentSongLoaded() async {
    QueueEntry? playingEntry;
    for (final entry in _queue) {
      if (entry.status == QueueItemStatus.playing) {
        playingEntry = entry;
        break;
      }
    }
    if (playingEntry == null) return;
    if (_playerProvider.currentSong?.hash == playingEntry.fileHash) return;

    final song = _libraryProvider.getSongById(playingEntry.fileHash);
    if (song != null) {
      await _playerProvider.loadQueue([song], autoPlay: false);
      return;
    }
    unawaited(_requestFileP2p(playingEntry));
  }

  /// `true` mientras se está bajando [fileHash] de otro miembro — la UI
  /// (`QueueEntryTile`) lo usa para mostrar "descargando…" en vez del error
  /// genérico "no está en tu biblioteca".
  bool isDownloading(String fileHash) => _downloadingHashes.contains(fileHash);

  /// Le pide el archivo a quien lo tenga conectado en la sesión (señalización
  /// `p2p_request` → `p2p_ready` → conexión TCP directa, ver
  /// `P2pTransferService`) y, si llega, lo agrega a la biblioteca local y
  /// reintenta cargarlo. Sin novedad si ya hay una descarga en curso para
  /// ese mismo hash — el próximo poll de cola la vuelve a intentar sola si
  /// esta falla (no hay reintento inmediato para no saturar al host).
  Future<void> _requestFileP2p(QueueEntry entry) async {
    if (!Env.canP2pTransfer) {
      _errorMessage =
          'Este dispositivo no puede recibir transferencias P2P (Web)';
      notifyListeners();
      return;
    }
    if (_downloadingHashes.contains(entry.fileHash)) return;

    _downloadingHashes.add(entry.fileHash);
    notifyListeners();

    final readyCompleter = Completer<P2pReadyEvent>();
    final sub = _sessionService.events.listen((event) {
      if (event is P2pReadyEvent &&
          event.fileHash == entry.fileHash &&
          !readyCompleter.isCompleted) {
        readyCompleter.complete(event);
      }
    });

    try {
      _sessionService.sendP2pRequest(
        fileHash: entry.fileHash,
        fileName: entry.title,
        fileSize: entry.fileSize,
      );

      final ready = await readyCompleter.future.timeout(
        AppConstants.p2pRequestTimeout,
      );
      final destPath = await _p2p.resolveDownloadDestination(entry.fileHash);
      await _p2p.downloadFrom(
        hostIp: ready.hostIp,
        hostPort: ready.hostPort,
        fileHash: entry.fileHash,
        expectedFileSize: entry.fileSize,
        destPath: destPath,
        onProgress: (received, total) => _sessionService.sendTransferProgress(
          fileHash: entry.fileHash,
          bytesSent: received,
          totalBytes: total,
        ),
      );

      await _libraryProvider.addSong(
        Song(
          id: entry.fileHash,
          path: destPath,
          title: entry.title,
          artist: entry.artist,
          album: entry.album ?? '',
          duration: entry.durationSeconds,
          hash: entry.fileHash,
          fileSize: entry.fileSize,
          dateAdded: DateTime.now(),
        ),
      );
      unawaited(_ensureCurrentSongLoaded());
    } on TimeoutException {
      _errorMessage =
          'Nadie pudo enviarte "${entry.title}" (¿están en la misma red?)';
    } catch (e) {
      _errorMessage = 'No se pudo descargar "${entry.title}": $e';
    } finally {
      await sub.cancel();
      _downloadingHashes.remove(entry.fileHash);
      notifyListeners();
    }
  }

  // ===== EVENTOS DEL WEBSOCKET =====

  void _onServerEvent(SessionServerEvent event) {
    switch (event) {
      case StateChangedEvent e:
        // El backend no reemite la sesión entera acá, solo el delta: sin
        // este copyWith, togglePlayPause() (y el ícono play/pausa de la UI)
        // quedarían leyendo para siempre el estado de cuando se entró.
        _session = _session?.copyWith(
          state: e.state,
          currentPositionMs: e.positionMs,
          currentSongId: e.currentSongId,
        );
        _errorMessage = null;
        if (e.state == JamPlaybackState.paused) {
          // "pause" nunca emite play_scheduled (a diferencia de "play"): es
          // este mensaje, y no otro, el que tiene que pausar el audio local
          // — sin esto la sesión decía "en pausa" pero seguía sonando. Un
          // seek mientras está pausada tampoco emite cita (solo actualiza
          // la posición), así que también hay que aplicarlo acá.
          _playScheduleTimer?.cancel();
          unawaited(_pauseAndSeek(e.positionMs));
        }
        unawaited(_refreshQueue().then((_) => _ensureCurrentSongLoaded()));
        notifyListeners();
        break;
      case PlayScheduledEvent e:
        _schedulePlayback(e);
        break;
      case UserJoinedEvent _:
        unawaited(refreshMembers());
        unawaited(_refreshQueue());
        break;
      case SessionHeartbeatEvent e:
        if (e.positionMs != null) _correctDrift(e.positionMs!);
        notifyListeners();
        break;
      case SessionErrorEvent e:
        _errorMessage = e.message;
        notifyListeners();
        break;
      case ClockSyncResponseEvent _:
        break; // consumido internamente por SessionService.syncClock()
      case P2pOfferEvent e:
        _respondToP2pOffer(e);
        break;
      case P2pReadyEvent _:
        break; // consumido por la suscripción propia de _requestFileP2p
      case UnknownSessionEvent _:
        break;
    }
  }

  void _schedulePlayback(PlayScheduledEvent event) {
    _playScheduleTimer?.cancel();
    final offset = _clockSync?.offsetMs ?? 0;
    final localPlayAtMs = event.playAtUnixTimestampMs - offset;
    final delayMs = localPlayAtMs - DateTime.now().millisecondsSinceEpoch;
    final delay = Duration(milliseconds: delayMs < 0 ? 0 : delayMs);

    _playScheduleTimer = Timer(delay, () {
      unawaited(_fireScheduledPlayback(event.positionMs));
    });
    notifyListeners();
  }

  Future<void> _fireScheduledPlayback(int positionMs) async {
    await _ensureCurrentSongLoaded();
    await _playerProvider.seek(Duration(milliseconds: positionMs));
    await _playerProvider.play();
  }

  /// Pausa y ajusta la posición, en ese orden (evita la carrera de disparar
  /// las dos operaciones async en paralelo) — reacción a un `state_changed`
  /// que deja la sesión pausada, sea por un "pause" o por un "seek" sin
  /// reproducir.
  Future<void> _pauseAndSeek(int positionMs) async {
    await _playerProvider.pause();
    await _playerProvider.seek(Duration(milliseconds: positionMs));
  }

  /// El servidor nos eligió como fuente (`hostId == yo`) para el hash que
  /// alguien pidió. Si de verdad lo tenemos, reconfirmamos el endpoint con
  /// ESE hash exacto (la primera vez que anunciamos `p2p_ready`, en
  /// `_startP2pServing`, fue con cualquier canción propia solo para
  /// quedar "CONNECTED" — esto lo deja preciso para este pedido puntual).
  void _respondToP2pOffer(P2pOfferEvent event) {
    final ip = _localP2pIp;
    final port = _localP2pPort;
    if (ip == null || port == null) return;
    if (event.hostUserId != currentUser?.id) return;
    if (_libraryProvider.getSongById(event.fileHash) == null) return;

    _sessionService.sendP2pReady(
      fileHash: event.fileHash,
      localIp: ip,
      localPort: port,
    );
  }

  /// El heartbeat difundido trae la posición esperada, calculada del lado
  /// del servidor (`SyncService.expectedPositionMs`); si nos alejamos más
  /// de `driftToleranceMs` se corrige con un seek — igual que el propio
  /// backend, corregir por menos produce saltos audibles.
  void _correctDrift(int serverPositionMs) {
    if (!_playerProvider.isPlaying) return;
    final localMs = _playerProvider.currentPosition.inMilliseconds;
    if ((serverPositionMs - localMs).abs() > AppConstants.driftToleranceMs) {
      unawaited(_playerProvider.seek(Duration(milliseconds: serverPositionMs)));
    }
  }

  // ===== TIMERS =====

  void _startTimers() {
    _heartbeatTimer = Timer.periodic(
      AppConstants.sessionHeartbeatInterval,
      (_) => _sessionService.sendHeartbeat(),
    );
    _queuePollTimer = Timer.periodic(
      AppConstants.sessionQueuePollInterval,
      (_) => unawaited(_refreshQueue().then((_) => _ensureCurrentSongLoaded())),
    );
  }

  void _stopTimers() {
    _heartbeatTimer?.cancel();
    _queuePollTimer?.cancel();
    _playScheduleTimer?.cancel();
    _heartbeatTimer = null;
    _queuePollTimer = null;
    _playScheduleTimer = null;
  }

  // ===== HELPERS =====

  Future<bool> _guard(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _errorMessage = '$e';
      return false;
    } catch (e) {
      _errorMessage = '$e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimers();
    _eventsSub?.cancel();
    _connectionSub?.cancel();
    unawaited(_sessionService.dispose());
    unawaited(_p2p.stopServing());
    super.dispose();
  }
}
