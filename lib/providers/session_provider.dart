import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/session_models.dart';
import '../models/song.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import 'library_provider.dart';
import 'player_provider.dart';

/// Orquesta una jam session: login, crear/unirse, cola compartida y
/// reproducción sincronizada — enlazando [AuthService]/[SessionService] (red)
/// con [PlayerProvider]/[LibraryProvider] (reproducción local), igual que
/// `PlayerProvider.onDurationResolved` enlaza con `LibraryProvider`.
///
/// Diseño de v1 (sin transferencia P2P de archivos todavía — la
/// señalización se registra pero el transporte de bytes es v2): un ítem de
/// la cola solo se puede reproducir si el dispositivo YA tiene el archivo
/// localmente (`LibraryProvider.getSongById(fileHash)` — `Song.id` es el
/// hash SHA-256, el mismo identificador que usa el backend). La cola no
/// tiene push por WebSocket (solo REST, ver `SessionService`), así que se
/// pollea periódicamente y también se refresca ante eventos del socket.
class SessionProvider extends ChangeNotifier {
  final AuthService _auth;
  final SessionService _sessionService;
  final PlayerProvider _playerProvider;
  final LibraryProvider _libraryProvider;
  final ApiClient _apiClient;
  final StorageService _storage;

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

  SessionProvider({
    required AuthService auth,
    required SessionService sessionService,
    required PlayerProvider playerProvider,
    required LibraryProvider libraryProvider,
    required ApiClient apiClient,
    required StorageService storage,
  }) : _auth = auth,
       _sessionService = sessionService,
       _playerProvider = playerProvider,
       _libraryProvider = libraryProvider,
       _apiClient = apiClient,
       _storage = storage {
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
  /// sincronizada. Si el archivo no está en la biblioteca local, informa el
  /// error en vez de intentar reproducir algo que no existe (la
  /// transferencia P2P que resolvería esto es v2).
  Future<bool> advanceQueue() => _guard(() async {
    final session = _session;
    if (session == null) throw StateError('No hay sesión activa');

    final next = await _sessionService.getNextInQueue(session.code);
    if (next == null) throw StateError('La cola compartida está vacía');

    final song = _libraryProvider.getSongById(next.fileHash);
    if (song == null) {
      throw StateError(
        'Todavía no tenés "${next.title}" en tu biblioteca (la transferencia '
        'entre dispositivos llega en una próxima versión)',
      );
    }

    await _sessionService.setQueueItemStatus(
      code: session.code,
      queueItemId: next.id,
      status: QueueItemStatus.playing,
    );
    await _playerProvider.loadQueue([song], autoPlay: false);
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
    if (song == null) {
      _errorMessage = 'Falta "${playingEntry.title}" en tu biblioteca';
      notifyListeners();
      return;
    }
    await _playerProvider.loadQueue([song], autoPlay: false);
  }

  // ===== EVENTOS DEL WEBSOCKET =====

  void _onServerEvent(SessionServerEvent event) {
    switch (event) {
      case StateChangedEvent _:
        _errorMessage = null;
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
      case P2pOfferEvent _:
      case P2pReadyEvent _:
        break; // señalización P2P: solo se registra por ahora (v2)
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
    super.dispose();
  }
}
