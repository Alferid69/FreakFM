# Publishing FreakFM on Google Play

Everything in the repo is ready. These are the steps only you can do.

## 1. One-time: signing secrets (GitHub)
Repo → Settings → Secrets and variables → Actions → New repository secret:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
The keystore + values live in `C:\Users\<you>\freakfm-signing\` (**back it up; never commit it**).
Releases built by CI are then signed with this key and ship a Play-ready `.aab` next to the APKs.

## 2. Play Console
1. Create a developer account (one-time US$25 fee; new personal accounts must run a closed test with 12+ testers for 14 days before production).
2. Create app → name **FreakFM**, default language English, App, Free.
3. Enrol in **Play App Signing** when uploading the first `.aab` (your key becomes the *upload key*).
4. Upload `freakfm-<tag>.aab` from the GitHub release to a Closed/Internal testing track.

## 3. Store listing (copy/paste)
- **Short description (≤80):** Offline music player with Spotify-style design, lyrics and equalizer.
- **Full description:**
  FreakFM plays the music already on your phone — no account, no ads, no streaming.
  • Finds every song on your device automatically
  • Spotify-inspired Home, Search and Your Library
  • Albums, artists, playlists, liked songs, queue, sleep timer, playback speed
  • Synced lyrics (LRCLIB) and shareable lyric cards
  • Real equalizer, gapless background playback, lock-screen controls
- **Icon:** `docs/play-store/icon-512.png`
- **Feature graphic:** `docs/play-store/feature-graphic-1024x500.png`
- **Phone screenshots:** `docs/screenshots/*.png` (take fresh ones from a device if you like)
- **Category:** Music & Audio. **Contact email:** alfeman4@gmail.com
- **Privacy policy URL:** https://github.com/Alferid69/freak_shit_show/blob/main/docs/PRIVACY.md

## 4. Policy forms
- **Data safety:** collects no data; data sent off-device: song title/artist/album for lyrics lookup (not linked to identity, encrypted in transit).
- **Content rating:** questionnaire → Everyone.
- **Ads:** none. **Target audience:** 13+ (not for children).
- **Permission declaration:** `READ_MEDIA_AUDIO` — core function is playing the user's own audio files. `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — background music playback.
- **Target API level:** set by Flutter (currently meets Play's requirement).
