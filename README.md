# EchoPlay

EchoPlay is a local music and video player for Android. It scans media already indexed on the device and plays local files; it does not stream music or video from the internet.

## Current features

- Scan Android MediaStore for audio and video.
- Search local titles, artists, albums, and paths.
- Browse Home, Music, Videos, and Library destinations.
- Play audio with a mini-player and video with basic playback and seeking.
- Scan in 200-item pages and debounce library search to reduce UI-isolate work.
- Request audio/video access at scan time using Android's scoped media permissions.

## Getting started

1. Install Flutter and Android Studio, then connect an Android device or start an emulator.
2. Run `flutter pub get`.
3. Run `flutter run` from this directory.
4. Tap **Scan device** and grant media access.

Android 13 and newer use separate audio and video permissions. Older Android versions use the legacy read-storage permission. The scanner uses MediaStore and may not include files hidden from the Android media index.

## Project notes

- [PROJECT.md](PROJECT.md) describes the architecture, offline guarantee, and product scope.
- [PROGRESS.md](PROGRESS.md) tracks implemented work and next steps.
- The first working slice targets Android. Other platforms need platform-specific library access.
- Actual format playback depends on codecs provided by the operating system.
