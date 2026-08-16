// Smoke test de un widget de hoja (sin providers/Hive de por medio — eso se
// prueba en `test/widget/` con dobles de prueba). Confirma que el árbol de
// widgets básico de Material renderiza sin explotar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_player_flutter/config/theme.dart';
import 'package:mp3_player_flutter/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState muestra título, subtítulo y dispara la acción', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: EmptyState(
            icon: Icons.music_note,
            title: 'Todavía no hay canciones',
            subtitle: 'Agregá un MP3 para empezar.',
            actionLabel: 'Agregar MP3',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Todavía no hay canciones'), findsOneWidget);
    expect(find.text('Agregá un MP3 para empezar.'), findsOneWidget);

    await tester.tap(find.text('Agregar MP3'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
