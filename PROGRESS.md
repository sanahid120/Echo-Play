# EchoPlay progress

Last updated: 2026-11-18

## Current work

### Stage 1 — Foundation and local library

- [x] Replace the Flutter counter starter with EchoPlay's application entry point and dark visual foundation.
- [x] Define the offline-only product scope and architecture in `PROJECT.md`.
- [x] Add Android MediaStore audio/video discovery through a small platform channel.
- [x] Add scoped Android media permissions (audio/video on Android 13+, legacy read permission on older versions).
- [x] Add explicit scan/re-scan flow and combined search across local audio and video.
- [x] Connect basic local-file audio playback with a persistent mini-player.
- [x] Connect basic local-file video playback with seek controls.
- [x] Page MediaStore scans and yield between batches to keep large library results from arriving in one UI-isolate message.
- [x] Debounce search input and reduce redundant per-item query normalization during rebuilds.
- [ ] Validate permission and playback behavior on a physical Android device.
- [x] Resolve package versions with `flutter pub get`.
- [x] Rebuild after scan batching changes.
- [ ] Launch on an Android device and validate permissions and local playback.

## Implemented in this iteration

- Android scanner queries indexed audio and video, returning title, artist, duration, path, and media type.
- Library screen offers Home/Music/Videos/Library destinations, local search, scan progress, empty state, and retry on scan errors.
- Audio rows play local paths with `just_audio` and a play/pause mini-player; video rows open a local `video_player` screen with a seek bar.
- Riverpod, router, and Drift/SQLite packages are selected in the manifest; feature state and database migration are still pending.
- App uses no internet media URLs.
- Disabled Kotlin incremental compilation in `android/gradle.properties` to work around Windows cross-drive cache path failures when the workspace is on `D:` and Pub cache is on `C:`.
- The pre-batching build succeeded in 622 seconds. After the paging changes, `flutter build apk --debug` succeeded in 284 seconds and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- Scan work is split into Android MediaStore pages (200 records per platform-channel call); the UI yields between pages and only refreshes progress once per 1,000 results.
- Search updates are debounced by 180 ms, and query normalization is done once per build instead of once per item.

## Known gaps

- Audio queue, background playback, and the full video control surface remain future work.
- Local database, favorites, playlists, queue, playback history/resume, metadata artwork, and background controls are not implemented.
- Android MediaStore cannot discover every arbitrary unindexed file; iOS/desktop scanning needs separate platform work.
- Dependency resolution and the post-batching debug APK compilation completed successfully. Responsiveness on a large real-world library has not been benchmarked; automated tests and on-device playback checks have not been run.

## Next steps

1. Launch on Android with a large library and check permission behavior, scan responsiveness, and local playback.
2. Move library and playback state into Riverpod providers and add the first Drift schema for favorites, playlists, and playback positions.
3. Add background audio, notification controls, queue, and resume positions.
4. Expand the video player controls and add platform-specific library support outside Android.
