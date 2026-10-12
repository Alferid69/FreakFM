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
- **Quick-Access Grid**: 2-column (4 on wide screens) grid of 4 tiles — Liked Songs, Most Played, Recently Added, Shuffle All — each with a 56px gradient icon block on the left and a bold title on `#2A2A2A` (6px radius). Tiles with nothing to play are dimmed.
- **Track List Tile**: 48x48 rounded album art (4px radius). When currently playing, the track title shines in Spotify Green `#1DB954` with a speaker/equalizer icon. Heart toggle on the right.
- **Spotify Mini Player**: `#242424` card with 8px radius. Left: 42x42 cover art + track title & artist. Right: lyrics, heart, play/pause, next. Bottom edge: 2px Spotify Green progress bar. Swipe left/right to skip, swipe up (or tap) to expand.
- **Spotify Full Player**: Deep gradient background (`#383838` to `#121212`), "Playing from" context in the header, hero square cover with soft shadow, thin seek slider that seeks on release, white 64x64 play button, green shuffle/repeat states, a row of pill chips (speed, EQ) between ±10 s buttons, and a live lyrics preview card.
- **Song Menu (bottom sheet)**: Opened from a track's ⋮ or long-press. Header with cover, title and artist, then list actions: Play next, Add to queue, Like, Song info, Hide this folder.
- **Tab Pills**: The selected pill auto-scrolls into view; the right edge fades to signal more tabs. System Back closes an open album/artist/genre/folder, then returns to Songs.
