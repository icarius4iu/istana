# Ist'aña — reproductor MP3 multiplataforma

> *ist'aña* — «escuchar», en aymara.

[![Test](https://github.com/icarius4iu/istana/actions/workflows/test.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/test.yml)
[![Android](https://github.com/icarius4iu/istana/actions/workflows/build_android.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_android.yml)
[![iOS](https://github.com/icarius4iu/istana/actions/workflows/build_ios.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_ios.yml)
[![Web](https://github.com/icarius4iu/istana/actions/workflows/build_web.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_web.yml)
[![Linux](https://github.com/icarius4iu/istana/actions/workflows/build_linux.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_linux.yml)
[![Windows](https://github.com/icarius4iu/istana/actions/workflows/build_windows.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_windows.yml)
[![macOS](https://github.com/icarius4iu/istana/actions/workflows/build_macos.yml/badge.svg)](https://github.com/icarius4iu/istana/actions/workflows/build_macos.yml)

Reproductor de MP3 locales con UI estilo Spotify. Corre en **Android, iOS,
Windows, macOS, Linux y Web** desde el mismo código Dart. Es el cliente MVP
puro (sin red): la integración con el backend P2P de sesiones de escucha
compartida ([mp3-classifier-p2p](https://github.com/icarius4iu/mp3-classifier-p2p) —
sincronización de reproducción en tiempo real) es el siguiente paso, no parte
de este MVP.

---

## Stack

- Flutter 3.47.0 (stable) · Dart 3.13.0
- `just_audio` + `just_audio_media_kit` (Windows/Linux) para reproducción
- `file_picker` para elegir archivos en cualquier plataforma
- `metadata_god` para leer tags ID3 (Android/iOS/Desktop — no Web)
- `provider` para estado reactivo, `get_it` para inyectar servicios
- `hive` / `hive_flutter` para persistir biblioteca, playlists y config

> El spec original pedía versiones fijas de 2023 (Flutter 3.13.0, `just_audio
> ^0.9.36`, etc.). Se instaló Flutter estable actual y se dejó que `pub`
> resolviera las versiones compatibles vigentes de cada paquete — pinning al
> spec original hoy directamente no compila contra el Flutter/Dart SDK
> actual.

---

## Estructura

```
istana/
├── lib/
│   ├── main.dart              # bootstrap: Hive, get_it, MultiProvider
│   ├── di.dart                 # service locator (get_it)
│   ├── config/                 # theme, constantes, rutas, capacidades por plataforma (env.dart)
│   ├── models/                 # Song, Playlist, PlaybackState, UiState — inmutables
│   ├── hive_models/             # espejos persistibles + *.g.dart generados
│   ├── services/                # AudioService, FileService (io/web), PlaylistService, StorageService
│   ├── providers/               # PlayerProvider, LibraryProvider, PlaylistProvider, SearchProvider
│   ├── screens/ + widgets/      # UI
│   └── utils/                   # formatters, validators, extensions, responsive
├── test/
│   ├── widget_test.dart
│   └── unit/                    # models, utils, services (file_service_io real), providers (mocktail)
├── integration_test/            # boot de la app real (Hive real) — necesita device/browser/desktop
└── android|ios|windows|macos|linux|web/   # generados por `flutter create`, con configs de plataforma ajustadas
```

---

## Arranque rápido

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # adapters de Hive

flutter run -d chrome     # Web
flutter run -d linux      # Linux desktop (necesita ninja-build + libgtk-3-dev)
flutter run -d windows    # Windows desktop
flutter run -d macos      # macOS desktop
flutter run               # Android/iOS con un device/emulador conectado
```

### Dependencias nativas por plataforma

| Plataforma | Qué hace falta además de Flutter |
|---|---|
| Linux (dev/CI) | `sudo apt install ninja-build libgtk-3-dev`, y **Rust** (`rustup`) — `metadata_god` compila su parte nativa con `cargokit` en el momento del build |
| Windows | Rust también, por el mismo motivo (`metadata_god`) |
| Android | `READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE` ya están en el manifest |
| macOS | Entitlement `com.apple.security.files.user-selected.read-only` ya agregado (sandbox + file_picker) |
| iOS | `UIBackgroundModes: audio` ya en `Info.plist` para reproducir con la app en background |
| Web | Nada extra — todo corre en el navegador |

---

## Qué cambia entre plataformas (por qué, no solo qué)

El pedido original describía "el mismo código en las 6 plataformas", pero eso
no es literal para dos features: **escanear una carpeta de música** y **leer
tags ID3**. Ninguna de las dos existe en un browser (no hay filesystem real,
no hay FFI/Rust). En vez de fingir que sí y romper en producción, `FileService`
tiene una implementación por familia de plataforma, elegida en tiempo de
compilación (no en runtime) vía conditional imports:

- **`file_service_io.dart`** (Android/iOS/Desktop): escanea carpetas con
  `dart:io`, lee tags reales con `metadata_god`.
- **`file_service_web.dart`** (Web): solo puede ofrecer el file picker (que en
  Web entrega bytes, no una ruta); el título sale del nombre de archivo, y la
  duración real se completa sola apenas el audio carga (`PlayerProvider.
  onDurationResolved` → `LibraryProvider.updateDuration`).

`Env` (`lib/config/env.dart`) expone `canScanFilesystem`/`canReadId3Tags` para
que la UI oculte lo que no aplica (p. ej. HomeScreen no ofrece "escanear
carpetas" en Web) en vez de mostrar un botón que siempre falla.

`AudioService.resolveUri` unifica el resto: reproduce desde una ruta absoluta
de filesystem (`Uri.file(...)`) o desde una URL con esquema propio (`blob:` —
la que arma `file_picker` en Web, ver `PlatformFile.uri`), usando siempre
`AudioSource.uri(...)` en vez de `setFilePath` (que no existe en Web).

`just_audio` tampoco tiene backend nativo propio en Windows/Linux (sí en
Android/iOS/macOS/Web): se usa `just_audio_media_kit` (libmpv vía
`media_kit`), inicializado una vez en `main()`.

---

## Tests

```bash
flutter test                                  # unit + widget (50 tests, sin device)
flutter test integration_test -d linux        # o -d chrome / -d windows / -d macos
```

- **`test/unit/services/file_service_io_test.dart`** corre la implementación
  real de `dart:io` (no un mock) contra un directorio temporal — `flutter
  test` corre en la VM de Dart, donde `dart.library.io` es `true`.
- **`test/unit/hive_models/`** hace un ciclo real de escritura/lectura en
  disco con `Hive.init(tempDir)`, no solo compara objetos en memoria.
- **`test/unit/providers/`** usa `mocktail` para `AudioService`/
  `StorageService`/`FileService` — cubre cola, shuffle (mantiene fija la
  canción actual), repeat, auto-avance al terminar una canción, y el bug real
  que tenía el spec original (togglear shuffle no debe saltar de canción).
- **`integration_test/`** arranca la app de verdad (Hive real, sin mocks) y
  necesita un dispositivo/navegador/desktop real — no corre bajo `flutter
  test` a secas porque `path_provider`/`shared_preferences` no tienen canal
  de plataforma en la VM pelada. Se verificó corriendo de punta a punta contra
  un build real de Linux desktop en este mismo entorno (bajo Xvfb): arranca,
  muestra la biblioteca vacía, navega a Buscar/Configuración, crea y borra
  una playlist. `build_linux.yml` lo corre en CI del mismo modo.

---

## Decisiones que se apartan del documento original

El documento pegado tenía código de referencia con algunos problemas reales
que se corrigieron acá (no son gustos de estilo):

1. **`AudioService`** del spec mapeaba un `AudioPlaybackState` que no existe
   en `just_audio` — no hubiera compilado. Se mapea desde el `PlayerState`
   real del paquete (`playing` + `processingState`).
2. **Auto-avance al terminar una canción**: el spec lo detectaba comparando
   contra `state == PlayerState.stopped`, que también es el estado inicial
   antes de cargar nada — dispararía "siguiente" de más. Se usa un stream
   dedicado (`AudioService.onSongComplete`, filtrando `ProcessingState.
   completed`).
3. **Shuffle** del spec no existía en la implementación (solo el flag); acá
   sí baraja la cola manteniendo fija la canción que estás escuchando.
4. **`file_picker` v6** (la del spec) tiene una API distinta a la v12
   actual (sin `FilePicker.platform`, `pickFiles` ya no es nullable, etc.) —
   se adaptó a la API vigente.
5. **Fuente "Spotify Circular"**: es propietaria de Spotify, no se puede
   redistribuir. Se usa la tipografía por defecto de Material 3 con los
   mismos tamaños/pesos.
6. **CMake manual para registrar plugins de Windows/Linux** (lo que sugería
   el spec) ya no es necesario ni válido con el sistema de plugins actual de
   Flutter — se genera solo.
