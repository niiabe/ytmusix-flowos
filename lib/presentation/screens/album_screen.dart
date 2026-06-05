import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format_duration.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/search_result_models.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/track_action_sheet.dart';
import '../widgets/now_playing_fab.dart';
import 'artist_screen.dart';

class AlbumScreen extends StatefulWidget {
  final String albumId;
  final String? title;
  final String? artist;
  final String? artistId;
  final String? thumbnailUrl;

  const AlbumScreen({
    super.key,
    required this.albumId,
    this.title,
    this.artist,
    this.artistId,
    this.thumbnailUrl,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  AlbumDetailResult? _album;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await context.read<PlaylistProvider>().getAlbum(
        widget.albumId,
      );
      if (mounted) {
        setState(() {
          _album = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final playerWatcher = context.watch<PlayerProvider>();
    final isNowPlaying = playerWatcher.currentTrack != null;
    return Scaffold(
      floatingActionButton: isNowPlaying
          ? NowPlayingFab(
              track: playerWatcher.currentTrack!,
              isPlaying: playerWatcher.isPlaying,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          onPressed: _loadAlbum,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final album = _album!;
    final player = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final isFav = playlistProvider.isCollectionFavorite(album.id);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Container(
                height: 380,
                width: double.infinity,
                foregroundDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                    ],
                  ),
                ),
                child: Image.network(
                  album.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Container(
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.album_rounded, size: 64, color: Colors.white24),
                  ),
                ),
              ),
              Positioned(
                top: statusBarHeight + 12,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white,
                          size: 20,
                        ),
                        tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                        onPressed: () {
                          final playlist = Playlist(
                            id: album.id,
                            title: album.title,
                            author: album.artist,
                            thumbnailUrl: album.thumbnailUrl,
                            videoCount: album.tracks.length,
                            tracks: album.tracks,
                            type: 'album',
                          );
                          playlistProvider.toggleFavoriteCollection(playlist, 'album');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Album',
                        style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: album.artistId != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistScreen(
                                    artistId: album.artistId!,
                                    name: album.artist,
                                  ),
                                ),
                              )
                          : null,
                      child: Text(
                        '${album.artist}${album.year != null ? ' · ${album.year}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: album.artistId != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: album.tracks.isEmpty
                                ? null
                                : () {
                                    final quality = context.read<SettingsProvider>().audioQuality;
                                    player.setQueue(
                                      album.tracks,
                                      startIndex: 0,
                                      playlistId: 'album_${album.id}',
                                    );
                                    player.playTrack(album.tracks.first, quality: quality);
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              backgroundColor: Colors.white.withAlpha(20),
                            ),
                            icon: const Icon(Icons.shuffle_rounded, size: 18),
                            label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: album.tracks.isEmpty
                                ? null
                                : () {
                                    final quality = context.read<SettingsProvider>().audioQuality;
                                    player.setQueue(
                                      album.tracks,
                                      startIndex: 0,
                                      playlistId: 'album_${album.id}',
                                    );
                                    player.toggleShuffle();
                                    player.playTrack(album.tracks.first, quality: quality);
                                  },
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
        if (album.tracks.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No tracks found')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = album.tracks[index];
                  final currentTrackId = player.currentTrack?.id;
                  final isCurrent = currentTrackId == track.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary.withAlpha(28)
                          : const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary.withAlpha(80)
                            : Colors.white.withAlpha(12),
                      ),
                    ),
                    child: ListTile(
                      tileColor: isCurrent
                          ? Theme.of(context).colorScheme.primary.withAlpha(28)
                          : const Color(0xFF171717),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          track.thumbnailUrl ?? '',
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 46,
                            height: 46,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, size: 20),
                          ),
                        ),
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        formatDuration(track.duration),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onPressed: () => showTrackActionSheet(
                          context,
                          track: track,
                          queue: album.tracks,
                          index: index,
                          playlistId: 'album_${album.id}',
                        ),
                      ),
                      onTap: () {
                        final quality = context.read<SettingsProvider>().audioQuality;
                        player.setQueue(
                          album.tracks,
                          startIndex: index,
                          playlistId: 'album_${album.id}',
                        );
                        player.playTrack(track, quality: quality);
                      },
                    ),
                  );
                },
                childCount: album.tracks.length,
              ),
            ),
          ),
      ],
    );
  }
}
