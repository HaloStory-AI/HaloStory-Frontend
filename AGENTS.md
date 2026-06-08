# AGENTS.md — Developer & Contributor Guide

## Project Overview

**HaloStory** (formerly BlueTalk) — Flutter app, Blue Archive MomoTalk simulator. AI-powered student chat, profiles, backups.

## Tech Stack

- Flutter (Dart), SDK ^3.10.8
- State: StatefulWidget + SharedPreferences (no Bloc/Riverpod)
- REST API via `http` package; local cache via `shared_preferences`
- Chat files: JSON on disk (platform-specific dirs), settings: SharedPreferences
- Localization: custom `tr()` function (`lib/services/localization_service.dart`)

## Build & Run

```bash
flutter pub get
flutter run                  # default platform
flutter build apk --release --split-per-abi   # Android
flutter build linux --release                 # Linux (needs: clang cmake ninja-build pkg-config libgtk-3-dev)
flutter build windows --release              # Windows
```

- CI builds on push/PR to `main` (`.github/workflows/flutter_build.yml`): Android, Linux, Windows
- Android release requires signing key (CI decodes keystore from secrets)
- Windows installer built with Inno Setup (`installer/setup.iss`)

## Static Analysis

```bash
flutter analyze
```

Uses `package:flutter_lints/flutter.yaml`. No custom lint rules enabled.

## Project Structure

```
lib/
├── main.dart                   # App entry — init services, background ban check, connectivity listener
├── constants.dart              # API URLs, static token (dev vs prod via ConfigService)
├── screens/
│   ├── splash_screen.dart      # App init flow (see below)
│   ├── home_screen.dart        # Tab container (mobile)
│   ├── desktop_home_screen.dart
│   ├── pin_screen.dart         # 6-digit PIN entry (SHA-256 hashed)
│   ├── chat_screen.dart        # Chat detail (messages, bond, AI)
│   ├── select_contact_screen.dart
│   ├── settings_screen.dart    # Settings hub → sub-pages
│   ├── settings/               # Sub-pages: privacy, backup, AI engine, appearance, general, developer
│   └── tabs/                   # chat_tab, stories_tab, calendar_tab, more_tab
├── services/
│   ├── bot_service.dart        # Bot API + multi-layer cache (memory/SP/_knownBots)
│   ├── local_chat_service.dart # Chat file I/O, pinned chats, summaries, atomic writes
│   ├── auth_service.dart       # Token-based auth
│   ├── ai_service.dart         # AI inference calls
│   ├── config_service.dart     # Remote config (GitHub), server health
│   ├── localization_service.dart # tr() global helper
│   ├── security_service.dart   # Device compromise detection
│   ├── ban_service.dart        # User ban check
│   └── ...
├── widgets/                    # Reusable UI components
├── responsive/                 # Responsive layout helpers
└── theme/                      # App themes (light + AMOLED dark)
```

## Key Service Details

### BotService (`lib/services/bot_service.dart`)
- `getBots(type: 'all')` — default type is `'all'` (fetches ALL bots, not just Main)
- Cache: memory 10min, SharedPreferences 5min fresh / 24h stale-while-revalidate
- `_knownBots` dict persisted in SharedPreferences (`known_bots_dict`)
- `getBotById(id)` — local lookup only, no API call
- Event bots: `getBots(type: 'Event', category: cat)` — no caching

### LocalChatService (`lib/services/local_chat_service.dart`)
- Chat files: `{chatId}.json` in platform dirs (`BlueTalkData` on Android, `HaloStoryData` on desktop)
- Atomic writes: `.tmp` file then rename
- `getAllChatMetadata()` — scans dir for `.json` files
- `loadChat(chatId)` — supports array or `{messages:[]}` format
- `onChatUpdated` stream broadcasts chatId on save/delete

### AuthService (`lib/services/auth_service.dart`)
- Bearer token in headers
- PIN stored as SHA-256 hash, never plain text

## App Init Flow (`splash_screen.dart`)

```
Connectivity check → ConfigService init → Maintenance check
→ Update check → Web notice / Permission request → Parallel fetch:
  [isLoggedIn, getBots(type:'all'), isDeviceCompromised, delay]
→ Logged in? → Email verified? → Contributor notice → Security notice
→ App lock enabled? → PinScreen → Home / Setup
→ Not logged in? → Ban check → WelcomeScreen
```

Background: `main.dart` runs 2-min periodic timer for server ping + ban check.

## Conventions

- All user-visible strings: `tr('key')` — never hardcode. Lang files: `assets/lang/{en,id,zh,ja,ko}.json` — add to **all 5** when adding keys.
- `if (!mounted) return;` after every async gap in StatefulWidgets
- `withValues(alpha: ...)` instead of deprecated `withOpacity()` (3 remaining usages in `story_view_screen.dart`)
- Chat files use atomic writes (tmp + rename) to prevent corruption
- Bot data cached aggressively (memory + SharedPreferences)
- PIN: SHA-256 hash stored in SharedPreferences
- API base URL: hardcoded dev URL in debug mode, remote config via `ConfigService` in release
