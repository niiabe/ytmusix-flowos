import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/search_result_models.dart';
import '../../domain/entities/video.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/track_action_sheet.dart';
import '../widgets/now_playing_fab.dart';
import '../widgets/video_tile.dart';
import 'album_screen.dart';
import 'artist_screen.dart';
import 'player_screen.dart';
import 'playlist_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabController;
  bool _hasSearched = false;
  Timer? _debounce;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().loadSearchHistory();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _hasSearched = true;
      _suggestions = [];
    });
    final provider = context.read<PlaylistProvider>();
    await provider.addSearchHistory(query);
    await provider.searchAll(query);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _suggestions = [];
          });
        }
        return;
      }
      final suggestions = await context.read<PlaylistProvider>().getSearchSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    });
  }

  void _searchFromHistory(String query) {
    _controller.text = query;
    _search();
  }

  Future<void> _playTrack(Track track, List<Track> queue, int index) async {
    final player = context.read<PlayerProvider>();
    final quality = context.read<SettingsProvider>().audioQuality;
    player.setQueue(queue, startIndex: index);
    player.playTrack(track, quality: quality);
    await context.read<PlaylistProvider>().saveSingleTrack(track);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaylistProvider>();
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF191919),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Search',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withAlpha(14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.white54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search for music...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _search(),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          setState(() {
                            _suggestions = [];
                          });
                        },
                      ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: provider.isCategorizedSearching
                            ? null
                            : _search,
                        icon: provider.isCategorizedSearching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_hasSearched && !provider.isCategorizedSearching)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  indicator: const BoxDecoration(),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabs: [
                    _buildTabChip('Songs', 0),
                    _buildTabChip('Videos', 1),
                    _buildTabChip('Albums', 2),
                    _buildTabChip('Artists', 3),
                    _buildTabChip('Playlists', 4),
                  ],
                ),
              ),
            Expanded(child: _buildContent(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PlaylistProvider provider) {
    if (provider.isCategorizedSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.text.isNotEmpty && _suggestions.isNotEmpty) {
      return _buildSuggestionsSection();
    }

    if (!_hasSearched) {
      return _buildHistorySection(provider);
    }

    final results = provider.categorizedResults;
    if (results == null || results.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSongsList(results.songs),
        _buildVideosList(results.videos),
        _buildAlbumsList(results.albums),
        _buildArtistsList(results.artists),
        _buildPlaylistsList(results.playlists),
      ],
    );
  }

  Widget _buildSuggestionsSection() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(8)),
          ),
          child: ListTile(
            leading: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
            title: Text(
              suggestion,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: const Icon(Icons.north_west_rounded, color: Colors.white24, size: 16),
            onTap: () {
              _controller.text = suggestion;
              _suggestions = [];
              _search();
            },
          ),
        );
      },
    );
  }

  Widget _buildHistorySection(PlaylistProvider provider) {
    final history = provider.searchHistory;
    if (history.isEmpty) {
      return Center(
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
                Icons.search_rounded,
                size: 34,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Search for music',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your recent searches will appear here',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => provider.clearSearchHistory(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(14)),
                  ),
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((query) {
              return GestureDetector(
                onTap: () => _searchFromHistory(query),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => provider.removeSearchHistory(query),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList(List<Track> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          'No songs found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }
    final player = context.watch<PlayerProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final track = songs[index];
          return TrackTile(
            track: track,
            isCurrent: player.currentTrack?.id == track.id,
            isDownloaded: downloadProvider.downloadedTrackIds.contains(track.id),
            isDownloading: downloadProvider.activeDownloads.containsKey(track.id),
            isFavorite: playlistProvider.isFavorite(track.id),
            onDownload: downloadProvider.downloadedTrackIds.contains(track.id)
                ? null
                : () {
                    final quality = context.read<SettingsProvider>().audioQuality;
                    downloadProvider.downloadTrack(
                      track,
                      '__search__',
                      quality: quality.name,
                    );
                  },
            onToggleFavorite: () => playlistProvider.toggleFavorite(track),
            onMore: () => showTrackActionSheet(
              context,
              track: track,
              queue: songs,
              index: index,
              playlistId: '__search__',
            ),
            onTap: () => _playTrack(track, songs, index),
          );
        },
      ),
    );
  }

  Widget _buildVideosList(List<Track> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Text(
          'No videos found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }
    final player = context.watch<PlayerProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final track = videos[index];
          return TrackTile(
            track: track,
            isCurrent: player.currentTrack?.id == track.id,
            isDownloaded: downloadProvider.downloadedTrackIds.contains(track.id),
            isDownloading: downloadProvider.activeDownloads.containsKey(track.id),
            isFavorite: playlistProvider.isFavorite(track.id),
            onDownload: downloadProvider.downloadedTrackIds.contains(track.id)
                ? null
                : () {
                    final quality = context.read<SettingsProvider>().audioQuality;
                    downloadProvider.downloadTrack(
                      track,
                      '__search__',
                      quality: quality.name,
                    );
                  },
            onToggleFavorite: () => playlistProvider.toggleFavorite(track),
            onMore: () => showTrackActionSheet(
              context,
              track: track,
              queue: videos,
              index: index,
              playlistId: '__search__',
            ),
            onTap: () => _playTrack(track, videos, index),
          );
        },
      ),
    );
  }

  Widget _buildAlbumsList(List<AlbumResult> albums) {
    if (albums.isEmpty) {
      return Center(
        child: Text(
          'No albums found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(12)),
            ),
            child: ListTile(
              tileColor: const Color(0xFF171717),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: album.thumbnailUrl ?? '',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFF282828),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 54,
                    height: 54,
                    color: Colors.grey[800],
                    child: const Icon(Icons.album_rounded),
                  ),
                ),
              ),
              title: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${album.artist}${album.year != null ? ' · ${album.year}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistsList(List<ArtistResult> artists) {
    if (artists.isEmpty) {
      return Center(
        child: Text(
          'No artists found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(12)),
            ),
            child: ListTile(
              tileColor: const Color(0xFF171717),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: artist.thumbnailUrl ?? '',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFF282828),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 54,
                    height: 54,
                    color: Colors.grey[800],
                    child: const Icon(Icons.person),
                  ),
                ),
              ),
              title: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Artist',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistScreen(
                    artistId: artist.id,
                    name: artist.name,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList(List<PlaylistResult> playlists) {
    if (playlists.isEmpty) {
      return Center(
        child: Text(
          'No playlists found',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(12)),
            ),
            child: ListTile(
              tileColor: const Color(0xFF171717),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: playlist.thumbnailUrl ?? '',
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFF282828),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 54,
                    height: 54,
                    color: Colors.grey[800],
                    child: const Icon(Icons.queue_music_rounded),
                  ),
                ),
              ),
              title: Text(
                playlist.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                playlist.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              onTap: () async {
                final provider = context.read<PlaylistProvider>();
                final result = await provider.fetchFromUrl(
                  'https://www.youtube.com/playlist?list=${playlist.id}',
                );
                if (result != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistScreen(playlist: result),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    return AnimatedBuilder(
      animation: _tabController.animation ?? _tabController,
      builder: (context, _) {
        final indexValue =
            _tabController.animation?.value ?? _tabController.index.toDouble();
        final isSelected = (indexValue - index).abs() < 0.5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF171717),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withAlpha(12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }
}
