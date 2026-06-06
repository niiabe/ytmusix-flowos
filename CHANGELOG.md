# Changelog

## 1.5.0

- Overhauled the Now Playing portrait layout to match Apple Music: sheet drag handle, enlarged artwork (240–330 px), bigger title/artist text, negative remaining time display, and an inline micro quality/bitrate badge.
- Consolidated all Now Playing action controls (Lyrics, Crossfade, Auto DJ, Save, Queue) into a single premium bottom row bar.
- Replaced skip-previous/next icons with fast-rewind/fast-forward across all player layouts and the mini-player bar.
- Removed the filled-circle background from the play/pause button for a flat Apple Music aesthetic.
- Enlarged secondary control icons (shuffle, repeat, skip) from 24 → 28 px for better visual weight.
- Added Auto DJ continuation system with five modes: Library Shuffle, Similar Songs, Same Genre, Same Artist, and Smart Mix.
- Equal-power crossfade with dynamic pitch warping during active/inactive player transitions.
- Auto DJ mode and songs-count preference persisted to SharedPreferences; mode selector available as an interactive bottom sheet in both portrait and wide layouts.
- Added Apple Music-style synced lyrics view with animated active-line highlight (AnimatedDefaultTextStyle), ShaderMask gradient fade at scroll edges, and 40 % viewport auto-scroll centering.
- Hidden mini album art in portrait player when inline lyrics are showing to maximize lyrics height.
- Fixed Recent tab routing: clicking a track now plays it directly instead of treating it as a playlist.
- Albums on the home browse shelf now navigate directly to the AlbumScreen detail page.
- Single-track playlists on the browse shelf now play immediately without opening the detail view.

## 1.4.2

- Redesigned search results screen utilizing standard TrackTile and CachedNetworkImage.
- Removed search category results limits by parallelizing search queries.
- Converted search tabs into pill-shaped chips with dynamic active highlights.
- Implemented seamless position handoff and playback synchronization between audio and video modes.
- Ensured video player auto-pauses background audio to prevent double playback sound.
- Added auto-advance navigation progression when video playback completes.

## 1.4.1

- Fixed background audio playback and track auto-play progression on Android.
- Introduced a toggleable 7-second crossfade feature on the Now Playing screen.

## 1.4.0

- Added favorite collection support (playlists and albums).
- Fully rebuilt iOS background playback auto-advance and dynamic island integration.
- Resolved layout overflow bugs and optimized the Now Playing FAB with dynamic sizing.

## 1.3.0

- Added floating player controls with play/pause and progress seekbar border to FAB.
- Removed mini-player layout.
- Optimized audio quality settings defaults.
- Added geo-restrictions bypass.
- Resolved playlist duration mapping.
- Fixed search playlist navigation and adjusted artist page layouts.

## 1.2.0

- Added Apple Music chart shelves with scoped Top 100 songs, album detail playback, recommendation autoplay, cached chart/search lookups, a custom video player, and refreshed About details.

## 1.1.0

- Improved playlist browsing, downloads, favourites, queue tools, and playback controls.

## 1.0.0

- Initial Android release for streaming public YouTube playlists, videos, and mixes.
