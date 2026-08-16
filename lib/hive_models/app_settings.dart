import 'package:hive/hive.dart';

part 'app_settings.g.dart';

/// Configuración persistida de la app (una sola instancia, key fija en el
/// box). Separado de SharedPreferences: todo lo que es "estado de dominio
/// de la app" vive en Hive; SharedPreferences queda libre para flags simples
/// de infraestructura (ver StorageService).
@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  double volume;

  @HiveField(1)
  int repeatModeIndex;

  @HiveField(2)
  bool shuffle;

  @HiveField(3)
  List<String> libraryFolders;

  @HiveField(4)
  bool darkMode;

  AppSettings({
    this.volume = 1.0,
    this.repeatModeIndex = 0,
    this.shuffle = false,
    List<String>? libraryFolders,
    this.darkMode = true,
  }) : libraryFolders = libraryFolders ?? [];

  factory AppSettings.defaults() => AppSettings();
}
