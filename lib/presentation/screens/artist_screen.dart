import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format_duration.dart';
import '../../domain/entities/search_result_models.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/track_action_sheet.dart';
import '../widgets/now_playing_fab.dart';
import 'album_screen.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;
  final String? name;

  const ArtistScreen({
    super.key,
    required this.artistId,
    this.name,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  ArtistDetailResult? _artist;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  Future<void> _loadArtist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await context.read<PlaylistProvider>().getArtist(
        widget.artistId,
      );
      if (mounted) {
        setState(() {
          _artist = result;
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
                          onPressed: _loadArtist,
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
    final artist = _artist!;
    final player = context.watch<PlayerProvider>();
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
                  artist.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => Container(
                    color: const Color(0xFF282828),
                    child: const Icon(Icons.person, size: 64, color: Colors.white24),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Artist',
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
                      artist.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (artist.topSongs.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              final quality = context.read<SettingsProvider>().audioQuality;
                              player.setQueue(
                                artist.topSongs,
                                startIndex: 0,
                                playlistId: 'artist_${artist.id}',
                              );
                              player.playTrack(artist.topSongs.first, quality: quality);
                            },
                          ),
                        if (artist.topSongs.length > 1) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              backgroundColor: Colors.white.withAlpha(20),
                            ),
                            icon: const Icon(Icons.shuffle_rounded, size: 18),
                            label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              final quality = context.read<SettingsProvider>().audioQuality;
                              player.setQueue(
                                artist.topSongs,
                                startIndex: 0,
                                playlistId: 'artist_${artist.id}',
                              );
                              player.toggleShuffle();
                              player.playTrack(artist.topSongs.first, quality: quality);
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (artist.topSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Text(
                    'Popular Songs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (artist.topSongs.length > 1)
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
                          player.setQueue(
                            artist.topSongs,
                            startIndex: 0,
                            playlistId: 'artist_${artist.id}',
                          );
                          player.toggleShuffle();
                          player.playTrack(artist.topSongs.first, quality: quality);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = artist.topSongs[index];
                final isCurrent = player.currentTrack?.id == track.id;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                        queue: artist.topSongs,
                        index: index,
                        playlistId: 'artist_${artist.id}',
                      ),
                    ),
                    onTap: () {
                      final quality = context.read<SettingsProvider>().audioQuality;
                      player.setQueue(
                        artist.topSongs,
                        startIndex: index,
                        playlistId: 'artist_${artist.id}',
                      );
                      player.playTrack(track, quality: quality);
                    },
                  ),
                );
              },
              childCount: artist.topSongs.length,
            ),
          ),
        ],
        if (artist.albums.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: const Text(
                'Albums',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: artist.albums.length,
                itemBuilder: (context, index) {
                  final album = artist.albums[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumScreen(
                          albumId: album.id,
                          title: album.title,
                          artist: album.artist,
                          artistId: album.artistId,
                          thumbnailUrl: album.thumbnailUrl,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              album.thumbnailUrl ?? '',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 140,
                                height: 140,
                                color: const Color(0xFF282828),
                                child: const Icon(Icons.album_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            album.year?.toString() ?? 'Album',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (artist.singles.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: const Text(
                'Singles & EPs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: artist.singles.length,
                itemBuilder: (context, index) {
                  final single = artist.singles[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumScreen(
                          albumId: single.id,
                          title: single.title,
                          artist: single.artist,
                          artistId: single.artistId,
                          thumbnailUrl: single.thumbnailUrl,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              single.thumbnailUrl ?? '',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 140,
                                height: 140,
                                color: const Color(0xFF282828),
                                child: const Icon(Icons.album_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            single.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            single.year?.toString() ?? 'Single',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
