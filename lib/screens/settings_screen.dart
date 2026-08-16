// `RepeatMode` existe tanto acá (modo de repetición de la cola) como en
// `package:flutter/material.dart` (animaciones que se repiten) — se oculta
// la de Flutter porque en esta pantalla la nuestra es la relevante.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../config/env.dart';
import '../config/theme.dart';
import '../models/playback_state.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../utils/formatters.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          _SectionHeader('Reproducción'),
          SwitchListTile(
            title: const Text('Aleatorio'),
            subtitle: const Text('Reproducir la cola en orden aleatorio'),
            activeThumbColor: AppTheme.spotifyGreen,
            value: player.shuffle,
            onChanged: (_) => player.toggleShuffle(),
          ),
          ListTile(
            title: const Text('Repetir'),
            subtitle: Text(_repeatLabel(player.repeatMode)),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
            onTap: player.toggleRepeat,
          ),
          const Divider(),
          _SectionHeader('Biblioteca'),
          ListTile(
            title: const Text('Canciones en la biblioteca'),
            trailing: Text(
              '${library.songs.length}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          if (Env.canScanFilesystem)
            ListTile(
              title: const Text('Escanear carpetas de música'),
              subtitle: library.lastScan == null
                  ? const Text('Nunca escaneado')
                  : Text(
                      'Último escaneo: ${FormatUtils.formatDateAdded(library.lastScan!)}',
                    ),
              trailing: library.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: AppTheme.textSecondary),
              onTap: library.isLoading ? null : library.scanLibrary,
            )
          else
            const ListTile(
              title: Text('Escaneo de carpetas'),
              subtitle: Text(
                'No disponible en Web: el navegador no expone el filesystem. Usá "Agregar MP3".',
              ),
            ),
          const Divider(),
          _SectionHeader('Acerca de'),
          ListTile(
            title: const Text('Plataforma'),
            subtitle: Text(Env.platformName),
          ),
          const _AppVersionTile(),
          const ListTile(
            title: Text('MP3 Player'),
            subtitle: Text(
              'MVP Spotify-like, reproducción 100% local. La sincronización P2P '
              '(sesiones compartidas) se integra con el backend del monolito.',
            ),
          ),
        ],
      ),
    );
  }

  String _repeatLabel(RepeatMode mode) => switch (mode) {
    RepeatMode.off => 'Desactivado',
    RepeatMode.one => 'Una canción',
    RepeatMode.all => 'Toda la cola',
  };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.spotifyGreen,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          title: const Text('Versión'),
          subtitle: Text(
            info == null ? '—' : '${info.version} (${info.buildNumber})',
          ),
        );
      },
    );
  }
}
