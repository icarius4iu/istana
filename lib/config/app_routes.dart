import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../screens/error_screen.dart';
import '../screens/home_screen.dart';
import '../screens/player_screen.dart';
import '../screens/playlist_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';

/// Nombres de ruta + generador central de rutas.
///
/// Usar rutas nombradas (en vez de `MaterialPageRoute` disperso por toda la
/// UI) mantiene la navegación fácil de testear y de extender cuando llegue
/// deep-linking (p. ej. abrir una sesión P2P desde un link de invitación).
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String player = '/player';
  static const String playlist = '/playlist';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String error = '/error';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case player:
        return MaterialPageRoute(builder: (_) => const PlayerScreen());
      case playlist:
        final playlist = routeSettings.arguments as Playlist?;
        return MaterialPageRoute(
          builder: (_) => PlaylistScreen(playlist: playlist),
        );
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              ErrorScreen(message: 'Ruta no encontrada: ${routeSettings.name}'),
        );
    }
  }
}
