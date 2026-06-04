import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/video.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/now_playing_fab.dart';
import '../widgets/track_action_sheet.dart';
import '../widgets/video_tile.dart';

class DownloadedScreen extends StatefulWidget {
  const DownloadedScreen({super.key});

  @override
  State<DownloadedScreen> createState() => _DownloadedScreenState();
}

class _DownloadedScreenState extends State<DownloadedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().loadDownloadedTracks();
    });
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
        child: Consumer3<DownloadProvider, PlaylistProvider, PlayerProvider>(
          builder: (context, downloadProvider, playlistProvider, playerProvider, _) {
            final tracks = downloadProvider.downloadedTracks;
            final favoriteIds = playlistProvider.favoriteIds;
            final currentTrackId = playerProvider.currentTrack?.id;

            return Column(
              children: [
                _buildHeader(context, tracks, playerProvider),
                Expanded(
                  child: tracks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF171717),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white.withAlpha(14)),
                                ),
                                child: const Icon(
                                  Icons.download_done_rounded,
                                  size: 34,
                                  color: Colors.white38,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'No downloaded songs',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Songs you download will appear here',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: tracks.length,
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return TrackTile(
                              track: track,
                              isCurrent: currentTrackId == track.id,
                              isDownloaded: true,
                              isFavorite: favoriteIds.contains(track.id),
                              onToggleFavorite: () => playlistProvider.toggleFavorite(track),
                              onMore: () => showTrackActionSheet(
                                context,
                                track: track,
                                queue: tracks,
                                index: index,
                                playlistId: '__downloads__',
                              ),
                              onTap: () {
                                if (currentTrackId == track.id) {
                                  playerProvider.togglePlayPause();
                                } else {
                                  final quality = context.read<SettingsProvider>().audioQuality;
                                  playerProvider.setQueue(
                                    tracks,
                                    startIndex: index,
                                    playlistId: '__downloads__',
                                  );
                                  playerProvider.playTrack(track, quality: quality);
                                }
                              },
                            );
                          },
                        ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<Track> tracks,
    PlayerProvider playerProvider,
  ) {
    final hasTracks = tracks.isNotEmpty;
    final isPlayingFromDownloads = playerProvider.currentPlaylistId == '__downloads__';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Downloaded Songs',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tracks.length} tracks available offline',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (hasTracks) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                    ),
                    icon: Icon(
                      isPlayingFromDownloads && playerProvider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 30,
                    ),
                    onPressed: () {
                      if (isPlayingFromDownloads) {
                        playerProvider.togglePlayPause();
                      } else {
                        final quality = context.read<SettingsProvider>().audioQuality;
                        playerProvider.setQueue(
                          tracks,
                          startIndex: 0,
                          playlistId: '__downloads__',
                        );
                        playerProvider.playTrack(tracks.first, quality: quality);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    onPressed: () {
                      final quality = context.read<SettingsProvider>().audioQuality;
                      playerProvider.setQueue(
                        tracks,
                        startIndex: 0,
                        playlistId: '__downloads__',
                      );
                      playerProvider.toggleShuffle();
                      playerProvider.playTrack(playerProvider.queue.first, quality: quality);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
