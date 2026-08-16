import 'api_client.dart';
import 'storage_service.dart';

/// Identidad local mínima: [id] es lo que el resto de la app manda como
/// `ownerId`/`userId`/`addedBy` a las rutas de sesión/cola (que en este MVP
/// son públicas y reciben la identidad como parámetro explícito, no del
/// JWT — ver `AuthService` doc de clase).
class AuthUser {
  final String id;
  final String username;

  const AuthUser({required this.id, required this.username});
}

/// Registro/login contra `/api/users` y persistencia del JWT.
///
/// El token solo hace falta para las rutas privadas del propio perfil
/// (`/api/users/{id}`, historial, favoritos) — sesiones, cola, canciones y
/// clasificación son públicas en este MVP y la identidad viaja como
/// parámetro explícito (`ownerId`, `userId`, `addedBy`). Igual se loguea y
/// persiste el token acá porque el cliente lo va a necesitar apenas la app
/// use historial/favoritos.
class AuthService {
  final ApiClient _api;
  final StorageService _storage;

  AuthUser? _currentUser;
  String? _token;

  AuthService({required ApiClient api, required StorageService storage})
    : _api = api,
      _storage = storage {
    _api.tokenProvider = () => _token;
    _restoreSession();
  }

  void _restoreSession() {
    final userId = _storage.authUserId;
    final username = _storage.authUsername;
    _token = _storage.authToken;
    if (userId != null && username != null) {
      _currentUser = AuthUser(id: userId, username: username);
    }
  }

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// El registro NO devuelve token (a diferencia del login — ver
  /// `UserResponse` vs `LoginResponse` en el backend): hace falta loguear a
  /// continuación con las mismas credenciales para obtener uno.
  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/api/users/register',
      body: {'username': username, 'email': email, 'password': password},
    ) as Map<String, dynamic>;
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
    );
  }

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final json = await _api.post(
      '/api/users/login',
      body: {'username': username, 'password': password},
    ) as Map<String, dynamic>;

    final token = json['token'] as String;
    final user = json['user'] as Map<String, dynamic>;
    final authUser = AuthUser(
      id: user['id'] as String,
      username: user['username'] as String,
    );

    _token = token;
    _currentUser = authUser;
    await _storage.saveAuthSession(
      token: token,
      userId: authUser.id,
      username: authUser.username,
    );
    return authUser;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.clearAuthSession();
  }
}
