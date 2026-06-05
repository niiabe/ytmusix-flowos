import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import '../../core/constants/repeat_mode.dart' as repeat;
import '../../core/constants/audio_quality.dart';
import '../../core/utils/format_duration.dart';
import '../../domain/entities/video.dart';
import '../../service/lyrics_service.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/queue_sheet.dart';
import 'album_screen.dart';
import 'artist_screen.dart';

enum _PlaybackMode { audio, video }

final _lyricsService = LyricsService();

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  _PlaybackMode _playbackMode = _PlaybackMode.audio;
  bool _audioPausedForVideo = false;
  VideoPlayerController? _activeVideoController;
  bool _showLyricsInline = false;
  Track? _lastTrack;
  Future<LyricsResult?>? _lyricsFuture;

  @override
  void dispose() {
    if (_activeVideoController != null) {
      _activeVideoController!.removeListener(_onVideoControllerTick);
      if (_activeVideoController!.value.isPlaying) {
        _activeVideoController!.pause();
      }
    }
    if (_audioPausedForVideo) {
      try {
        final player = context.read<PlayerProvider>();
        if (!player.isPlaying) {
          player.togglePlayPause();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  void _onVideoControllerInitialized(VideoPlayerController? controller) {
    if (_activeVideoController != null) {
      _activeVideoController!.removeListener(_onVideoControllerTick);
    }
    _activeVideoController = controller;
    if (_activeVideoController != null) {
      _activeVideoController!.addListener(_onVideoControllerTick);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onVideoControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      PlayerProvider,
      SettingsProvider,
      PlaylistProvider,
      DownloadProvider
    >(
      builder: (context, player, settings, playlistProvider, downloadProvider, _) {
        if (player.currentTrack == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Player')),
            body: const Center(child: Text('No track playing')),
          );
        }

        final track = player.currentTrack!;
        final isFav = playlistProvider.isFavorite(track.id);

        if (_lastTrack?.id != track.id) {
          _lastTrack = track;
          _lyricsFuture = _lyricsService.getLyrics(track);
        }

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _BlurredArtworkBackground(imageUrl: track.thumbnailUrl),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isAudio = _playbackMode == _PlaybackMode.audio;
                    final compact = constraints.maxHeight < 760;
                    final isWide = constraints.maxWidth > 720;
                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(36, 24, 36, 24),
                        child: Column(
                          children: [
                            _buildPlayerHeader(context, player),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 440,
                                          maxHeight: 440,
                                        ),
                                        child: isAudio
                                            ? _ArtworkLyricsStage(
                                                imageUrl: track.thumbnailUrl,
                                                showLyrics: _showLyricsInline,
                                                lyricsFuture: _lyricsFuture,
                                              )
                                            : _InlineVideoPlayer(
                                                key: ValueKey(
                                                  'video-${track.id}',
                                                ),
                                                track: track,
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 480,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        track.title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        track.author ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 1.2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons
                                                        .compare_arrows_rounded,
                                                    color:
                                                        settings
                                                            .crossfadeEnabled
                                                        ? Colors.greenAccent
                                                        : Colors.white54,
                                                  ),
                                                  tooltip: 'Crossfade (7s)',
                                                  onPressed: () {
                                                    final nextVal = !settings
                                                        .crossfadeEnabled;
                                                    settings
                                                        .setCrossfadeEnabled(
                                                          nextVal,
                                                        );
                                                    player.setCrossfadeEnabled(
                                                      nextVal,
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.bubble_chart_rounded,
                                                    color:
                                                        settings.autoDjMode !=
                                                            'off'
                                                        ? Colors.greenAccent
                                                        : Colors.white54,
                                                  ),
                                                  tooltip:
                                                      'Auto DJ (${settings.autoDjMode})',
                                                  onPressed: () =>
                                                      _showAutoDjMenu(
                                                        context,
                                                        settings,
                                                      ),
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    isFav
                                                        ? Icons.favorite_rounded
                                                        : Icons
                                                              .favorite_border_rounded,
                                                    color: Colors.white,
                                                  ),
                                                  tooltip: isFav
                                                      ? 'Remove from favorites'
                                                      : 'Add to favorites',
                                                  onPressed: () =>
                                                      playlistProvider
                                                          .toggleFavorite(
                                                            track,
                                                          ),
                                                ),
                                              ],
                                            ),
                                            if (isAudio) ...[
                                              const SizedBox(height: 36),
                                              _SeekWaveform(
                                                position: player.position,
                                                duration: player.duration,
                                                bufferedPosition:
                                                    player.bufferedPosition,
                                                isPlaying: player.isPlaying,
                                                trackId: track.id,
                                                onSeek: player.seekTo,
                                              ),
                                              const SizedBox(height: 28),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _ControlButton(
                                                    icon: Icons.shuffle_rounded,
                                                    active: player.shuffleMode,
                                                    onPressed:
                                                        player.toggleShuffle,
                                                  ),
                                                  _ControlButton(
                                                    icon: Icons
                                                        .fast_rewind_rounded,
                                                    onPressed: player.previous,
                                                  ),
                                                  player.isLoading
                                                      ? const SizedBox(
                                                          width: 64,
                                                          height: 64,
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.5,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        )
                                                      : IconButton(
                                                          icon: Icon(
                                                            player.isPlaying
                                                                ? Icons
                                                                      .pause_rounded
                                                                : Icons
                                                                      .play_arrow_rounded,
                                                            size: 64,
                                                            color: Colors.white,
                                                          ),
                                                          onPressed: player
                                                              .togglePlayPause,
                                                        ),
                                                  _ControlButton(
                                                    icon: Icons
                                                        .fast_forward_rounded,
                                                    onPressed:
                                                        player.currentIndex +
                                                                1 <
                                                            player.queue.length
                                                        ? () => player.next()
                                                        : null,
                                                  ),
                                                  _ControlButton(
                                                    icon: _repeatIconData(
                                                      player.repeatMode,
                                                    ),
                                                    active:
                                                        player.repeatMode !=
                                                        repeat
                                                            .PlaybackRepeatMode
                                                            .none,
                                                    onPressed:
                                                        player.cycleRepeatMode,
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 36),
                                            _buildQuickActions(
                                              context,
                                              player,
                                              track,
                                            ),
                                            const SizedBox(height: 16),
                                            _buildTrackQualityInfo(
                                              context,
                                              player,
                                              track,
                                              downloadProvider,
                                            ),
                                            if (player.error != null) ...[
                                              const SizedBox(height: 16),
                                              _PlayerErrorBanner(
                                                message: player.error!,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            12,
                            24,
                            compact ? 16 : 28,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPlayerHeader(context, player),
                              SizedBox(
                                height: isAudio
                                    ? (compact ? 18 : 28)
                                    : (compact ? 24 : 42),
                              ),
                              isAudio
                                  ? _ArtworkLyricsStage(
                                      imageUrl: track.thumbnailUrl,
                                      showLyrics: _showLyricsInline,
                                      lyricsFuture: _lyricsFuture,
                                    )
                                  : _InlineVideoPlayer(
                                      key: ValueKey('video-${track.id}'),
                                      track: track,
                                      shouldPlay:
                                          _audioPausedForVideo ||
                                          player.isPlaying,
                                      onControllerInitialized:
                                          _onVideoControllerInitialized,
                                    ),
                              SizedBox(height: isAudio ? 28 : 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          track.author ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withAlpha(
                                        20,
                                      ),
                                      shape: const CircleBorder(),
                                    ),
                                    icon: Icon(
                                      isFav
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: isFav
                                          ? Colors.amberAccent
                                          : Colors.white70,
                                    ),
                                    tooltip: isFav
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                    onPressed: () =>
                                        playlistProvider.toggleFavorite(track),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withAlpha(
                                        20,
                                      ),
                                      shape: const CircleBorder(),
                                    ),
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      color: Colors.white70,
                                    ),
                                    tooltip: 'More options',
                                    onPressed: () =>
                                        _showMoreSheet(context, player),
                                  ),
                                ],
                              ),
                              if (isAudio) ...[
                                SizedBox(height: compact ? 26 : 34),
                                _SeekWaveform(
                                  position: player.position,
                                  duration: player.duration,
                                  bufferedPosition: player.bufferedPosition,
                                  isPlaying: player.isPlaying,
                                  trackId: track.id,
                                  onSeek: player.seekTo,
                                  showTimestamps: false,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatDuration(player.position),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    _buildCompactQualityInfo(
                                      context,
                                      player,
                                      track,
                                      downloadProvider,
                                    ),
                                    Text(
                                      player.duration.inSeconds >
                                              player.position.inSeconds
                                          ? '-${formatDuration(player.duration - player.position)}'
                                          : '0:00',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 24 : 30),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fast_rewind_rounded,
                                        size: 46,
                                        color: Colors.white,
                                      ),
                                      onPressed: player.previous,
                                    ),
                                    player.isLoading
                                        ? const SizedBox(
                                            width: 68,
                                            height: 68,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : IconButton(
                                            icon: Icon(
                                              player.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 64,
                                              color: Colors.white,
                                            ),
                                            onPressed: player.togglePlayPause,
                                          ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fast_forward_rounded,
                                        size: 46,
                                        color: Colors.white,
                                      ),
                                      onPressed:
                                          player.currentIndex + 1 <
                                              player.queue.length
                                          ? () => player.next()
                                          : null,
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 18 : 22),
                              ] else if (_activeVideoController != null) ...[
                                _buildVideoControlsBelowTitle(
                                  context,
                                  player,
                                  track,
                                  _activeVideoController!,
                                  compact,
                                ),
                              ] else ...[
                                const SizedBox(height: 22),
                              ],
                              _buildQuickActions(context, player, track),
                              if (player.error != null) ...[
                                const SizedBox(height: 12),
                                _PlayerErrorBanner(message: player.error!),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAutoDjMenu(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161616),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.bubble_chart_rounded,
                    size: 24,
                    color: settings.autoDjMode != 'off'
                        ? Colors.greenAccent
                        : Colors.white54,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Auto DJ Continuation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose how the queue continues when it ends',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              ...[
                (
                  'off',
                  'Off',
                  'Playback stops when the queue ends',
                  Icons.power_settings_new_rounded,
                ),
                (
                  'shuffleLibrary',
                  'Library Shuffle',
                  'Picks random tracks from library',
                  Icons.shuffle_rounded,
                ),
                (
                  'similarSongs',
                  'Similar Songs',
                  'Appends YouTube recommendations',
                  Icons.graphic_eq_rounded,
                ),
                (
                  'sameGenre',
                  'Same Genre',
                  'Plays similar vibes and matching genres',
                  Icons.category_rounded,
                ),
                (
                  'sameArtist',
                  'Same Artist',
                  'Plays top hits from the current artist',
                  Icons.person_rounded,
                ),
                (
                  'smartMix',
                  'Smart Mix',
                  'Intelligent mix based on your listening habits',
                  Icons.bubble_chart_rounded,
                ),
              ].map((mode) {
                final isSelected = settings.autoDjMode == mode.$1;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      settings.setAutoDjMode(mode.$1);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            mode.$1 == 'off'
                                ? 'Auto DJ disabled'
                                : 'Auto DJ set to ${mode.$2}',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(30)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(120)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode.$4,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white60,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode.$2,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withAlpha(230),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  mode.$3,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white60
                                        : Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerHeader(BuildContext context, PlayerProvider player) {
    return Row(
      children: [
        _HeaderButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        _HeaderButton(
          icon: Icons.more_horiz_rounded,
          tooltip: 'More',
          onPressed: () => _showMoreSheet(context, player),
        ),
      ],
    );
  }

  Future<void> _selectVideoMode(PlayerProvider player) async {
    if (_playbackMode == _PlaybackMode.video) return;
    if (player.isPlaying) {
      await player.togglePlayPause();
      _audioPausedForVideo = true;
    } else {
      _audioPausedForVideo = false;
    }
    if (!mounted) return;
    setState(() => _playbackMode = _PlaybackMode.video);
  }

  Future<void> _selectAudioMode(PlayerProvider player) async {
    if (_playbackMode == _PlaybackMode.audio) return;

    final videoController = _activeVideoController;
    bool wasVideoPlaying = false;
    if (videoController != null && videoController.value.isInitialized) {
      final videoPos = videoController.value.position;
      await player.seekTo(videoPos);
      wasVideoPlaying = videoController.value.isPlaying;
      if (wasVideoPlaying) {
        await videoController.pause();
      }
    }

    setState(() => _playbackMode = _PlaybackMode.audio);
    if (wasVideoPlaying) {
      if (!player.isPlaying) {
        await player.togglePlayPause();
      }
    } else {
      if (player.isPlaying) {
        await player.togglePlayPause();
      }
    }
    _audioPausedForVideo = false;
  }

  Widget _buildQuickActions(
    BuildContext context,
    PlayerProvider player,
    Track track,
  ) {
    final settings = context.watch<SettingsProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.lyrics_rounded,
            color: _showLyricsInline
                ? Theme.of(context).colorScheme.primary
                : Colors.white54,
          ),
          tooltip: 'Lyrics',
          style: IconButton.styleFrom(
            backgroundColor: _showLyricsInline
                ? Theme.of(context).colorScheme.primary.withAlpha(30)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () =>
              setState(() => _showLyricsInline = !_showLyricsInline),
        ),
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: player.shuffleMode
                ? Theme.of(context).colorScheme.primary
                : Colors.white54,
          ),
          tooltip: 'Shuffle',
          style: IconButton.styleFrom(
            backgroundColor: player.shuffleMode
                ? Theme.of(context).colorScheme.primary.withAlpha(30)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          icon: Icon(
            Icons.compare_arrows_rounded,
            color: settings.crossfadeEnabled
                ? Colors.greenAccent
                : Colors.white54,
          ),
          tooltip: 'Crossfade (7s)',
          style: IconButton.styleFrom(
            backgroundColor: settings.crossfadeEnabled
                ? Colors.greenAccent.withAlpha(30)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final nextVal = !settings.crossfadeEnabled;
            settings.setCrossfadeEnabled(nextVal);
            player.setCrossfadeEnabled(nextVal);
          },
        ),
        IconButton(
          icon: Icon(
            Icons.bubble_chart_rounded,
            color: settings.autoDjMode != 'off'
                ? Colors.greenAccent
                : Colors.white54,
          ),
          tooltip: 'Auto DJ (${settings.autoDjMode})',
          style: IconButton.styleFrom(
            backgroundColor: settings.autoDjMode != 'off'
                ? Colors.greenAccent.withAlpha(30)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showAutoDjMenu(context, settings),
        ),
        IconButton(
          icon: Icon(
            _repeatIconData(player.repeatMode),
            color: player.repeatMode != repeat.PlaybackRepeatMode.none
                ? Theme.of(context).colorScheme.primary
                : Colors.white54,
          ),
          tooltip: 'Repeat',
          style: IconButton.styleFrom(
            backgroundColor: player.repeatMode != repeat.PlaybackRepeatMode.none
                ? Theme.of(context).colorScheme.primary.withAlpha(30)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: player.cycleRepeatMode,
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white54),
          tooltip: 'Queue',
          onPressed: () => _showQueueSheet(context),
        ),
      ],
    );
  }

  Widget _buildTrackQualityInfo(
    BuildContext context,
    PlayerProvider player,
    Track track,
    DownloadProvider downloadProvider,
  ) {
    final isDownloaded = downloadProvider.downloadedTrackIds.contains(track.id);
    final isAudio = _playbackMode == _PlaybackMode.audio;

    IconData icon;
    String infoText;
    Color iconColor;

    if (isDownloaded) {
      icon = Icons.offline_pin_rounded;
      infoText = 'OFFLINE • AAC • 256 KBPS • 44.1 KHZ';
      iconColor = const Color(0xFF81C784);
    } else if (!isAudio) {
      icon = Icons.hd_rounded;
      infoText = 'STREAMING • H.264 • 720P • 30 FPS';
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.wifi_rounded;
      iconColor = Colors.white70;
      switch (player.lastPlaybackQuality) {
        case AudioQuality.high:
          infoText = 'STREAMING • OPUS • 160 KBPS • 48.0 KHZ';
          iconColor = const Color(0xFFFFD54F);
          break;
        case AudioQuality.medium:
          infoText = 'STREAMING • AAC • 128 KBPS • 44.1 KHZ';
          break;
        case AudioQuality.low:
          infoText = 'STREAMING • AAC • 64 KBPS • 44.1 KHZ';
          break;
      }
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(16), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(
              infoText,
              style: TextStyle(
                color: Colors.white.withAlpha(160),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactQualityInfo(
    BuildContext context,
    PlayerProvider player,
    Track track,
    DownloadProvider downloadProvider,
  ) {
    final isDownloaded = downloadProvider.downloadedTrackIds.contains(track.id);
    final isAudio = _playbackMode == _PlaybackMode.audio;

    IconData icon;
    String infoText;
    Color iconColor;

    if (isDownloaded) {
      icon = Icons.offline_pin_rounded;
      infoText = 'OFFLINE • AAC • 256K';
      iconColor = const Color(0xFF81C784);
    } else if (!isAudio) {
      icon = Icons.hd_rounded;
      infoText = 'STREAMING • H.264 • 720P';
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.wifi_rounded;
      iconColor = Colors.white70;
      switch (player.lastPlaybackQuality) {
        case AudioQuality.high:
          infoText = 'STREAMING • OPUS • 160K';
          iconColor = const Color(0xFFFFD54F);
          break;
        case AudioQuality.medium:
          infoText = 'STREAMING • AAC • 128K';
          break;
        case AudioQuality.low:
          infoText = 'STREAMING • AAC • 64K';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(16), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 4),
          Text(
            infoText,
            style: TextStyle(
              color: Colors.white.withAlpha(140),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControlsBelowTitle(
    BuildContext context,
    PlayerProvider player,
    Track track,
    VideoPlayerController controller,
    bool compact,
  ) {
    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(height: compact ? 26 : 34),
        Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(formatDuration(position), style: _timeStyle),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress,
                  onChanged: (val) {
                    final target = Duration(
                      milliseconds: (duration.inMilliseconds * val).round(),
                    );
                    controller.seekTo(target);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                formatDuration(duration),
                textAlign: TextAlign.end,
                style: _timeStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 24 : 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ControlButton(
              icon: Icons.shuffle_rounded,
              active: player.shuffleMode,
              onPressed: player.toggleShuffle,
            ),
            _ControlButton(
              icon: Icons.fast_rewind_rounded,
              onPressed: player.previous,
            ),
            IconButton(
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 52,
                color: Colors.white,
              ),
              onPressed: () async {
                if (value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                setState(() {});
              },
            ),
            _ControlButton(
              icon: Icons.fast_forward_rounded,
              onPressed: player.currentIndex + 1 < player.queue.length
                  ? () => player.next()
                  : null,
            ),
            _ControlButton(
              icon: Icons.fullscreen_rounded,
              onPressed: () =>
                  _openFullscreenFromPlayerScreen(context, player, controller),
            ),
          ],
        ),
        SizedBox(height: compact ? 18 : 22),
      ],
    );
  }

  Future<void> _openFullscreenFromPlayerScreen(
    BuildContext context,
    PlayerProvider player,
    VideoPlayerController controller,
  ) async {
    if (!controller.value.isInitialized) return;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    final videoUrl = controller.dataSource;
    await controller.pause();

    if (!context.mounted) return;
    final track = player.currentTrack!;
    final newPosition = await Navigator.of(context).push<Duration>(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPlayer(
          track: track,
          videoUrl: videoUrl,
          initialPosition: position,
          wasPlaying: wasPlaying,
        ),
      ),
    );
    if (!context.mounted) return;
    if (newPosition != null) {
      await controller.seekTo(newPosition);
    }
    if (wasPlaying) {
      await controller.play();
    }
  }

  void _showMoreSheet(BuildContext context, PlayerProvider player) {
    final track = player.currentTrack;
    final downloadProvider = context.read<DownloadProvider>();
    final settings = context.read<SettingsProvider>();
    final isDownloaded =
        track != null && downloadProvider.downloadedTrackIds.contains(track.id);
    final isDownloading =
        track != null && downloadProvider.activeDownloads.containsKey(track.id);
    final items = [
      _MoreAction(
        icon: Icons.queue_music_rounded,
        title: 'Queue',
        subtitle: '${player.queue.length} tracks',
        onTap: () {
          Navigator.pop(context);
          _showQueueSheet(context);
        },
      ),
      if (track != null) ...[
        _MoreAction(
          icon: Icons.playlist_add_rounded,
          title: 'Save to playlist',
          subtitle: 'Add this track to a playlist',
          onTap: () {
            Navigator.pop(context);
            _showSaveSheet(context, player, track);
          },
        ),
        _MoreAction(
          icon: isDownloaded
              ? Icons.offline_pin_rounded
              : isDownloading
              ? Icons.downloading_rounded
              : Icons.download_rounded,
          title: isDownloaded
              ? 'Downloaded'
              : isDownloading
              ? 'Downloading'
              : 'Download',
          subtitle: isDownloaded
              ? 'Available offline'
              : isDownloading
              ? 'Already in progress'
              : 'Cache this track',
          onTap: isDownloaded || isDownloading
              ? null
              : () {
                  Navigator.pop(context);
                  downloadProvider.downloadTrack(
                    track,
                    player.currentPlaylistId ?? track.id,
                    quality: settings.audioQuality.name,
                  );
                },
        ),
      ],
      if (track?.artistId != null)
        _MoreAction(
          icon: Icons.person_outline_rounded,
          title: 'Go to artist',
          subtitle: track!.author ?? 'View artist page',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ArtistScreen(artistId: track.artistId!, name: track.author),
              ),
            );
          },
        ),
      if (track?.albumId != null)
        _MoreAction(
          icon: Icons.album_outlined,
          title: 'Go to album',
          subtitle: 'View album tracks',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumScreen(
                  albumId: track!.albumId!,
                  artist: track.author,
                  artistId: track.artistId,
                ),
              ),
            );
          },
        ),
      _MoreAction(
        icon: player.isSleepTimerActive
            ? Icons.timer_off_rounded
            : Icons.timer_rounded,
        title: player.isSleepTimerActive ? 'Cancel sleep timer' : 'Sleep timer',
        subtitle: player.isSleepTimerActive
            ? formatDuration(player.sleepTimerRemaining ?? Duration.zero)
            : 'Stop playback later',
        onTap: () {
          Navigator.pop(context);
          if (player.isSleepTimerActive) {
            player.cancelSleepTimer();
          } else {
            _showSleepTimerDialog(context, player);
          }
        },
      ),
      if (player.queue.isNotEmpty)
        _MoreAction(
          icon: Icons.clear_all_rounded,
          title: 'Clear queue',
          subtitle: 'Remove upcoming tracks',
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            _showClearQueueDialog(context, player);
          },
        ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withAlpha(14)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Now playing',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...items.map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: item.destructive
                                            ? Colors.redAccent.withAlpha(28)
                                            : Colors.white.withAlpha(12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: item.destructive
                                            ? Colors.redAccent
                                            : Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(item.subtitle),
                                    enabled: item.onTap != null,
                                    onTap: item.onTap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLyricsSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: MediaQuery.sizeOf(context).height * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(14)),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<LyricsResult?>(
                future: _lyricsService.getLyrics(track),
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                        child: Row(
                          children: [
                            const Icon(Icons.lyrics_rounded),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _LyricsSheetBody(
                          result: snapshot.data,
                          isLoading:
                              snapshot.connectionState ==
                              ConnectionState.waiting,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSaveSheet(
    BuildContext context,
    PlayerProvider player,
    Track track,
  ) {
    final playlistProvider = context.read<PlaylistProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withAlpha(14)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const _SaveActionIcon(
                          icon: Icons.music_note_rounded,
                        ),
                        title: const Text(
                          'Save current track',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Add it to your cached library'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await playlistProvider.saveSingleTrack(track);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${track.title}" saved')),
                          );
                        },
                      ),
                      if (player.queue.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const _SaveActionIcon(
                            icon: Icons.playlist_add_check_rounded,
                          ),
                          title: const Text(
                            'Create playlist from queue',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${player.queue.length} tracks, exportable',
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showCreatePlaylistDialog(context, player.queue);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, List<Track> tracks) {
    final controller = TextEditingController(text: 'Now Playing');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            prefixIcon: Icon(Icons.playlist_add_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = controller.text.trim().isEmpty
                  ? 'Now Playing'
                  : controller.text.trim();
              Navigator.pop(ctx);
              await context.read<PlaylistProvider>().savePlaylistFromTracks(
                title: title,
                tracks: tracks,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$title" saved to playlists')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showClearQueueDialog(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear queue?'),
        content: Text(
          '${player.queue.length} tracks in queue will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              player.clearQueue();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => const QueueSheet(),
    );
  }

  void _showSleepTimerDialog(BuildContext context, PlayerProvider player) {
    final options = [15, 30, 60];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sleep Timer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (player.isSleepTimerActive)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: const Text('Turn off timer'),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
            ...options.map(
              (minutes) => ListTile(
                leading: const Icon(Icons.timer),
                title: Text(
                  minutes >= 60
                      ? '${minutes ~/ 60}h ${minutes % 60}m'
                      : '${minutes}m',
                ),
                onTap: () {
                  player.startSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Custom...'),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomSleepTimer(context, player);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCustomSleepTimer(BuildContext context, PlayerProvider player) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom sleep timer'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                player.startSleepTimer(Duration(minutes: minutes));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  IconData _repeatIconData(repeat.PlaybackRepeatMode mode) {
    switch (mode) {
      case repeat.PlaybackRepeatMode.none:
      case repeat.PlaybackRepeatMode.all:
        return Icons.repeat_rounded;
      case repeat.PlaybackRepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }
}

class _PlayerErrorBanner extends StatelessWidget {
  final String message;

  const _PlayerErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact.isEmpty ? 'Playback failed' : compact,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackModeTabs extends StatelessWidget {
  final _PlaybackMode mode;
  final VoidCallback onAudioTap;
  final VoidCallback onVideoTap;

  const _PlaybackModeTabs({
    required this.mode,
    required this.onAudioTap,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(65),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
            icon: Icons.graphic_eq_rounded,
            tooltip: 'Audio',
            selected: mode == _PlaybackMode.audio,
            onTap: onAudioTap,
          ),
          const SizedBox(width: 3),
          _ModeTab(
            icon: Icons.smart_display_rounded,
            tooltip: 'Video',
            selected: mode == _PlaybackMode.video,
            onTap: onVideoTap,
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final Track track;
  final bool shouldPlay;
  final ValueChanged<VideoPlayerController?>? onControllerInitialized;

  const _InlineVideoPlayer({
    super.key,
    required this.track,
    this.shouldPlay = true,
    this.onControllerInitialized,
  });

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  Timer? _ticker;
  bool _isLoading = true;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.onControllerInitialized?.call(null);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    setState(() {
      _isLoading = true;
      _playerError = null;
    });

    try {
      final player = context.read<PlayerProvider>();
      final settings = context.read<SettingsProvider>();
      final startPosition = player.position;
      final videoUrl = await player.getVideoUrl(
        widget.track,
        quality: settings.audioQuality,
      );
      if (!mounted) return;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          'Referer': 'https://www.youtube.com/',
        },
      );
      _controller = controller;
      _initializeFuture = controller.initialize().then((_) async {
        await controller.seekTo(startPosition);
        if (widget.shouldPlay) {
          await controller.play();
        }
        if (!mounted) return;
        setState(() => _isLoading = false);
        widget.onControllerInitialized?.call(controller);

        // Ensure the audio player is paused when video starts playing!
        final playerProvider = context.read<PlayerProvider>();
        if (playerProvider.isPlaying) {
          await playerProvider.togglePlayPause();
        }
      });
      controller.addListener(_handleControllerTick);
      _ticker = Timer.periodic(const Duration(milliseconds: 450), (_) {
        if (mounted) setState(() {});
      });
      await _initializeFuture;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _playerError = e.toString();
      });
    }
  }

  void _handleControllerTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final error = controller.value.errorDescription;
    if (error != null && error != _playerError) {
      setState(() => _playerError = error);
    }

    // Check for video completion
    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero &&
        !controller.value.isPlaying &&
        _playerError == null) {
      controller.removeListener(_handleControllerTick);
      final playerProvider = context.read<PlayerProvider>();
      playerProvider.handleTrackCompletion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoSurface(controller: _controller),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final c = _controller;
                  if (c != null && c.value.isInitialized) {
                    if (c.value.isPlaying) {
                      c.pause();
                    } else {
                      c.play();
                    }
                  }
                },
              ),
              if (_isLoading && _playerError == null)
                _VideoLoadingOverlay(imageUrl: widget.track.thumbnailUrl),
              if (_playerError != null) _VideoError(message: _playerError),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final Track track;
  final String videoUrl;
  final Duration initialPosition;
  final bool wasPlaying;

  const _FullscreenVideoPlayer({
    required this.track,
    required this.videoUrl,
    required this.initialPosition,
    required this.wasPlaying,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;
  Timer? _ticker;
  bool _controlsVisible = true;
  bool _isLoading = true;
  String? _playerError;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://www.youtube.com/',
      },
    );
    _controller.addListener(_handleControllerTick);
    _initializeFuture = _controller
        .initialize()
        .then((_) async {
          await _controller.seekTo(widget.initialPosition);
          if (widget.wasPlaying) {
            await _controller.play();
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showControlsAndResetTimer();
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _playerError = e.toString();
          });
        });
    _ticker = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cancelHideTimer();
    _ticker?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _showControlsAndResetTimer() {
    _cancelHideTimer();
    if (mounted) {
      setState(() => _controlsVisible = true);
    }
    if (_controller.value.isInitialized && _controller.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _handleControllerTick() {
    final error = _controller.value.errorDescription;
    if (error != null && error != _playerError && mounted) {
      setState(() => _playerError = error);
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    _showControlsAndResetTimer();
  }

  void _close() {
    Navigator.pop(context, _controller.value.position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: _VideoSurface(controller: _controller)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_controlsVisible) {
                    setState(() => _controlsVisible = false);
                    _cancelHideTimer();
                  } else {
                    _showControlsAndResetTimer();
                  }
                },
              ),
              if (_isLoading && _playerError == null)
                _VideoLoadingOverlay(imageUrl: widget.track.thumbnailUrl),
              if (_playerError != null) _VideoError(message: _playerError),
              if (_playerError == null && !_isLoading)
                _CustomVideoControls(
                  controller: _controller,
                  visible: _controlsVisible,
                  compact: false,
                  onPlayPause: _togglePlayPause,
                  onFullscreen: _close,
                  onInteraction: _showControlsAndResetTimer,
                ),
              Positioned(
                top: 12,
                left: 12,
                child: SafeArea(
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: _close,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(150),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(42, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  final VideoPlayerController? controller;

  const _VideoSurface({required this.controller});

  @override
  Widget build(BuildContext context) {
    final videoController = controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return const SizedBox.expand();
    }
    return AspectRatio(
      aspectRatio: videoController.value.aspectRatio == 0
          ? 16 / 9
          : videoController.value.aspectRatio,
      child: VideoPlayer(videoController),
    );
  }
}

class _CustomVideoControls extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool visible;
  final bool compact;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;
  final VoidCallback? onInteraction;

  const _CustomVideoControls({
    required this.controller,
    required this.visible,
    required this.compact,
    required this.onPlayPause,
    required this.onFullscreen,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final videoController = controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final value = videoController.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(compact ? 80 : 120),
                Colors.transparent,
                Colors.black.withAlpha(compact ? 190 : 220),
              ],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: IconButton(
                  tooltip: value.isPlaying ? 'Pause' : 'Play',
                  onPressed: () {
                    onInteraction?.call();
                    onPlayPause();
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(235),
                    foregroundColor: Colors.black,
                    fixedSize: Size(compact ? 54 : 68, compact ? 54 : 68),
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: compact ? 30 : 40,
                  ),
                ),
              ),
              Positioned(
                top: compact ? 10 : 22,
                right: compact ? 10 : 22,
                child: IconButton(
                  tooltip: compact ? 'Fullscreen' : 'Exit fullscreen',
                  onPressed: () {
                    onInteraction?.call();
                    onFullscreen();
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(150),
                    foregroundColor: Colors.white,
                    fixedSize: Size(compact ? 38 : 44, compact ? 38 : 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    compact
                        ? Icons.fullscreen_rounded
                        : Icons.fullscreen_exit_rounded,
                    size: compact ? 22 : 26,
                  ),
                ),
              ),
              Positioned(
                left: compact ? 12 : 26,
                right: compact ? 12 : 26,
                bottom: compact ? 10 : 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: compact ? 3 : 4,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: compact ? 5 : 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (value) {
                          onInteraction?.call();
                          final target = Duration(
                            milliseconds: (duration.inMilliseconds * value)
                                .round(),
                          );
                          videoController.seekTo(target);
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          formatDuration(position),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatDuration(duration),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: compact ? 10 : 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoLoadingOverlay extends StatelessWidget {
  final String? imageUrl;

  const _VideoLoadingOverlay({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: imageUrl == null || imageUrl!.isEmpty
            ? null
            : DecorationImage(
                image: CachedNetworkImageProvider(imageUrl!),
                fit: BoxFit.cover,
                opacity: 0.32,
              ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Colors.black.withAlpha(135),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Loading YouTube player',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  final String? message;

  const _VideoError({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white54,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Video is unavailable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LyricsSheetBody extends StatelessWidget {
  final LyricsResult? result;
  final bool isLoading;

  const _LyricsSheetBody({required this.result, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final lyrics = result;
    if (lyrics == null || !lyrics.hasAnyLyrics) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No direct synced lyrics found for this track.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    if (!lyrics.hasSyncedLyrics) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SelectableText(
            lyrics.plainLyrics ?? '',
            style: const TextStyle(fontSize: 18, height: 1.55),
          ),
        ),
      );
    }

    return _SyncedLyricsList(lines: lyrics.syncedLines);
  }
}

class _SyncedLyricsList extends StatefulWidget {
  final List<LyricLine> lines;

  const _SyncedLyricsList({required this.lines});

  @override
  State<_SyncedLyricsList> createState() => _SyncedLyricsListState();
}

class _SyncedLyricsListState extends State<_SyncedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _lineKeys;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _SyncedLyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
      _lastActiveIndex = -1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final activeIndex = _activeLyricIndex(widget.lines, player.position);
        _scheduleAutoScroll(activeIndex);
        return ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 180, 24, 200),
              itemCount: widget.lines.length,
              itemBuilder: (context, index) {
                final line = widget.lines[index];
                final active = index == activeIndex;
                return GestureDetector(
                  key: _lineKeys[index],
                  onTap: () => player.seekTo(line.time),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white24,
                        fontSize: active ? 26 : 20,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        height: 1.35,
                        shadows: active
                            ? [
                                Shadow(
                                  color: Colors.white.withAlpha(90),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(line.text),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _scheduleAutoScroll(int activeIndex) {
    if (activeIndex == _lastActiveIndex ||
        activeIndex < 0 ||
        activeIndex >= _lineKeys.length) {
      return;
    }
    _lastActiveIndex = activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ensureActiveLineVisible(activeIndex)) return;
      if (!_scrollController.hasClients) return;
      final estimatedOffset = (activeIndex * 68.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController
          .animateTo(
            estimatedOffset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _ensureActiveLineVisible(activeIndex);
            });
          });
    });
  }

  bool _ensureActiveLineVisible(int activeIndex) {
    final context = _lineKeys[activeIndex].currentContext;
    if (context == null) return false;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.40,
    );
    return true;
  }

  int _activeLyricIndex(List<LyricLine> lines, Duration position) {
    final adjusted = position + const Duration(milliseconds: 150);
    var active = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= adjusted) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}

class _MoreAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  const _MoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });
}

class _SeekWaveform extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final String trackId;
  final bool showTimestamps;

  const _SeekWaveform({
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.isPlaying,
    required this.trackId,
    required this.onSeek,
    this.showTimestamps = true,
  });

  @override
  State<_SeekWaveform> createState() => _SeekWaveformState();
}

class _SeekWaveformState extends State<_SeekWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _bars;
  late double _rippleSpeed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _initTrackParams();
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _initTrackParams() {
    final seed = _getHash(widget.trackId);
    final random = _SeededRandom(seed);

    // Generate deterministic bar heights using a symmetric window envelope
    _bars = [];
    for (int i = 0; i < 45; i++) {
      final progress = i / 44.0;
      final window = math.sin(progress * math.pi);
      final randVal = 0.2 + 0.8 * random.nextDouble();
      _bars.add((randVal * window).clamp(0.08, 1.0));
    }

    // Generate deterministic animation settings
    final durationMs = 1600 + (random.nextDouble() * 1400).round();
    _controller.duration = Duration(milliseconds: durationMs);
    _rippleSpeed = 0.25 + 0.35 * random.nextDouble();
  }

  int _getHash(String str) {
    int hash = 0;
    for (var i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash;
  }

  @override
  void didUpdateWidget(covariant _SeekWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackId != oldWidget.trackId) {
      final wasPlaying = _controller.isAnimating;
      _controller.stop();
      _initTrackParams();
      if (widget.isPlaying || wasPlaying) {
        _controller.repeat();
      }
    } else if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inMilliseconds > 0
        ? widget.position.inMilliseconds / widget.duration.inMilliseconds
        : 0.0;
    final bufferProgress = widget.duration.inMilliseconds > 0
        ? widget.bufferedPosition.inMilliseconds /
              widget.duration.inMilliseconds
        : 0.0;

    void seekFromX(double x, double width) {
      if (widget.duration.inMilliseconds <= 0 || width <= 0) return;
      final value = (x / width).clamp(0.0, 1.0);
      widget.onSeek(
        Duration(
          milliseconds: (value * widget.duration.inMilliseconds).round(),
        ),
      );
    }

    final waveformWidget = LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              seekFromX(details.localPosition.dx, constraints.maxWidth),
          onHorizontalDragUpdate: (details) =>
              seekFromX(details.localPosition.dx, constraints.maxWidth),
          child: SizedBox(
            height: 58,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, 58),
                  painter: _WaveformPainter(
                    progress: progress.clamp(0.0, 1.0),
                    bufferProgress: bufferProgress.clamp(0.0, 1.0),
                    animationValue: _controller.value,
                    isPlaying: widget.isPlaying,
                    activeColor: Theme.of(context).colorScheme.primary,
                    bars: _bars,
                    rippleSpeed: _rippleSpeed,
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (!widget.showTimestamps) {
      return waveformWidget;
    }

    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(formatDuration(widget.position), style: _timeStyle),
        ),
        Expanded(child: waveformWidget),
        SizedBox(
          width: 42,
          child: Text(
            formatDuration(widget.duration),
            textAlign: TextAlign.end,
            style: _timeStyle,
          ),
        ),
      ],
    );
  }
}

class _BlurredArtworkBackground extends StatelessWidget {
  final String? imageUrl;

  const _BlurredArtworkBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final original = imageUrl ?? '';
    final fallback = _hiFiArtworkUrl(imageUrl);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (original.isNotEmpty)
          CachedNetworkImage(
            imageUrl: original,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, error) =>
                fallback.isNotEmpty && fallback != original
                ? CachedNetworkImage(
                    imageUrl: fallback,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(color: Colors.black.withAlpha(120)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66303030), Color(0xEE151515), Color(0xFF101010)],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  final String? imageUrl;

  const _Artwork({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width.clamp(240.0, 330.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: _ArtworkImage(imageUrl: imageUrl),
      ),
    );
  }
}

class _ArtworkLyricsStage extends StatelessWidget {
  final String? imageUrl;
  final bool showLyrics;
  final Future<LyricsResult?>? lyricsFuture;

  const _ArtworkLyricsStage({
    required this.imageUrl,
    required this.showLyrics,
    required this.lyricsFuture,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width.clamp(240.0, 330.0);
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: showLyrics
            ? FutureBuilder<LyricsResult?>(
                key: const ValueKey('lyrics-view'),
                future: lyricsFuture,
                builder: (context, snapshot) {
                  return _LyricsSheetBody(
                    result: snapshot.data,
                    isLoading:
                        snapshot.connectionState == ConnectionState.waiting,
                  );
                },
              )
            : _Artwork(key: const ValueKey('artwork-view'), imageUrl: imageUrl),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  final String? imageUrl;

  const _ArtworkImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final original = imageUrl ?? '';
    final fallback = _hiFiArtworkUrl(imageUrl);
    return CachedNetworkImage(
      imageUrl: original,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: const Color(0xFF282828)),
      errorWidget: (context, url, error) =>
          fallback.isNotEmpty && fallback != original
          ? CachedNetworkImage(
              imageUrl: fallback,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: const Color(0xFF282828)),
              errorWidget: (context, url, error) => _ArtworkFallback(),
            )
          : _ArtworkFallback(),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF282828),
      child: const Icon(
        Icons.music_video_rounded,
        size: 68,
        color: Colors.white38,
      ),
    );
  }
}

String _hiFiArtworkUrl(String? url) {
  final value = url ?? '';
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.pathSegments.isEmpty) return value;
  final last = uri.pathSegments.last;
  const replaceable = {
    'default.jpg',
    'mqdefault.jpg',
    'hqdefault.jpg',
    'sddefault.jpg',
  };
  if (!replaceable.contains(last)) return value;
  final segments = [...uri.pathSegments];
  segments[segments.length - 1] = 'hqdefault.jpg';
  return uri.replace(pathSegments: segments).toString();
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withAlpha(55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    this.active = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 28),
      color: active ? Theme.of(context).colorScheme.primary : Colors.white,
      disabledColor: Colors.white24,
      onPressed: onPressed,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double bufferProgress;
  final double animationValue;
  final bool isPlaying;
  final Color activeColor;
  final List<double> bars;
  final double rippleSpeed;

  const _WaveformPainter({
    required this.progress,
    required this.bufferProgress,
    required this.animationValue,
    required this.isPlaying,
    required this.activeColor,
    required this.bars,
    required this.rippleSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = Colors.white.withAlpha(36)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final bufferedPaint = Paint()
      ..color = Colors.white.withAlpha(92)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final step = size.width / bars.length;
    final activeWidth = size.width * progress;
    final bufferWidth = size.width * bufferProgress;
    for (var i = 0; i < bars.length; i++) {
      final x = step * i + step / 2;

      // Calculate dynamic scale factor based on play state and animation
      final phase = animationValue * 2 * math.pi;
      final scaleFactor = isPlaying
          ? 0.7 + 0.3 * math.sin(phase - i * rippleSpeed)
          : 1.0;

      final barHeight = size.height * bars[i] * scaleFactor;

      final paint = x <= activeWidth
          ? activePaint
          : x <= bufferWidth
          ? bufferedPaint
          : inactivePaint;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferProgress != bufferProgress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.bars != bars ||
        oldDelegate.rippleSpeed != rippleSpeed;
  }
}

class _SeededRandom {
  int seed;
  _SeededRandom(this.seed);

  double nextDouble() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }
}

const _timeStyle = TextStyle(
  color: Colors.white70,
  fontSize: 11,
  fontWeight: FontWeight.w600,
);

class _SaveActionIcon extends StatelessWidget {
  final IconData icon;

  const _SaveActionIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: active ? Colors.black : Colors.white,
          backgroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withAlpha(24),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
