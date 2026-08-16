// Ver el comentario en `app_flow_test.dart` sobre cómo correr esto — igual
// que ese archivo, necesita un dispositivo/navegador real.
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

  testWidgets('crear una playlist la deja ver en el hub, y se puede borrar', (
    tester,
  ) async {
    await pumpRealApp(tester);

    // Home -> hub de playlists.
    await tester.tap(find.byTooltip('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no creaste playlists'), findsOneWidget);

    // Crear playlist vía el diálogo.
    await tester.tap(find.text('Crear playlist'));
    await tester.pumpAndSettle();

    const playlistName = 'Para el gimnasio';
    await tester.enterText(find.byType(TextFormField), playlistName);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(find.text(playlistName), findsOneWidget);
    expect(find.text('0 canciones'), findsOneWidget);

    // Borrarla desde el ícono de la fila: abre un diálogo de confirmación
    // antes de borrar de verdad (ver PlaylistScreen._confirmDelete).
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar playlist?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text(playlistName), findsNothing);
    expect(find.text('Todavía no creaste playlists'), findsOneWidget);
  });
}
