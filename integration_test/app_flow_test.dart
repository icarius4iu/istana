// Test de integración real: arranca la app completa (Hive, get_it,
// providers) igual que `main.dart`, sobre un dispositivo/navegador de
// verdad — a diferencia de los tests unitarios, acá no hay mocks: es
// `StorageService` con Hive real, `FileService` real, etc.
//
// Requiere un target real (no corre bajo `flutter test` a secas, porque
// `Hive.initFlutter()`/`path_provider`/`shared_preferences` necesitan
// canales de plataforma reales):
//
//   flutter test integration_test        # (o copiar este archivo ahí)
//   flutter drive --target=test/integration/app_flow_test.dart -d <device>
//
// En este sandbox headless (sin dispositivo, sin Chrome) no se puede
// ejecutar — ver el README de la sección "Cómo correr los tests".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mp3_player_flutter/di.dart';
import 'package:mp3_player_flutter/main.dart';
import 'package:mp3_player_flutter/providers/library_provider.dart';
import 'package:mp3_player_flutter/providers/player_provider.dart';
import 'package:mp3_player_flutter/providers/playlist_provider.dart';
import 'package:mp3_player_flutter/services/audio_service.dart';
import 'package:mp3_player_flutter/services/file_service.dart';
import 'package:mp3_player_flutter/services/playlist_service.dart';
import 'package:mp3_player_flutter/services/storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRealApp(WidgetTester tester) async {
    // Todos los `testWidgets` de este archivo corren en el mismo proceso, y
    // GetIt es un singleton global: sin resetear, el segundo test explota
    // con "Type StorageService is already registered inside GetIt".
    await getIt.reset();
    await setupDependencies();

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

    await tester.pumpWidget(
      MP3PlayerApp(
        libraryProvider: libraryProvider,
        playlistProvider: playlistProvider,
        playerProvider: playerProvider,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('la app arranca en la biblioteca y muestra el estado vacío', (
    tester,
  ) async {
    await pumpRealApp(tester);

    expect(find.text('Tu biblioteca'), findsOneWidget);
    expect(find.text('Todavía no hay canciones'), findsOneWidget);
  });

  testWidgets('se puede navegar a Buscar y volver', (tester) async {
    await pumpRealApp(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tu biblioteca'), findsOneWidget);
  });

  testWidgets('se puede navegar a Configuración y ver el switch de aleatorio', (
    tester,
  ) async {
    await pumpRealApp(tester);

    await tester.tap(find.byTooltip('Configuración'));
    await tester.pumpAndSettle();

    expect(find.text('Aleatorio'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
