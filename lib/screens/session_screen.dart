import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../models/session_models.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/session_provider.dart';
import '../utils/extensions.dart';
import '../widgets/empty_state.dart';
import '../widgets/session/member_chip.dart';
import '../widgets/session/qr_code_view.dart';
import '../widgets/session/queue_entry_tile.dart';

/// Pantalla de jam session: sin sesión activa muestra "crear/unirse"; con
/// una activa, código + QR, miembros y cola compartida.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (!session.isLoggedIn) {
      return const _LoginRequired();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jam session'),
        actions: [
          if (session.hasActiveSession)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Salir de la sesión',
              onPressed: () => session.leaveSession(),
            ),
        ],
      ),
      body: session.hasActiveSession
          ? const _ActiveSessionBody()
          : const _NoSessionBody(),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jam session')),
      body: EmptyState(
        icon: Icons.groups_outlined,
        title: 'Iniciá sesión para escuchar con otros',
        subtitle: 'Crear o unirte a una jam session necesita una cuenta.',
        actionLabel: 'Iniciar sesión',
        onAction: () => Navigator.pushNamed(context, AppRoutes.auth),
      ),
    );
  }
}

class _NoSessionBody extends StatefulWidget {
  const _NoSessionBody();

  @override
  State<_NoSessionBody> createState() => _NoSessionBodyState();
}

class _NoSessionBodyState extends State<_NoSessionBody> {
  late final TextEditingController _serverController;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    _serverController = TextEditingController(
      text: session.serverUrl.isEmpty
          ? Env.defaultApiBaseUrl
          : session.serverUrl,
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyServerUrl() async {
    final session = context.read<SessionProvider>();
    await session.setServerUrl(_serverController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Servidor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'La URL pública del backend (en Codespaces cambia cada vez que se '
            'levanta el MVP) — tiene que ser la misma en los dos dispositivos.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _serverController,
            decoration: const InputDecoration(hintText: 'https://...'),
            onSubmitted: (_) => _applyServerUrl(),
            onEditingComplete: _applyServerUrl,
          ),
          const SizedBox(height: 32),
          Text(
            'Crear una sesión',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear jam session'),
            onPressed: session.isBusy
                ? null
                : () async {
                    await _applyServerUrl();
                    if (!context.mounted) return;
                    final ok = await session.createSession();
                    if (!ok && context.mounted) {
                      context.showSnack(
                        session.errorMessage ?? 'No se pudo crear',
                      );
                    }
                  },
          ),
          const SizedBox(height: 32),
          Text(
            'Unirte con un código',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(hintText: 'JAM-XXX'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Unirme'),
            onPressed: session.isBusy
                ? null
                : () async {
                    await _applyServerUrl();
                    if (!context.mounted) return;
                    final ok = await session.joinSession(_codeController.text);
                    if (!ok && context.mounted) {
                      context.showSnack(
                        session.errorMessage ?? 'No se pudo unir',
                      );
                    }
                  },
          ),
          if (session.isBusy) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(color: AppTheme.spotifyGreen),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveSessionBody extends StatelessWidget {
  const _ActiveSessionBody();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final jamSession = session.session!;
    final myId = session.currentUser?.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                jamSession.code,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                session.isConnected ? 'Conectado' : 'Conectando…',
                style: TextStyle(
                  color: session.isConnected
                      ? AppTheme.spotifyGreen
                      : AppTheme.textSecondary,
                ),
              ),
              if (jamSession.qrCodePngBase64 != null) ...[
                const SizedBox(height: 16),
                QrCodeView(base64Png: jamSession.qrCodePngBase64!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Miembros (${session.members.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in session.members)
              MemberChip(member: member, isMe: member.userId == myId),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cola compartida',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Agregar de mi biblioteca',
              onPressed: () => _showAddSongSheet(context),
            ),
          ],
        ),
        if (session.queue.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'La cola está vacía. Agregá una canción de tu biblioteca.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          Consumer<LibraryProvider>(
            builder: (context, library, _) => Column(
              children: [
                for (final entry in session.queue)
                  QueueEntryTile(
                    entry: entry,
                    ownedLocally: library.getSongById(entry.fileHash) != null,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            icon: Icon(
              jamSession.state == JamPlaybackState.playing
                  ? Icons.pause
                  : Icons.play_arrow,
            ),
            label: Text(
              jamSession.state == JamPlaybackState.playing
                  ? 'Pausar'
                  : 'Reproducir',
            ),
            onPressed: session.isBusy ? null : () => session.togglePlayPause(),
          ),
        ),
        if (session.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            session.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.error),
          ),
        ],
      ],
    );
  }

  void _showAddSongSheet(BuildContext context) {
    final sessionProvider = context.read<SessionProvider>();
    final library = context.read<LibraryProvider>();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Agregar a la cola',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                Expanded(
                  child: library.songs.isEmpty
                      ? const Center(
                          child: Text(
                            'Tu biblioteca está vacía.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: library.songs.length,
                          itemBuilder: (_, index) {
                            final Song song = library.songs[index];
                            return ListTile(
                              title: Text(song.title, maxLines: 1),
                              subtitle: Text(song.artist, maxLines: 1),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                final ok = await sessionProvider.addSongToQueue(
                                  song,
                                );
                                if (!ok && sheetContext.mounted) {
                                  sheetContext.showSnack(
                                    sessionProvider.errorMessage ??
                                        'No se pudo agregar',
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
