import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/video.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/album_screen.dart';
import '../screens/artist_screen.dart';
import '../screens/player_screen.dart';

Future<void> showTrackActionSheet(
  BuildContext context, {
  required Track track,
  List<Track>? queue,
  int? index,
  String? playlistId,
  VoidCallback? onRemove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _TrackActionSheet(
      track: track,
      queue: queue,
      index: index,
      playlistId: playlistId,
      onRemove: onRemove,
    ),
  );
}

class _TrackActionSheet extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final int? index;
  final String? playlistId;
  final VoidCallback? onRemove;

  const _TrackActionSheet({
    required this.track,
    this.queue,
    this.index,
    this.playlistId,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlaylistProvider, DownloadProvider>(
      builder: (context, playlistProvider, downloadProvider, _) {
        final isFavorite = playlistProvider.isFavorite(track.id);
        final isDownloaded = downloadProvider.downloadedTrackIds.contains(
          track.id,
        );
        final isDownloading = downloadProvider.activeDownloads.containsKey(
          track.id,
        );
        final actions = [
          _TrackAction(
            icon: Icons.play_arrow_rounded,
            title: 'Play now',
            subtitle: 'Start this track',
            onTap: () => _playNow(context),
          ),
          _TrackAction(
            icon: Icons.queue_music_rounded,
            title: 'Play next',
            subtitle: 'Add after the current track',
            onTap: () => _playNext(context),
          ),
          _TrackAction(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            title: isFavorite ? 'Remove favourite' : 'Add favourite',
            subtitle: isFavorite ? 'Take it out of favourites' : 'Save it',
            color: isFavorite ? const Color(0xFFFF7FA4) : null,
            onTap: () {
              playlistProvider.toggleFavorite(track);
              Navigator.pop(context);
            },
          ),
          if (track.artistId != null)
            _TrackAction(
              icon: Icons.person_outline_rounded,
              title: 'Go to artist',
              subtitle: track.author ?? 'View artist page',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistScreen(
                      artistId: track.artistId!,
                      name: track.author,
                    ),
                  ),
                );
              },
            ),
          if (track.albumId != null)
            _TrackAction(
              icon: Icons.album_outlined,
              title: 'Go to album',
              subtitle: 'View album tracks',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumScreen(
                      albumId: track.albumId!,
                      artist: track.author,
                      artistId: track.artistId,
                    ),
                  ),
                );
              },
            ),
          if (!isDownloaded && !isDownloading)
            _TrackAction(
              icon: Icons.download_rounded,
              title: 'Download',
              subtitle: 'Cache for offline playback',
              onTap: () => _download(context),
            ),
          if (isDownloaded)
            const _TrackAction(
              icon: Icons.offline_pin_rounded,
              title: 'Downloaded',
              subtitle: 'Available offline',
            ),
          if (isDownloading)
            const _TrackAction(
              icon: Icons.downloading_rounded,
              title: 'Downloading',
              subtitle: 'Already in progress',
            ),
          if (onRemove != null)
            _TrackAction(
              icon: Icons.delete_outline_rounded,
              title: 'Remove from list',
              subtitle: 'Delete from this playlist',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                onRemove?.call();
              },
            ),
        ];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: GestureDetector(
              onTap: () {},
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
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.author ?? 'Unknown artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...actions.map((action) => _ActionTile(action: action)),
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
        );
      },
    );
  }

  Future<void> _playNow(BuildContext context) async {
    final navigator = Navigator.of(context);
    final player = context.read<PlayerProvider>();
    final settings = context.read<SettingsProvider>();
    final tracks = queue ?? [track];
    final startIndex =
        index ?? tracks.indexWhere((item) => item.id == track.id);
    player.setQueue(
      tracks,
      startIndex: startIndex < 0 ? 0 : startIndex,
      playlistId: playlistId,
    );
    player.playTrack(track, quality: settings.audioQuality);
    await context.read<PlaylistProvider>().saveSingleTrack(track);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  void _playNext(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final player = context.read<PlayerProvider>();
    final currentQueue = List<Track>.from(player.queue);
    if (currentQueue.isEmpty) {
      player.setQueue([track], startIndex: 0, playlistId: playlistId);
    } else {
      final insertAt = (player.currentIndex + 1).clamp(0, currentQueue.length);
      currentQueue.insert(insertAt, track);
      player.setQueue(
        currentQueue,
        startIndex: player.currentIndex,
        playlistId: player.currentPlaylistId,
      );
    }
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${track.title}" added to queue'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _download(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    context.read<DownloadProvider>().downloadTrack(
      track,
      playlistId ?? track.id,
      quality: settings.audioQuality.name,
    );
    Navigator.pop(context);
  }
}

class _ActionTile extends StatelessWidget {
  final _TrackAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (action.color ?? Colors.white).withAlpha(18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(action.icon, color: action.color ?? Colors.white),
      ),
      title: Text(
        action.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(action.subtitle),
      enabled: action.onTap != null,
      onTap: action.onTap,
    );
  }
}

class _TrackAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _TrackAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.onTap,
  });
}
