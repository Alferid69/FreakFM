# DESIGN.md

## Design System: Spotify Dark Theme & Impeccable Craft

### 1. Palette
- **Base Background**: `#121212` (Spotify signature pitch dark)
- **Top Bar / Navigation**: `#000000` (Pure black with subtle transparency/elevation)
- **Cards & Row Surfaces**: `#181818` (Default card surface)
- **Elevated Surfaces**: `#242424` (Hovered tracks, dialogs, elevated chips)
- **Highlight Surfaces**: `#2A2A2A` (Active pressed states, inactive pill filters)
- **Spotify Accent**: `#1DB954` (Iconic Spotify Green)
- **Spotify Accent Hover**: `#1ED760` (Brighter green on hover/interaction)
- **Spotify Accent Dark**: `#169C46` (Pressed green)
- **Primary Text**: `#FFFFFF` (High-contrast pure white)
- **Secondary Text**: `#B3B3B3` (Light neutral gray for artists, subtitles, inactive nav)
- **Subdued Text**: `#727272` (Metadata, durations, timestamps)
- **Borders & Dividers**: `#282828` or borderless surface separation

### 2. Typography
- **Font Family**: Inter (Circular-styled geometric sans)
- **Scale**:
  - Greeting / Hero: 24–28px, Bold (`FontWeight.w800`), tracking `-0.4`
  - Section Header: 18–20px, Bold (`FontWeight.w700`), tracking `-0.2`
  - Item / Track Title: 15–16px, Semi-Bold (`FontWeight.w600`)
  - Subtitle / Artist: 13–14px, Regular (`FontWeight.w400`)
  - Badge / Caption: 11–12px, Semi-Bold (`FontWeight.w600`)

### 3. Iconic Spotify Components
- **Filter Pills**: Pill-shaped horizontal chip list (`borderRadius: 24`). Selected pill is Spotify Green (`#1DB954`) or white (`#FFFFFF`) with pure black text (`#000000`, `w700`), unselected is `#2A2A2A` with `#FFFFFF` text.
- **Quick-Access Grid**: 2-column compact grid of 6 tiles with square album art on the left (56x56) and bold title on `#282828` with rounded corners (4px).
- **Track List Tile**: 48x48 rounded album art (4px radius). When currently playing, the track title shines in Spotify Green `#1DB954` with a speaker/equalizer icon. Heart toggle on the right.
- **Spotify Mini Player**: `#242424` card with 8px radius or docked `#181818` bar. Left: 44x44 cover art + track title & artist. Right: play/pause, next, heart. Bottom edge: 2px slim Spotify Green playback progress bar.
- **Spotify Full Player**: Dynamic deep gradient background (`#383838` to `#121212`), hero square album cover with soft shadow, sleek thin Spotify slider, giant white circular play button (64x64) with black icon, shuffle/repeat green indicator dots, and live synced lyrics sheet.
