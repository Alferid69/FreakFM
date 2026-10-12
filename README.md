# freak player 🎵

A high-performance, Spotify-inspired offline music player for **Android** and **Windows**, engineered with Flutter, low-latency audio pipelines, synchronized lyrics, and tactile media controls.

---

## ✨ Features

- **⚡ Library Scanner**: Indexes your music folders (Music / Download by default, plus any folder you add) using MediaStore and a background-isolate tag reader. Audio stored by other apps (Quran readers, messengers, podcast apps), `.nomedia` folders, ringtones and recordings are skipped, and any folder can be hidden from the Folders tab.
- **💾 Persistent library**: Favourites, play counts and learned durations are saved automatically and survive rescans.
- **🎨 Impeccable Spotify Design**: Full Spotify dark obsidian theme (`#121212`), high-contrast typography, seamless mini player, and immersive full-screen hero player with a vinyl turntable toggle.
- **🎤 Synchronized Lyrics**: Real-time auto-scrolling synced lyrics fetched from free sources (LRCLIB) with persistent offline disk caching.
- **🖼️ Spotify Lyrics Sharing**:
  - Interactive multi-line selection (up to 5 lines).
  - Live card preview with 7 curated gradient palettes (Spotify Obsidian, Emerald, Neon Velvet, Sunset, etc.).
  - High-DPI card export (3.0x ratio, 1080p+) for Instagram Stories, WhatsApp, and Telegram.
  - Formatted text copying and direct 1-tap image download.
- **🎧 Bluetooth & AirPods Hardware Controls**:
  - Full AVRCP media button support (single tap, double-click play/pause, next, previous).
  - Audio focus handling: ducks/pauses for calls and other apps, and pauses when headphones are unplugged.
- **🖼️ Embedded Album Artwork**:
  - Native Android `MediaMetadataRetriever` / `loadThumbnail` extraction with disk caching.
  - Broadcasts genuine track cover art to Android lock screens, notification controls, and Bluetooth car dashboards.
- **🎛️ Hi-Fi Audio Suite**:
  - In-app volume control independent of system master volume.
  - Real hardware equalizer on Android (presets + per-band sliders backed by `android.media.audiofx.Equalizer`).
  - Decorative waveform animation and turntable mode.

---

## 📱 Platforms

- **Android** (API 21+ / Android 5.0 to 14+, supports arm64-v8a, armeabi-v7a, x86_64)
- **Windows** (Windows 10/11 x64)

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x / Dart 3.x
- **Audio Engine**: `just_audio` (+ `just_audio_windows`), `audio_session`, `audio_service`
- **Tags & Artwork**: `audio_metadata_reader`
- **Native Android**: Kotlin, MediaStore API, AndroidX Media, FileProvider
- **Storage & Cache**: `shared_preferences`, `path_provider`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.12+ recommended)
- Android SDK / Android Studio (for Android builds)
- Visual Studio 2022 with C++ Desktop Workload (for Windows builds)

### Installation
```bash
# Clone the repository
git clone https://github.com/Alferid69/freak_shit_show.git

# Navigate to project directory
cd freak_shit_show

# Install dependencies
flutter pub get

# Run on connected device or Windows
flutter run
```

### Building Release Binaries
```bash
# Build Android split APKs (per ABI)
flutter build apk --split-per-abi

# Build Windows Release executable
flutter build windows --release
```

## 🧪 Tests

```bash
# Unit + widget tests (add --tags network to also hit the live lyrics API)
flutter test --exclude-tags network

# Integration tests: real scanning, playback, search and persistence
flutter test integration_test -d windows        # or -d <android-device-id>
```

## 🤖 CI & Releases

- **CI** (`.github/workflows/ci.yml`) runs on every push/PR to `main`: analyze, unit tests, and the integration suite on an Android emulator and on Windows.
- **Release** (`.github/workflows/release.yml`) runs when a `v*` tag is pushed (or manually). After the full test suite passes it builds one APK per ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and attaches them to a GitHub Release.

```bash
git tag v1.1.0 && git push origin v1.1.0
```

To sign releases with your own key, add the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. Without them the APKs are debug-signed (installable, not Play Store-ready).

---

## 📄 License
This project is open-source under the MIT License.
