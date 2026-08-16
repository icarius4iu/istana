import 'package:flutter/foundation.dart';

import '../models/song.dart';

/// Notificaciones de reproducción (controles en pantalla de bloqueo /
/// centro de notificaciones / media keys del SO).
///
/// Fuera de alcance del MVP a propósito: eso requiere el paquete
/// `audio_service` (github.com/ryanheise/audio_service) corriendo el
/// reproductor dentro de un `BackgroundAudioTask`/`AudioHandler`, más
/// permisos y manifest entries por plataforma (`FOREGROUND_SERVICE` en
/// Android, `UIBackgroundModes: audio` en iOS — ya declarado en
/// `Info.plist` para cuando se active). No se agregó como dependencia
/// todavía para no acoplar el MVP a esa integración antes de tener el
/// reproductor base probado; queda como próximo paso natural post-MVP.
///
/// Esta clase deja el punto de extensión con la forma que va a tener esa
/// integración, para que PlayerProvider ya la llame y no haga falta tocar
/// el resto de la app cuando se implemente de verdad.
class NotificationService {
  Future<void> init() async {
    // No-op en el MVP.
  }

  Future<void> showNowPlaying(Song song, {required bool isPlaying}) async {
    if (kDebugMode) {
      debugPrint(
        '[NotificationService] now playing (stub, sin UI de sistema): '
        '${song.title} — ${song.artist} (${isPlaying ? "playing" : "paused"})',
      );
    }
  }

  Future<void> clear() async {
    // No-op en el MVP.
  }
}
