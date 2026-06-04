# ytmusix - YouTube Music Streamer

A Flutter mobile app that streams audio from public YouTube playlists, single videos, and mixes. No backend, no ads. Built for Android and iOS with a modern dark music-player interface.

## Features

### Playback
- **Offline-first** — plays from local files when downloaded, streams only when unavailable; no redundant redirect resolution
- **Faster stream startup** — resolves playback redirects once and shows the selected track immediately while audio loads
- **Smooth seek and buffer UI** — optimistic seeking plus buffered progress in the full player waveform and mini player
- **Play/pause state indicators** — toggle icon reflects playback status on home screen, playlist screen, player bar, and expanded player
- **Queue management** — play, pause, skip, previous, shuffle, repeat, auto-advance on track completion
- **Autoplay** — when the queue ends, seamlessly fetches related YouTube tracks and keeps playing (designed by [BENJAMINDARKO](https://github.com/BENJAMINDARKO))
- **Sleep timer** — 15m/30m/60m/custom timer to auto-stop playback
- **Lockscreen & notification controls** — Android media notification with play/pause/skip buttons

### Import & Search
- **YouTube search** — search YouTube directly from the app, play results instantly
- **URL import** — paste a video, playlist, or mix URL to add to your library
- **Auto-save to library** — searched and played tracks are automatically saved to your homescreen as single-track playlists

### Downloads & Cache
- **Per-track download** — download individual tracks directly from the playlist list
- **Playlist download** — bulk download with per-track progress, percentage, and cancel support
- **Download status colors** — green icon when fully downloaded, orange while downloading, spinner for in-progress tracks
- **Home screen download** — download playlists directly from the home screen card (with cached tracks)
- **Cache management** — view total cache size in settings; clear per-playlist or all cached downloads
- **Pre-download ahead** — silently downloads the next tracks in the queue so there's no delay between songs

### Playlist Management
- **Sort playlists** — by title, date added, or track count
- **Import/Export** — backup and restore your library as JSON, XML, or Markdown
- **Swipe to delete** — remove playlists with a swipe
- **Rename playlists** — edit playlist title inline
- **Reorder tracks** — long-press drag to reorder tracks within a playlist
- **Remove individual tracks** — swipe-to-delete on any track
- **Star / Favorites** — star/unstar tracks anywhere (playlist, player, search); dedicated "Favorites" playlist card on home screen

### UI
- **Modern Browse home** — large-title browse screen with rounded controls, category tabs, horizontal playlist artwork, and ranked top hits
- **Expanded player** — full-screen now-playing view with large artwork, gradient background, waveform seek control, favorite action, and compact transport controls
- **Modern secondary screens** — Search, Playlist, Settings, Login, track rows, and mini player share the same rounded dark visual language
- **Mini player** — floating bottom player with artwork, queue access, transport controls, active progress, and buffered progress
- **Dark theme** — music-app-inspired dark UI with custom pixel-art logo and green brand accent

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Architecture | Hexagonal (domain/data/presentation) |
| State | Provider |
| YouTube API | `youtube_explode_dart` 3.1.0 (patched client version) |
| Audio playback | `just_audio` 0.9.46 |
| Lockscreen/notification | `audio_service` 0.18.18 |
| Storage | sqflite (SQLite) |
| Secure storage | flutter_secure_storage |
| Downloads | path_provider + http |
| Auth | WebView cookie extraction |
| Platforms | Android + iOS |

## Prerequisites

- Flutter SDK ^3.12.0
- Android device/emulator for Android builds
- Xcode and an iOS Simulator for iOS simulator builds

## Setup

```bash
git clone https://github.com/niiabe/ytmusix-flowos.git
cd ytmusix-flowos
flutter pub get
```

### Pub Cache Patch (youtube_explode_dart)

The `youtube_explode_dart` package needs a patch to return non-empty browse API results:

**File:** `$PUB_CACHE/hosted/pub.dev/youtube_explode_dart-3.1.0/lib/src/reverse_engineering/youtube_http_client.dart`

Change the InnerTube client context to:
```dart
'clientName': "WEB",
'clientVersion': "2.20250601.00.00",
```

Without this patch, the browse API returns empty `contents` and mix playlists fail to load.

> **Note:** This patch is overwritten on `flutter pub upgrade` — must be re-applied.

### Run (Debug)

```bash
flutter run
```

### Android

Run on an Android device or emulator:

```bash
flutter run -d <android-device-id>
```

Build a release APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (~60MB)

A prebuilt release APK is also available at the project root as [`ytmusix.apk`](ytmusix.apk).

### iOS Simulator

Launch a simulator:

```bash
flutter emulators --launch apple_ios_simulator
```

Build for the iOS simulator:

```bash
flutter build ios --simulator
```

Run on a booted simulator:

```bash
flutter run -d <ios-simulator-id>
```

Output: `build/ios/iphonesimulator/Runner.app`

## Project Structure

```
ios/                               # Flutter iOS host project
lib/
├── app.dart                        # App entry point + theme
├── main.dart                       # DI + AudioService.init
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── audio_quality.dart
│   │   ├── playlist_sort_mode.dart
│   │   └── repeat_mode.dart
│   ├── theme/
│   │   └── app_theme.dart          # Dark Spotify-inspired theme
│   └── utils/
│       ├── format_duration.dart
│       └── network_utils.dart      # Redirect resolution
├── domain/
│   ├── entities/
│   │   ├── playlist.dart
│   │   └── video.dart              # Track entity
│   └── repositories/
│       ├── audio_repository.dart
│       └── playlist_repository.dart
├── data/
│   ├── datasources/
│   │   ├── remote/
│   │   │   ├── youtube_remote_datasource.dart
│   │   │   └── authenticated_client.dart
│   │   └── local/
│   │       └── playlist_database.dart  # SQLite
│   ├── models/
│   │   ├── playlist_model.dart
│   │   └── video_model.dart
│   └── repositories/
│       ├── audio_repository_impl.dart
│       └── playlist_repository_impl.dart
├── presentation/
│   ├── screens/
│   │   ├── home_screen.dart        # Browse layout + playlist shelf
│   │   ├── player_screen.dart      # Full-screen waveform player
│   │   ├── playlist_screen.dart    # Modern playlist detail
│   │   ├── search_screen.dart      # YouTube search
│   │   ├── settings_screen.dart    # Playback/login/storage settings
│   │   └── login_screen.dart       # WebView Google auth
│   ├── providers/
│   │   ├── player_provider.dart
│   │   ├── playlist_provider.dart
│   │   ├── download_provider.dart
│   │   └── settings_provider.dart
│   └── widgets/
│       ├── player_bar.dart
│       ├── video_tile.dart
│       ├── playlist_card.dart
│       ├── now_playing_card.dart
│       ├── queue_sheet.dart
│       └── pixel_logo.dart
└── service/
    ├── audio_handler.dart          # MusicAudioHandler (audio_service bridge)
    ├── auth_service.dart           # flutter_secure_storage cookies
    └── download_service.dart       # Offline downloads with progress
```

## Testing

```bash
flutter test
```

_(No tests currently — test directory removed during refactoring.)_

## Known Issues

### App
- **Pub cache patch** — overwritten when `flutter pub upgrade` runs; must be re-applied manually.
- **iOS Swift Package Manager notice** — Flutter currently warns that `flutter_secure_storage` does not support Swift Package Manager for iOS yet. This is a future-warning, not a current build blocker.
- **Android Kotlin Gradle Plugin notice** — Flutter currently warns that app/plugin Kotlin Gradle Plugin usage should migrate to Built-in Kotlin for future Flutter versions. This is a future-warning, not a current build blocker.
- **Samsung GPU `BufferQueue` timeout** — harmless Adreno driver spam in logcat on Exynos devices; does not affect playback.

## Design Docs

- [`autoplay-explained-simple.md`](autoplay-explained-simple.md) — autoplay behavior spec designed by [BENJAMINDARKO](https://github.com/BENJAMINDARKO)

## Roadmap

See [`futureroadmap.txt`](futureroadmap.txt) for planned features sourced from MusicPiped, koel/player, Flow, sweyer, you-free-app, and monochrome-music/monochrome.

## License

Personal / educational use.
