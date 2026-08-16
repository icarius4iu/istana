import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/theme.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/validators.dart';
import '../widgets/empty_state.dart';
import '../widgets/playlist_tile.dart';
import '../widgets/song_tile.dart';

/// Pantalla dual: sin [playlist] muestra el listado de todas las playlists
/// (el "hub"); con [playlist] muestra el detalle de una. Se modela así en
/// vez de dos screens separadas porque comparten toda la lógica de
/// creación/borrado y es una única entrada en `AppRoutes`.
class PlaylistScreen extends StatelessWidget {
  final Playlist? playlist;

  const PlaylistScreen({super.key, this.playlist});

  @override
  Widget build(BuildContext context) {
    return playlist == null
        ? const _PlaylistsHub()
        : _PlaylistDetail(playlistId: playlist!.id);
  }
}

class _PlaylistsHub extends StatelessWidget {
  const _PlaylistsHub();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tus playlists')),
      body: provider.playlists.isEmpty
          ? EmptyState(
              icon: Icons.queue_music,
              title: 'Todavía no creaste playlists',
              subtitle: 'Agrupá tus canciones favoritas en una playlist.',
              actionLabel: 'Crear playlist',
              onAction: () => _showCreateDialog(context),
            )
          : ListView.builder(
              itemCount: provider.playlists.length,
              itemBuilder: (context, index) {
                final playlist = provider.playlists[index];
                return PlaylistTile(
                  playlist: playlist,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.playlist,
                    arguments: playlist,
                  ),
                  onDelete: () => _confirmDelete(context, playlist),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        tooltip: 'Crear playlist',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final provider = context.read<PlaylistProvider>();
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Nueva playlist'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            validator: Validators.playlistName,
            decoration: const InputDecoration(
              hintText: 'Nombre de la playlist',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              provider.createPlaylist(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Playlist playlist) {
    final provider = context.read<PlaylistProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('¿Eliminar playlist?'),
        content: Text(
          '"${playlist.name}" se va a eliminar. Esto no borra las canciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.deletePlaylist(playlist.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistDetail extends StatelessWidget {
  final String playlistId;
  const _PlaylistDetail({required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();
    final playlist = provider.playlists
        .where((p) => p.id == playlistId)
        .firstOrNull;

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Esta playlist ya no existe',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final songs = provider.songsInPlaylist(playlist);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar playlist',
            onPressed: () {
              provider.deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: songs.isEmpty
          ? const EmptyState(
              icon: Icons.music_off,
              title: 'Esta playlist está vacía',
              subtitle: 'Agregá canciones desde tu biblioteca con "Playlist" al deslizar una fila.',
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final player = context.watch<PlayerProvider>();
                return SongTile(
                  song: song,
                  isPlaying: player.currentSong?.id == song.id,
                  onTap: () async {
                    await player.loadQueue(songs, startIndex: index);
                    if (context.mounted) {
                      Navigator.pushNamed(context, AppRoutes.player);
                    }
                  },
                  onRemove: () =>
                      provider.removeSongFromPlaylist(playlist.id, song.id),
                );
              },
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
