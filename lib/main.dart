import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:provider/provider.dart';

import 'config/app_routes.dart';
import 'config/constants.dart';
import 'config/theme.dart';
import 'di.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/search_provider.dart';
import 'providers/session_provider.dart';
import 'services/api_client.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/file_service.dart';
import 'services/playlist_service.dart';
import 'services/session_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // just_audio no tiene backend nativo propio en Windows/Linux (a
  // diferencia de Android/iOS/macOS/Web); esto lo registra vía media_kit
  // (libmpv). Es un no-op seguro en el resto de las plataformas —ver
  // doc del método—, así que se llama incondicionalmente acá.
  JustAudioMediaKit.ensureInitialized();

  await setupDependencies();

  // Los providers "de servicio" (library/playlist/player) se construyen acá
  // -y no con `create:` perezoso de Provider- porque necesitan enlazarse
  // entre sí (ver `onDurationResolved` más abajo) antes de que la UI arranque.
  final libraryProvider = LibraryProvider(
    fileService: getIt<FileService>(),
    storage: getIt<StorageService>(),
  );

  final playlistProvider = PlaylistProvider(
    playlistService: getIt<PlaylistService>(),
    libraryProvider: libraryProvider,
  );

  final playerProvider = PlayerProvider(
    audioService: AudioService(),
    storage: getIt<StorageService>(),
  )..onDurationResolved = libraryProvider.updateDuration;

  // Igual que playerProvider: se construye eager (no `create:` perezoso)
  // porque necesita enlazarse con playerProvider/libraryProvider antes de
  // que la UI arranque (ver SessionProvider._schedulePlayback).
  final sessionProvider = SessionProvider(
    auth: getIt<AuthService>(),
    sessionService: getIt<SessionService>(),
    playerProvider: playerProvider,
    libraryProvider: libraryProvider,
    apiClient: getIt<ApiClient>(),
    storage: getIt<StorageService>(),
  );

  runApp(
    MP3PlayerApp(
      libraryProvider: libraryProvider,
      playlistProvider: playlistProvider,
      playerProvider: playerProvider,
      sessionProvider: sessionProvider,
    ),
  );
}

class MP3PlayerApp extends StatelessWidget {
  final LibraryProvider libraryProvider;
  final PlaylistProvider playlistProvider;
  final PlayerProvider playerProvider;
  final SessionProvider sessionProvider;

  const MP3PlayerApp({
    super.key,
    required this.libraryProvider,
    required this.playlistProvider,
    required this.playerProvider,
    required this.sessionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryProvider>.value(value: libraryProvider),
        ChangeNotifierProvider<PlaylistProvider>.value(value: playlistProvider),
        ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
        ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
        ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
