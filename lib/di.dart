import 'package:get_it/get_it.dart';

import 'config/env.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/file_service.dart';
import 'services/notification_service.dart';
import 'services/p2p_transfer_service.dart';
import 'services/playlist_service.dart';
import 'services/session_service.dart';
import 'services/storage_service.dart';

/// Service locator para lo que NO es estado reactivo (servicios, sin
/// `notifyListeners`). El estado reactivo va por `provider` — ver
/// `main.dart`. Mezclar los dos es intencional: get_it resuelve
/// dependencias entre servicios sin pasar `BuildContext` por todos lados,
/// y provider reconstruye la UI cuando cambia el estado de dominio.
final GetIt getIt = GetIt.instance;

/// Debe llamarse una sola vez, en `main()`, antes de `runApp`.
Future<void> setupDependencies() async {
  final storage = StorageService();
  await storage.init();
  getIt.registerSingleton<StorageService>(storage);

  final fileService = FileService();
  await fileService.init();
  getIt.registerSingleton<FileService>(fileService);

  getIt.registerLazySingleton<NotificationService>(() => NotificationService());

  getIt.registerLazySingleton<PlaylistService>(
    () => PlaylistService(storage: getIt<StorageService>()),
  );

  // Networking de la jam session: ApiClient primero (lee la URL guardada, o
  // el fallback de Env), AuthService y SessionService dependen de él.
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: getIt<StorageService>().serverBaseUrl ?? Env.defaultApiBaseUrl,
    ),
  );
  getIt.registerLazySingleton<AuthService>(
    () =>
        AuthService(api: getIt<ApiClient>(), storage: getIt<StorageService>()),
  );
  getIt.registerLazySingleton<SessionService>(
    () => SessionService(api: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<P2pTransferService>(() => P2pTransferService());
}
