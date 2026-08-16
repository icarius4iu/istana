/// Validaciones de formularios simples (crear/renombrar playlist, etc.).
/// Devuelven `null` si el valor es válido, o un mensaje de error listo para
/// mostrar en un `TextFormField.validator`.
class Validators {
  Validators._();

  static const int maxPlaylistNameLength = 60;

  static String? playlistName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'El nombre no puede estar vacío';
    if (trimmed.length > maxPlaylistNameLength) {
      return 'Máximo $maxPlaylistNameLength caracteres';
    }
    return null;
  }

  static String? searchQuery(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 200) return 'Búsqueda demasiado larga';
    return null;
  }

  /// true si el nombre de archivo tiene una extensión de audio soportada.
  static bool isSupportedAudioFile(
    String fileName,
    List<String> supportedFormats,
  ) {
    final ext = fileName.split('.').last.toLowerCase();
    return supportedFormats.contains(ext);
  }
}
