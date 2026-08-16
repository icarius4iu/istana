import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/env.dart';
import '../config/theme.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/extensions.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_spinner.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tu biblioteca',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Jam session',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.session),
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_outlined),
            tooltip: 'Playlists',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.playlist),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: const _LibraryBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndPlaySong(context),
        tooltip: 'Agregar MP3',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const _HomeMiniPlayer(),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    if (library.isLoading && library.songs.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => const SongTileShimmer(),
      );
    }

    if (library.songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_note,
        title: 'Todavía no hay canciones',
        subtitle: Env.canScanFilesystem
            ? 'Agregá un MP3 o escaneá tus carpetas de música.'
            : 'Elegí uno o varios archivos MP3 para empezar a escuchar.',
        actionLabel: 'Agregar MP3',
        onAction: () => _pickAndPlaySong(context),
      );
    }

    return RefreshIndicator(
      color: AppTheme.spotifyGreen,
      onRefresh: () =>
          Env.canScanFilesystem ? library.scanLibrary() : Future<void>.value(),
      child: CustomScrollView(
        slivers: [
          if (library.errorMessage != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(message: library.errorMessage!),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 96),
            sliver: SliverList.builder(
              itemCount: library.filteredSongs.length,
              itemBuilder: (context, index) {
                final song = library.filteredSongs[index];
                final player = context.watch<PlayerProvider>();
                final isPlaying = player.currentSong?.id == song.id;

                return SongTile(
                  song: song,
                  isPlaying: isPlaying,
                  onTap: () => _playSong(context, song),
                  onRemove: () => library.removeSong(song.id),
                  onAddToPlaylist: () => _showAddToPlaylistSheet(context, song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMiniPlayer extends StatelessWidget {
  const _HomeMiniPlayer();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final totalMs = player.duration.inMilliseconds;
    final progress = totalMs == 0
        ? 0.0
        : player.currentPosition.inMilliseconds / totalMs;

    return MiniPlayer(
      song: song,
      state: player.state,
      progress: progress,
      onPlayPause: () => player.isPlaying ? player.pause() : player.resume(),
      onTap: () => Navigator.pushNamed(context, AppRoutes.player),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickAndPlaySong(BuildContext context) async {
  final library = context.read<LibraryProvider>();
  final song = await library.pickAndAddSong();
  if (song != null && context.mounted) {
    await _playSong(context, song);
  } else if (context.mounted && library.errorMessage != null) {
    context.showSnack(library.errorMessage!);
  }
}

Future<void> _playSong(BuildContext context, Song song) async {
  final library = context.read<LibraryProvider>();
  final player = context.read<PlayerProvider>();
  final songs = library.filteredSongs;

  await player.loadQueue(songs, startIndex: songs.indexOfId(song.id));
  if (context.mounted) {
    Navigator.pushNamed(context, AppRoutes.player);
  }
}

void _showAddToPlaylistSheet(BuildContext context, Song song) {
  final playlistProvider = context.read<PlaylistProvider>();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Agregar a playlist',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (playlistProvider.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tenés playlists. Creá una desde la pestaña de playlists.',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final playlist in playlistProvider.playlists)
                      ListTile(
                        leading: const Icon(
                          Icons.queue_music,
                          color: AppTheme.textSecondary,
                        ),
                        title: Text(playlist.name),
                        onTap: () {
                          playlistProvider.addSongToPlaylist(
                            playlist.id,
                            song.id,
                          );
                          Navigator.pop(sheetContext);
                          context.showSnack('Agregada a "${playlist.name}"');
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
