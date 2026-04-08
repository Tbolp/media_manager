# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

This is a monorepo for **家庭影院 (Home Cinema)** — a self-hosted media server system:

```
backend/    Go HTTP server (serves API + embedded React frontend)
frontend/   React/Vite web frontend
mobile/     Flutter Android app (primary focus)
Makefile    Top-level commands for backend + frontend
```

## Flutter App — Commands (run from `mobile/`)

```bash
# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release

# Code generation (must re-run after editing any @riverpod annotated file)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation during development
dart run build_runner watch --delete-conflicting-outputs

# Lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart
```

## Backend + Frontend — Commands (run from repo root)

```bash
make dev            # Start backend (localhost:8080) + frontend (localhost:3000) simultaneously
make dev-backend    # Backend only
make dev-frontend   # Frontend only
make install        # Install frontend npm deps
make build          # Build frontend → embed into Go binary → compile binary
make release        # Cross-compile for all platforms (linux/darwin/windows × amd64/arm64)
```

## Flutter Architecture

### Feature-First Structure
```
lib/
  app.dart                    MaterialApp.router shell with global NetworkBanner overlay
  main.dart                   Bootstrap: MediaKit init, SharedPreferences, auth session restore
  core/
    router/                   GoRouter setup + route path constants
    network/                  Dio singleton, AuthInterceptor, ErrorInterceptor
    storage/                  SecureStorage (JWT) + PrefsStorage (serverUrl, viewMode)
    constants.dart            App-wide constants (thresholds, durations, keys)
    exceptions.dart           Typed exception hierarchy: AppException subclasses
  features/
    auth/                     Server setup, login — data/domain/presentation layers
    library/                  Home list, library detail, directory browsing, file tiles
    player/                   Video player page + image preview overlay
    settings/                 Settings state (serverUrl, libraryViewMode)
  shared/
    utils/                    UrlBuilder (thumbnail/video URLs), DurationFormat
    widgets/                  NetworkBanner, skeleton loaders, EmptyState
```

Each feature follows `data/` → `domain/` → `presentation/` layers.

### State Management: Riverpod 2.x with Code Generation
- Every provider uses `@riverpod` / `@Riverpod` annotations → generates `.g.dart` files via `build_runner`
- **Never edit `.g.dart` files manually**
- `keepAlive: true` only on `appRouterProvider`; all others auto-dispose
- `AsyncValue<T>` used throughout for loading/error/data states

### Routing: go_router with reactive auth guard
- Route constants in `lib/core/router/routes.dart`
- Single `redirect` callback in `app_router.dart` checks: server URL configured → logged in → home
- `router.refresh()` triggered via `ref.listen` on `authNotifierProvider` and `settingsNotifierProvider`
- **Directory drill-down is in-page state** (`CurrentPathNotifier`), not router-based — avoids deep back-stacks
- Image preview uses a transparent `PageRouteBuilder` overlay, not in the go_router graph
- `PopScope` in `library_detail_page.dart` intercepts Android back button to navigate up the directory tree

### Network Layer
- Single `Dio` instance, rebuilt only when `serverUrl` changes
- `AuthInterceptor` reads token per-request; on 401 calls `forceLogout` via `_authCallbackProvider`
- `ErrorInterceptor` maps HTTP status codes → typed `AppException` subclasses
- Thumbnail/video URLs include `?token=<jwt>` as query param (instead of headers) for compatibility with `CachedNetworkImage` and `media_kit`

### App Startup Sequence
```
main()
  → SharedPreferences.getInstance()
  → ProviderContainer with prefsStorageProvider override
  → authNotifier.restoreSession()  ← GET /api/me with saved token
  → runApp(UncontrolledProviderScope)
  → GoRouter redirect → correct first page (server / login / home)
```

### Video Player (`lib/features/player/presentation/video_player_page.dart`)
- Uses `media_kit` + `media_kit_video`; requires `minSdkVersion 21`
- Enters immersive landscape mode on init, restores portrait + system UI on dispose
- Gesture system: single-tap=toggle controls, double-tap±=seek ±15s, long-press=2× speed, horizontal pan=seek, left vertical pan=brightness, right vertical pan=volume
- Progress (position/duration) reported to API on `AppLifecycleState.paused/detached` and `dispose()`
- Auto-resumes playback position if saved progress < 90% (`AppConstants.watchedThreshold`)

### Key Constants (`lib/core/constants.dart`)
| Constant | Value |
|---|---|
| `watchedThreshold` | 0.9 (90% → mark as watched) |
| `seekSeconds` | 15 |
| `longPressRate` | 2.0× |
| `searchDebounce` | 300 ms |
| `refreshPollInterval` | 5 s |

### Android-Specific Notes
- `usesCleartextTraffic="true"` in `AndroidManifest.xml` — supports LAN `http://` addresses
- JWT stored with `encryptedSharedPreferences: true` (Android KeyStore)
- Screen orientation: `"unspecified"` in manifest, controlled programmatically via `SystemChrome`
