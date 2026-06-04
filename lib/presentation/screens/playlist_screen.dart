import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/video.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/track_action_sheet.dart';
import '../widgets/video_tile.dart';
import '../widgets/now_playing_fab.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  final bool autoDownload;

  const PlaylistScreen({
    super.key,
    required this.playlist,
    this.autoDownload = false,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  bool _autoDownloadStarted = false;
  VoidCallback? _trackChangedHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      _trackChangedHandler = () {
        if (!mounted) return;
        if (player.currentPlaylistId != widget.playlist.id) return;
        final dl = context.read<DownloadProvider>();
        final settings = context.read<SettingsProvider>();
        dl.preDownloadUpcoming(
          player.queue,
          player.currentIndex,
          widget.playlist.id,
          prebufferCount: settings.prebufferCount,
          quality: settings.audioQuality.name,
        );
      };
      player.addTrackChangedListener(_trackChangedHandler!);
      
      final provider = context.read<PlaylistProvider>();
      provider.loadCachedPlaylist(widget.playlist.id).then((_) {
        if (!mounted) return;
        final current = provider.currentPlaylist;
        if ((current == null || current.tracks.isEmpty) && !provider.isLoading) {
          provider.fetchPlaylist(widget.playlist.id);
        }
      });
    });
  }

  @override
  void dispose() {
    if (_trackChangedHandler != null) {
      try {
        context.read<PlayerProvider>().removeTrackChangedListener(
          _trackChangedHandler!,
        );
      } catch (_) {}
      _trackChangedHandler = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isNowPlaying = player.currentTrack != null;

    return Scaffold(
      floatingActionButton: isNowPlaying
          ? NowPlayingFab(
              track: player.currentTrack!,
              isPlaying: player.isPlaying,
            )
          : null,
      body: SafeArea(
        child: Consumer3<PlaylistProvider, PlayerProvider, DownloadProvider>(
          builder:
              (context, playlistProvider, playerProvider, downloadProvider, _) {
                final playlist =
                    playlistProvider.currentPlaylist?.id == widget.playlist.id
                    ? playlistProvider.currentPlaylist!
                    : widget.playlist;
                final tracks = playlist.tracks;
                final currentTrackId = playerProvider.currentTrack?.id;
                final isDownloading = downloadProvider.isDownloadingPlaylist(
                  widget.playlist.id,
                );
                final favoriteIds = playlistProvider.favoriteIds;

                if (widget.autoDownload &&
                    !_autoDownloadStarted &&
                    tracks.isNotEmpty &&
                    !isDownloading) {
                  _autoDownloadStarted = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      final quality = context
                          .read<SettingsProvider>()
                          .audioQuality;
                      context.read<DownloadProvider>().downloadPlaylist(
                        playlist,
                        quality: quality.name,
                      );
                    }
                  });
                }

                return Column(
                  children: [
                    _buildHeader(
                      context,
                      playlist,
                      tracks,
                      playerProvider,
                      downloadProvider,
                      isDownloading,
                      playlistProvider,
                    ),
                    if (isDownloading)
                      _buildDownloadProgress(downloadProvider, tracks),
                    Expanded(
                      child: playlistProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : tracks.isEmpty
                              ? const Center(child: Text('No tracks found'))
                              : RefreshIndicator(
                              onRefresh: () async {
                                final provider = context
                                    .read<PlaylistProvider>();
                                await provider.fetchPlaylist(
                                  widget.playlist.id,
                                );
                              },
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  12,
                                ),
                                onReorderItem: (oldIndex, newIndex) {
                                  final updatedTracks = List<Track>.from(
                                    tracks,
                                  );
                                  final item = updatedTracks.removeAt(oldIndex);
                                  updatedTracks.insert(newIndex, item);
                                  playerProvider.setQueue(
                                    updatedTracks,
                                    startIndex: playerProvider.currentIndex,
                                    playlistId: widget.playlist.id,
                                  );
                                  final trackIds = updatedTracks
                                      .map((t) => t.id)
                                      .toList();
                                  playlistProvider.reorderTracks(
                                    widget.playlist.id,
                                    trackIds,
                                  );
                                },
                                itemCount: tracks.length,
                                itemBuilder: (context, index) {
                                  final track = tracks[index];
                                  return Dismissible(
                                    key: ValueKey(
                                      '${track.id}-${widget.playlist.id}',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Remove track'),
                                          content: Text(
                                            'Remove "${track.title}" from this playlist?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        playlistProvider
                                            .removeTrackFromPlaylist(
                                              widget.playlist.id,
                                              track.id,
                                            );
                                      }
                                      return false;
                                    },
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 24),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: TrackTile(
                                      track: track,
                                      isCurrent: currentTrackId == track.id,
                                      isDownloaded: downloadProvider
                                          .downloadedTrackIds
                                          .contains(track.id),
                                      isDownloading: downloadProvider
                                          .activeDownloads
                                          .containsKey(track.id),
                                      isFavorite: favoriteIds.contains(
                                        track.id,
                                      ),
                                      onDownload:
                                          downloadProvider.downloadedTrackIds
                                              .contains(track.id)
                                          ? null
                                          : () {
                                              final quality = context
                                                  .read<SettingsProvider>()
                                                  .audioQuality;
                                              downloadProvider.downloadTrack(
                                                track,
                                                widget.playlist.id,
                                                quality: quality.name,
                                              );
                                            },
                                      onToggleFavorite: () => playlistProvider
                                          .toggleFavorite(track),
                                      onMore: () => showTrackActionSheet(
                                        context,
                                        track: track,
                                        queue: tracks,
                                        index: index,
                                        playlistId: widget.playlist.id,
                                        onRemove: () => playlistProvider
                                            .removeTrackFromPlaylist(
                                              widget.playlist.id,
                                              track.id,
                                            ),
                                      ),
                                      onTap: () {
                                        final quality = context
                                            .read<SettingsProvider>()
                                            .audioQuality;
                                        playerProvider.setQueue(
                                          tracks,
                                          startIndex: index,
                                          playlistId: widget.playlist.id,
                                        );
                                        playerProvider.playTrack(
                                          track,
                                          quality: quality,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),

                  ],
                );
              },
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(
    DownloadProvider downloadProvider,
    List<Track> tracks,
  ) {
    final completed = tracks
        .where((t) => downloadProvider.downloadedTrackIds.contains(t.id))
        .length;
    final activeProgress = downloadProvider.activeDownloads.values.isNotEmpty
        ? downloadProvider.activeDownloads.values.last
        : null;
    return Column(
      children: [
        if (activeProgress != null && activeProgress.totalBytes > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Downloading: ${activeProgress.trackTitle}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(activeProgress.fraction * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: LinearProgressIndicator(
            value: tracks.isEmpty ? 0 : completed / tracks.length,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Playlist playlist,
    List<Track> tracks,
    PlayerProvider playerProvider,
    DownloadProvider downloadProvider,
    bool isDownloading,
    PlaylistProvider playlistProvider,
  ) {
    final isFullyDownloaded =
        tracks.isNotEmpty &&
        tracks.every((t) => downloadProvider.downloadedTrackIds.contains(t.id));
    final anyDownloaded = tracks.any(
      (t) => downloadProvider.downloadedTrackIds.contains(t.id),
    );
    final isFav = playlistProvider.isCollectionFavorite(playlist.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : Colors.white,
                  size: 20,
                ),
                tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => playlistProvider.toggleFavoriteCollection(
                  playlist,
                  'playlist',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                tooltip: 'Rename',
                onPressed: () => _showRenameDialog(
                  context,
                  playlist.id,
                  playlist.title,
                  playlistProvider,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  widget.playlist.thumbnailUrl ?? '',
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Container(
                    width: 112,
                    height: 112,
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.music_note_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tracks.length} tracks${playlist.author != null ? ' · ${playlist.author}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _PlayPauseButton(
                tracks: tracks,
                playerProvider: playerProvider,
                playlistId: widget.playlist.id,
              ),
              const SizedBox(width: 8),
              if (tracks.isNotEmpty)
                _HeaderActionButton(
                  icon: Icons.shuffle_rounded,
                  onPressed: () {
                    final quality = context
                        .read<SettingsProvider>()
                        .audioQuality;
                    playerProvider.setQueue(
                      tracks,
                      startIndex: 0,
                      playlistId: widget.playlist.id,
                    );
                    playerProvider.toggleShuffle();
                    playerProvider.playTrack(tracks.first, quality: quality);
                  },
                ),
              const Spacer(),
              if (anyDownloaded)
                _HeaderActionButton(
                  icon: Icons.delete_sweep_rounded,
                  tooltip: 'Clear downloads',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear downloaded tracks?'),
                        content: const Text(
                          'Remove all downloaded files for this playlist?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await downloadProvider.deleteDownloadedPlaylist(
                        widget.playlist.id,
                      );
                    }
                  },
                ),
              if (isDownloading)
                _HeaderActionButton(
                  icon: Icons.cancel_rounded,
                  color: Colors.redAccent,
                  onPressed: () => downloadProvider.cancelDownload(),
                )
              else
                _HeaderActionButton(
                  icon: isFullyDownloaded
                      ? Icons.offline_pin_rounded
                      : Icons.download_rounded,
                  color: isFullyDownloaded ? Colors.greenAccent : null,
                  onPressed: tracks.isEmpty || isFullyDownloaded
                      ? null
                      : () {
                          final quality = context
                              .read<SettingsProvider>()
                              .audioQuality;
                          downloadProvider.downloadPlaylist(
                            playlist,
                            quality: quality.name,
                          );
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    String playlistId,
    String currentTitle,
    PlaylistProvider provider,
  ) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            prefixIcon: Icon(Icons.edit),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty && trimmed != currentTitle) {
              provider.renamePlaylist(playlistId, trimmed);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty && trimmed != currentTitle) {
                provider.renamePlaylist(playlistId, trimmed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final List<Track> tracks;
  final PlayerProvider playerProvider;
  final String playlistId;

  const _PlayPauseButton({
    required this.tracks,
    required this.playerProvider,
    required this.playlistId,
  });

  bool get _isPlayingFromThisPlaylist {
    return playerProvider.currentPlaylistId == playlistId;
  }

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    if (!_isPlayingFromThisPlaylist) {
      return SizedBox(
        width: 54,
        height: 54,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 30),
          onPressed: () {
            final quality = context.read<SettingsProvider>().audioQuality;
            playerProvider.setQueue(
              tracks,
              startIndex: 0,
              playlistId: playlistId,
            );
            playerProvider.playTrack(tracks.first, quality: quality);
          },
        ),
      );
    }

    return SizedBox(
      width: 54,
      height: 54,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
        ),
        icon: Icon(
          playerProvider.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 30,
        ),
        onPressed: () => playerProvider.togglePlayPause(),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  const _HeaderActionButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withAlpha(10),
          foregroundColor: color ?? Colors.white,
          disabledForegroundColor: Colors.white24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
