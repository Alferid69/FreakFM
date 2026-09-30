# freak player 🎵

A high-performance, Spotify-inspired offline music player for **Android** and **Windows**, engineered with Flutter, low-latency audio pipelines, synchronized lyrics, and tactile media controls.

---

## ✨ Features

- **⚡ Sub-Second Storage Scanner**: Discovers and indexes 1,000+ local music tracks in under 1 second using background Dart isolates and MediaStore projections.
- **🎨 Impeccable Spotify Design**: Full Spotify dark obsidian theme (`#121212`), high-contrast typography, seamless mini player, and immersive full-screen hero player with a vinyl turntable toggle.
- **🎤 Synchronized Lyrics**: Real-time auto-scrolling synced lyrics fetched from free sources (LRCLIB) with persistent offline disk caching.
- **🖼️ Spotify Lyrics Sharing**:
  - Interactive multi-line selection (up to 5 lines).
  - Live card preview with 7 curated gradient palettes (Spotify Obsidian, Emerald, Neon Velvet, Sunset, etc.).
  - High-DPI card export (3.0x ratio, 1080p+) for Instagram Stories, WhatsApp, and Telegram.
  - Formatted text copying and direct 1-tap image download.
- **🎧 Bluetooth & AirPods Hardware Controls**:
  - Full AVRCP media button support (single tap, double-click play/pause, next, previous).
  - Explicit audio focus management (`AUDIOFOCUS_GAIN`) preventing conflicts with other background players.
- **🖼️ Embedded Album Artwork**:
  - Native Android `MediaMetadataRetriever` / `loadThumbnail` extraction with disk caching.
  - Broadcasts genuine track cover art to Android lock screens, notification controls, and Bluetooth car dashboards.
- **🎛️ Hi-Fi Audio Suite**:
  - In-app volume control independent of system master volume.
  - Equalizer presets (Bass Boost, Vocal Clarity, Electronic, Acoustic, Rock).
  - Animated audio waveform visualizer and turntable mode.

---

## 📱 Platforms

- **Android** (API 21+ / Android 5.0 to 14+, supports arm64-v8a, armeabi-v7a, x86_64)
- **Windows** (Windows 10/11 x64)

---

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x / Dart 3.x
- **Audio Engine**: `audioplayers` & `audio_service`
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

---

## 📄 License
This project is open-source under the MIT License.
