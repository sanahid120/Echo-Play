# EchoPlay

EchoPlay is an offline-first Flutter music and video player. It discovers media already stored on the device and plays local files. It does not stream, download, or search for media on the internet.

## Product goals

- Browse locally indexed audio and video, with permission requested only when a user scans.
- Play audio and video from local file paths using native playback plugins.
- Keep a polished dark interface with clear Music and Videos modes.
- Grow toward a feature-based Clean Architecture with testable repository and playback boundaries.
- Degrade clearly when a platform does not yet have a media scanner or a file is unavailable/unsupported.

## Platform scope

The first delivery targets Android, where scoped media permissions and MediaStore provide a reliable way to enumerate device audio and video. iOS, desktop, and web need their own media discovery/file-import workflows before they can expose a comparable library. Unsupported formats depend on the device decoder.

## Offline guarantee

Media discovery is from Android MediaStore only. Playback sources are local file paths. No network media source, remote image, analytics, or account service is part of the app. Internet access is not needed to browse or play a previously indexed local library.

## Architecture

```text
lib/
  core/
    media/       Media model, discovery channel, permission and playback services
    theme/       Shared visual system
  features/
    library/     Music/video browsing and search
    player/      Playback surfaces and controls
  main.dart
android/app/src/main/kotlin/.../MainActivity.kt  Android MediaStore bridge
```

The Android bridge returns metadata and paths in pages of 200; MediaStore queries run on a dedicated Android executor, and Flutter yields between page responses. It does not copy media into the app or load media bytes into memory. Keep platform access behind a repository so future iOS/file-import support can be added without coupling screens to MediaStore.

The initial dependency choices are Riverpod for feature state, `just_audio` for audio, Flutter's maintained `video_player` plugin for video, GoRouter for the planned route graph, and Drift/SQLite for persisted library data. The first slice currently wires playback and discovery directly; provider, route, and database migrations are tracked as follow-up work.

## Development stages

1. Project foundation, offline-only scope, Android media permissions and local library discovery.
2. Real local audio/video playback and responsive library experience.
3. Persisted favorites, playlists, playback history, and resume positions.
4. Background audio, notification/lock-screen controls, queue, and richer video controls.
5. Platform coverage, accessibility, performance, and automated coverage.

See [PROGRESS.md](PROGRESS.md) for current status and the next concrete tasks.

## Run

With Flutter installed, run `flutter pub get`, connect an Android device or start an emulator, then run `flutter run`. Grant the requested audio/video access and use **Scan device** to load the local library. Internet connectivity is not used by the app.

## Limitations

- MediaStore covers media indexed by Android. Files hidden from MediaStore or stored in arbitrary folders may need an explicit folder picker in a later stage.
- iOS and desktop library scanning are not implemented yet.
- Background audio, playlists, persisted history, subtitles, equalizer, and advanced video gestures remain planned work; the interface must not imply these are available until implemented.
