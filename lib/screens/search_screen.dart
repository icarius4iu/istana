import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/theme.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    final library = context.watch<LibraryProvider>();

    final query = search.query.trim().toLowerCase();
    final results = query.isEmpty
        ? const <Song>[]
        : library.songs
              .where(
                (s) =>
                    s.title.toLowerCase().contains(query) ||
                    s.artist.toLowerCase().contains(query) ||
                    s.album.toLowerCase().contains(query),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buscar canción, artista o álbum...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: search.isQueryEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      _controller.clear();
                      search.clearQuery();
                    },
                  ),
          ),
          onChanged: search.setQuery,
          onSubmitted: (_) => search.commitSearch(),
        ),
      ),
      body: search.isQueryEmpty
          ? _RecentSearches(
              onSelect: (term) {
                _controller.text = term;
                search.setQuery(term);
              },
            )
          : results.isEmpty
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'Sin resultados',
              subtitle: 'Probá con otro título, artista o álbum.',
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final song = results[index];
                final player = context.watch<PlayerProvider>();
                return SongTile(
                  song: song,
                  isPlaying: player.currentSong?.id == song.id,
                  onTap: () async {
                    search.commitSearch();
                    await player.loadQueue(results, startIndex: index);
                    if (context.mounted) {
                      Navigator.pushNamed(context, AppRoutes.player);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _RecentSearches({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();

    if (search.recentSearches.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Buscá en tu biblioteca',
        subtitle: 'Por título, artista o álbum.',
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Búsquedas recientes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: search.clearRecentSearches,
                child: const Text('Borrar todo'),
              ),
            ],
          ),
        ),
        for (final term in search.recentSearches)
          ListTile(
            leading: const Icon(Icons.history, color: AppTheme.textSecondary),
            title: Text(term),
            trailing: IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              onPressed: () => search.removeRecentSearch(term),
            ),
            onTap: () => onSelect(term),
          ),
      ],
    );
  }
}
