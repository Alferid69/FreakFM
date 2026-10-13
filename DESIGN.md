# DESIGN.md

## Design system: Spotify-style dark UI

The app follows the layout and visual language of Spotify's mobile app, adapted to a local, offline library. It uses no Spotify assets, logos or fonts.

### 1. Colour
- **Base**: `#121212`. **Raised surfaces**: `#1F1F1F`, `#282828` (sheets, cards), `#2A2A2A` (pills, shortcut tiles).
- **Accent**: Spotify green `#1ED760` (play buttons, active shuffle/repeat, liked ticks, playing song).
- **Text**: white `#FFFFFF`; secondary `#B3B3B3`; subdued `#7A7A7A`.
- **Cover colour**: every song gets a backdrop colour from its artwork (`ArtColorService`): a saturation-weighted average of a 24×24 downscale, lightness capped at 0.38 so white text stays readable. It drives the album/artist page headers, Now Playing, the mini player and the Home tint. Songs without artwork get a stable colour from their album name.
- **Category colours**: a fixed palette (`AppTheme.categoryColors`) for genre tiles and placeholders, picked by a hash of the name.

### 2. Typography
- **Figtree** (bundled, OFL), a geometric sans close to Spotify's typeface.
- Page titles 24–26 / w800 / tight tracking; section headers 22 / w700; song titles 16 / w500; subtitles 13–14 / regular, grey; captions 10.5–12.

### 3. Structure
- **Bottom bar**: Home, Search, Your Library. Icons with small labels over a transparent-to-black fade. Each tab keeps its own navigation stack; re-tapping a tab returns to its first page.
- **Mini player**: a floating 58 px card with a 6 px radius, tinted with the cover colour. Cover, title/artist, like (+ / green tick), play/pause, and a 2 px white progress line. Tap or swipe up to expand; swipe sideways to skip.
- **Back**: closes the open page, then returns to Home, then exits.

### 4. Components
- **Filter pills**: `#2A2A2A` stadium chips; the selected one is green with black text. They scroll sideways when space runs out.
- **Shortcut tile** (Home): 56 px tall, cover on the left, bold two-line title on `#2A2A2A`, a playing indicator when active.
- **Shelf card**: 140–150 px cover (round for artists) with a title and grey subtitle; used in horizontal shelves.
- **Library row**: 64 px cover (round for artists), title, and "Type • detail"; a green pin on pinned playlists.
- **Song row**: 48 px cover (hidden on album pages), title (green while playing, with a small equalizer), artist, a like toggle, and ⋮. Long-press also opens the song menu.
- **Collection page**: a header gradient from the cover colour, a centred cover with a deep shadow, the title, details and an action row (⋮ … shuffle toggle, 56 px green play button). The top bar fills with colour and shows the title once you scroll past the header.
- **Now Playing**: a full-screen gradient from the cover colour, "PLAYING FROM <TYPE>" header, a cover sized to keep the controls on screen, a thin white seek bar (seeks on release), and a 64 px white play button. Shuffle and repeat turn green with a dot. Below: the lyrics card (a lighter cover colour, current line white, upcoming lines dark), Next in queue, and About this song.
- **Lyrics page**: a solid lighter cover colour with 24 px bold lines; sung lines white, upcoming lines at 55 % black.
- **Search**: a white 6 px-radius search field with a black icon; "Browse all" genre tiles with a tilted cover in the corner.
- **Sheets**: `#282828` with a 16 px top radius and a drag handle.
