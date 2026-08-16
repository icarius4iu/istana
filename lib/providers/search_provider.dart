import 'package:flutter/foundation.dart';

/// Estado de la pantalla de búsqueda: el texto de búsqueda y el historial
/// de búsquedas recientes.
///
/// A propósito NO guarda los resultados (canciones/playlists) acá: eso
/// obligaría a este provider a re-computar cada vez que cambia la
/// biblioteca o las playlists, duplicando lo que ya hacen
/// [LibraryProvider]/[PlaylistProvider]. `SearchScreen` combina el `query`
/// de acá con `context.watch<LibraryProvider>().songs` para filtrar, así
/// que los resultados siempre están en vivo.
class SearchProvider extends ChangeNotifier {
  static const int _maxRecentSearches = 10;

  String _query = '';
  final List<String> _recentSearches = [];

  String get query => _query;
  bool get isQueryEmpty => _query.trim().isEmpty;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Guarda el término actual en el historial (al enviar el formulario de
  /// búsqueda, no en cada tecla).
  void commitSearch() {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) return;

    _recentSearches
      ..remove(trimmed)
      ..insert(0, trimmed);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeLast();
    }
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }

  void removeRecentSearch(String term) {
    _recentSearches.remove(term);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }
}
