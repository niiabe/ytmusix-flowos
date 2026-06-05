import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/playlist_sort_mode.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/video.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/pixel_logo.dart';
import '../widgets/now_playing_fab.dart';
import '../widgets/track_action_sheet.dart';
import 'playlist_screen.dart';
import 'album_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'chart_list_screen.dart';
import 'downloaded_screen.dart';
import '../../domain/entities/chart_item.dart';
import '../providers/chart_provider.dart';
import '../../service/chart_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = ['Recent', 'New', 'Trend', 'Podcasts', 'Favourites'];
  int _homeTab = 0;

  bool get _isPlaylistTab => _homeTab == 0;
  bool get _isFavoritesTab => _homeTab == 4;

  String? get _activeFeedKey {
    if (_homeTab == 1) return 'new';
    if (_homeTab == 2) return 'trend';
    if (_homeTab == 3) return 'podcasts';
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().loadSavedPlaylists();
      context.read<PlaylistProvider>().loadFavoriteIds();
      context.read<PlaylistProvider>().loadFavoriteCollections();
      context.read<ChartProvider>().loadCharts();
      context.read<PlayerProvider>().loadRecentlyPlayed();
    });
  }

  void _selectHomeTab(int index) {
    setState(() => _homeTab = index);
    final key = _activeFeedKey;
    if (key != null) {
      context.read<PlaylistProvider>().loadHomeFeed(key);
    }
  }

  Future<void> _showLinkDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste YouTube link'),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Video, playlist, or mix link',
            prefixIcon: Icon(Icons.link),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final text = result?.trim();
    if (text == null || text.isEmpty) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading $text...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final provider = context.read<PlaylistProvider>();
    final playlist = await provider.fetchFromUrl(text);
    if (!context.mounted) return;

    if (playlist != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to load link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    return Scaffold(
      floatingActionButton: NowPlayingFab(
        track: player.currentTrack,
        isPlaying: player.isPlaying,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildErrorBanner(),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const PixelLogo(size: 40),
          const Spacer(),
          _roundIconButton(
            icon: Icons.search,
            tooltip: 'Search YouTube',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _roundIconButton(
            icon: Icons.link_rounded,
            tooltip: 'Paste YouTube link',
            onPressed: () => _showLinkDialog(context),
          ),
          const SizedBox(width: 8),
          Consumer<PlaylistProvider>(
            builder: (context, provider, _) => _roundIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Sort playlists',
              onPressed: () => _showSortSheet(context, provider),
            ),
          ),
          const SizedBox(width: 8),
          _roundIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context, PlaylistProvider provider) {
    final options = [
      (PlaylistSortMode.dateAdded, 'Date added', Icons.schedule_rounded),
      (PlaylistSortMode.title, 'Title', Icons.sort_by_alpha_rounded),
      (PlaylistSortMode.trackCount, 'Track count', Icons.queue_music_rounded),
    ];
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
                      'Sort playlists',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...options.map((option) {
                      final selected = provider.sortMode == option.$1;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            option.$3,
                            color: selected ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          option.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                        onTap: () {
                          provider.setSortMode(option.$1);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF191919),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        if (provider.error == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withAlpha(100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => provider.clearError(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Consumer3<PlaylistProvider, PlayerProvider, DownloadProvider>(
      builder: (context, provider, playerProvider, downloadProvider, _) {
        final feedKey = _activeFeedKey;
        final feedTracks = feedKey == null
            ? const <Track>[]
            : provider.homeFeed(feedKey);
        final isFeedLoading =
            feedKey != null && provider.isHomeFeedLoading(feedKey);

        if (provider.isLoading && feedKey == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.playlists.isEmpty &&
            provider.favoriteIds.isEmpty &&
            feedKey == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoWithHeadset(size: 120),
                const SizedBox(height: 16),
                Text(
                  'No playlists yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search YouTube or paste a link to get started',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () {
            final key = _activeFeedKey;
            if (key != null) {
              return provider.loadHomeFeed(key, force: true);
            }
            return Future.wait([
              provider.loadSavedPlaylists(),
              provider.loadFavoriteCollections(),
              context.read<ChartProvider>().loadCharts(force: true),
            ]);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 146),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Browse',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white.withAlpha(10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download_done_rounded, size: 18),
                    label: const Text(
                      'Downloaded',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadedScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildCategoryTabs(),
              const SizedBox(height: 22),
              if (feedKey != null)
                _buildTrackShelf(
                  context,
                  feedTracks,
                  isFeedLoading,
                  playerProvider,
                  feedKey,
                )
              else if (_isFavoritesTab)
                _buildPlaylistShelf(
                  context,
                  provider.favoriteCollections,
                  playerProvider,
                  downloadProvider,
                )
              else if (_isPlaylistTab &&
                  playerProvider.recentlyPlayed.isNotEmpty)
                _buildTrackShelf(
                  context,
                  playerProvider.recentlyPlayed,
                  false,
                  playerProvider,
                  'recent',
                )
              else if (_isPlaylistTab)
                _buildPlaylistShelf(
                  context,
                  _filteredPlaylists(provider),
                  playerProvider,
                  downloadProvider,
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 28),
              _buildTopHits(
                context,
                _filteredPlaylists(provider),
                _homeTab == 0
                    ? playerProvider.recentlyPlayed
                    : _isFavoritesTab
                    ? provider.favoriteTracks
                    : feedTracks,
                playerProvider,
                _isFavoritesTab ? provider.favoriteIds : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = index == _homeTab;
          return GestureDetector(
            onTap: () => _selectHomeTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary.withAlpha(30)
                    : const Color(0xFF171717),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active
                      ? Theme.of(context).colorScheme.primary.withAlpha(120)
                      : Colors.white.withAlpha(12),
                  width: active ? 1.2 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackShelf(
    BuildContext context,
    List<Track> tracks,
    bool isLoading,
    PlayerProvider playerProvider,
    String feedKey,
  ) {
    if (isLoading && tracks.isEmpty) {
      return const SizedBox(
        height: 184,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (tracks.isEmpty) {
      return _EmptyShelf(tabLabel: _tabs[_homeTab]);
    }
    return SizedBox(
      height: 184,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isCurrent = playerProvider.currentTrack?.id == track.id;
          return SizedBox(
            width: 138,
            child: _HomeTrackCard(
              track: track,
              isCurrent: isCurrent,
              isPlaying: isCurrent && playerProvider.isPlaying,
              onTap: () => _playTrackShelfItem(
                context,
                tracks,
                index,
                playerProvider,
                feedKey,
                openPlayer: true,
              ),
              onPlay: () async {
                if (isCurrent) {
                  playerProvider.togglePlayPause();
                  return;
                }
                await _playTrackShelfItem(
                  context,
                  tracks,
                  index,
                  playerProvider,
                  feedKey,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _playTrackShelfItem(
    BuildContext context,
    List<Track> tracks,
    int index,
    PlayerProvider playerProvider,
    String feedKey, {
    bool openPlayer = false,
  }) async {
    if (index < 0 || index >= tracks.length) return;

    final quality = context.read<SettingsProvider>().audioQuality;
    final track = tracks[index];
    playerProvider.setQueue(
      tracks,
      startIndex: index,
      playlistId: '__feed_$feedKey',
    );
    await playerProvider.playTrack(track, quality: quality);

    if (!context.mounted) return;
    if (playerProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(playerProvider.error!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (openPlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      );
    }
  }

  Widget _buildPlaylistShelf(
    BuildContext context,
    List<Playlist> playlists,
    PlayerProvider playerProvider,
    DownloadProvider downloadProvider,
  ) {
    if (playlists.isEmpty) {
      return _EmptyShelf(tabLabel: _tabs[_homeTab]);
    }
    return SizedBox(
      height: 184,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final provider = context.read<PlaylistProvider>();
          final isCurrent = playerProvider.currentPlaylistId == playlist.id;
          final isDownloading = downloadProvider.isDownloadingPlaylist(
            playlist.id,
          );
          final isDownloaded = downloadProvider.isPlaylistFullyDownloaded(
            playlist.id,
          );
          return SizedBox(
            width: 138,
            child: _BrowsePlaylistCard(
              playlist: playlist,
              isCurrentPlaylist: isCurrent,
              isPlaying: playerProvider.isPlaying,
              isDownloaded: isDownloaded,
              isDownloading: isDownloading,
              onTap: () => _openBrowsePlaylist(
                context,
                playlist,
                playerProvider,
                provider,
              ),
              onPlay: () async {
                if (isCurrent) {
                  playerProvider.togglePlayPause();
                  return;
                }
                if (await _playBrowsePlaylist(
                  context,
                  playlist,
                  playerProvider,
                  provider,
                )) {
                  return;
                }
                final cachedTracks = await provider.getCachedTracks(
                  playlist.id,
                );
                if (cachedTracks != null &&
                    cachedTracks.isNotEmpty &&
                    context.mounted) {
                  final settings = context.read<SettingsProvider>();
                  playerProvider.setQueue(
                    cachedTracks,
                    startIndex: 0,
                    playlistId: playlist.id,
                  );
                  await playerProvider.playTrack(
                    cachedTracks.first,
                    quality: settings.audioQuality,
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open the playlist first to cache tracks'),
                    ),
                  );
                }
              },
              onDownload: () async {
                if (isDownloading) {
                  downloadProvider.cancelDownload();
                  return;
                }
                if (isDownloaded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Playlist is already downloaded'),
                    ),
                  );
                  return;
                }
                final provider = context.read<PlaylistProvider>();
                final cachedTracks = await provider.getCachedTracks(
                  playlist.id,
                );
                if (cachedTracks != null &&
                    cachedTracks.isNotEmpty &&
                    context.mounted) {
                  final fullPlaylist = Playlist(
                    id: playlist.id,
                    title: playlist.title,
                    author: playlist.author,
                    thumbnailUrl: playlist.thumbnailUrl,
                    videoCount: cachedTracks.length,
                    tracks: cachedTracks,
                  );
                  final settings = context.read<SettingsProvider>();
                  downloadProvider.downloadPlaylist(
                    fullPlaylist,
                    quality: settings.audioQuality.name,
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open the playlist first to load tracks, then download',
                      ),
                    ),
                  );
                }
              },
              onDelete: () {
                if (_homeTab == 5) {
                  provider.toggleFavoriteCollection(
                    playlist,
                    playlist.type ?? 'playlist',
                  );
                } else {
                  provider.deletePlaylist(playlist.id);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBrowsePlaylist(
    BuildContext context,
    Playlist playlist,
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
  ) async {
    if (playlist.type == 'album') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlbumScreen(
            albumId: playlist.id,
            title: playlist.title,
            artist: playlist.author,
            thumbnailUrl: playlist.thumbnailUrl,
          ),
        ),
      );
      return;
    }

    if (playlist.tracks.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
      );
      return;
    }

    final played = await _playBrowsePlaylist(
      context,
      playlist,
      playerProvider,
      playlistProvider,
      openPlayer: true,
    );
    if (!played && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find a playable track')),
      );
    }
  }

  Future<bool> _playBrowsePlaylist(
    BuildContext context,
    Playlist playlist,
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider, {
    bool openPlayer = false,
  }) async {
    if (playlist.type == 'album') return false;

    final track = playlist.tracks.isNotEmpty
        ? playlist.tracks.first
        : await _resolveEmptyPlaylistTrack(playlistProvider, playlist);
    if (track == null) return false;
    if (!context.mounted) return false;

    final settings = context.read<SettingsProvider>();
    playerProvider.setQueue([track], startIndex: 0, playlistId: track.id);
    await playerProvider.playTrack(track, quality: settings.audioQuality);

    if (openPlayer && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerScreen()),
      );
    }
    return true;
  }

  Future<Track?> _resolveEmptyPlaylistTrack(
    PlaylistProvider provider,
    Playlist playlist,
  ) async {
    Track? track;
    if (_looksLikeVideoId(playlist.id)) {
      track = Track(
        id: playlist.id,
        title: playlist.title,
        author: playlist.author,
        thumbnailUrl: playlist.thumbnailUrl,
        duration: Duration.zero,
      );
    } else {
      track = await _findChartTrack(
        provider,
        ChartItem(
          id: playlist.id,
          rank: 1,
          title: playlist.title,
          artist: playlist.author ?? '',
          artworkUrl: playlist.thumbnailUrl,
          sourceName: 'Saved',
          sourceUrl: '',
          kind: ChartItemKind.song,
        ),
      );
    }

    if (track != null) {
      await provider.saveSingleTrack(track);
    }
    return track;
  }

  bool _looksLikeVideoId(String id) {
    return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  }

  Widget _buildChartShelf(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<ChartItem> items,
    required bool isLoading,
    required PlayerProvider playerProvider,
    required PlaylistProvider playlistProvider,
    required String playlistId,
    required Future<void> Function() onRefresh,
    Widget? headerAction,
    bool autoPlayOnResolve = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (headerAction != null) ...[
              const SizedBox(width: 8),
              headerAction,
            ],
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                tooltip: 'Refresh $title',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: isLoading ? null : onRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoading && items.isEmpty)
          const SizedBox(
            height: 184,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          _EmptyShelf(tabLabel: title)
        else
          SizedBox(
            height: 184,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: items.length > 10 ? 11 : items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                if (index == 10) {
                  return _SeeMoreCard(
                    title: title,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChartListScreen(
                            title: title,
                            subtitle: subtitle,
                            items: items,
                            playlistId: playlistId,
                          ),
                        ),
                      );
                    },
                  );
                }
                final item = items[index];
                return SizedBox(
                  width: 138,
                  child: _ChartItemCard(
                    item: item,
                    onTap: () => _playChartItem(
                      context,
                      item,
                      items,
                      index,
                      playerProvider,
                      playlistProvider,
                      playlistId,
                      openPlayer: true,
                      autoPlayOnResolve: autoPlayOnResolve,
                    ),
                    onPlay: () => _playChartItem(
                      context,
                      item,
                      items,
                      index,
                      playerProvider,
                      playlistProvider,
                      playlistId,
                      autoPlayOnResolve: autoPlayOnResolve,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAppleTopScopeSelector(ChartProvider chartProvider) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppleTopSongsScope>(
          value: chartProvider.appleTopSongsScope,
          dropdownColor: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          items: AppleTopSongsScope.values
              .map(
                (scope) =>
                    DropdownMenuItem(value: scope, child: Text(scope.label)),
              )
              .toList(),
          onChanged:
              chartProvider.isLoading(
                ChartService.appleTopSongsKey(chartProvider.appleTopSongsScope),
              )
              ? null
              : (scope) {
                  if (scope == null) return;
                  chartProvider.loadAppleTopSongs(scope: scope);
                },
        ),
      ),
    );
  }

  Future<void> _playChartItem(
    BuildContext context,
    ChartItem item,
    List<ChartItem> sourceItems,
    int index,
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
    String playlistId, {
    bool openPlayer = false,
    bool autoPlayOnResolve = true,
  }) async {
    final chartProvider = context.read<ChartProvider>();
    final settings = context.read<SettingsProvider>();
    final notifier = ValueNotifier(
      ChartResolveState(
        item: item,
        status: item.kind == ChartItemKind.album
            ? 'Finding ${item.title} songs'
            : 'Finding ${item.title} song',
      ),
    );
    var sheetActive = true;

    void update(ChartResolveState Function(ChartResolveState state) apply) {
      if (!sheetActive) return;
      notifier.value = apply(notifier.value);
    }

    Future<void> playResolvedTrack(Track track) async {
      final state = notifier.value;
      final queue = <Track>[];
      for (final chartItem in state.items.take(18)) {
        final resolved = state.resolvedTracks[chartItem.id];
        if (resolved != null && queue.every((item) => item.id != resolved.id)) {
          queue.add(resolved);
        }
      }
      if (queue.isEmpty) return;
      final startIndex = queue.indexWhere((item) => item.id == track.id);
      final index = startIndex < 0 ? 0 : startIndex;
      playerProvider.setQueue(queue, startIndex: index, playlistId: playlistId);
      await playerProvider.playTrack(
        queue[index],
        quality: settings.audioQuality,
      );
      update(
        (state) => state.copyWith(
          hasStartedPlayback: true,
          status: 'Playing ${queue[index].title}',
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChartItemDetailsSheet(
        notifier: notifier,
        onPlayTrack: playResolvedTrack,
      ),
    ).whenComplete(() {
      sheetActive = false;
      notifier.dispose();
    });

    try {
      final isAlbum = item.kind == ChartItemKind.album;
      final playableItems = item.kind == ChartItemKind.album
          ? await chartProvider.getAlbumSongs(item)
          : [
              item,
              ...sourceItems
                  .where((sourceItem) => sourceItem.id != item.id)
                  .take(17),
            ];
      update(
        (state) => state.copyWith(
          items: playableItems,
          status: item.kind == ChartItemKind.album
              ? 'Finding ${item.title} songs'
              : 'Finding ${item.title} song',
        ),
      );

      final tracks = <Track>[];
      var playbackStarted = false;

      for (final chartItem in playableItems.take(18)) {
        update(
          (state) => state.copyWith(
            activeItemId: chartItem.id,
            status: item.kind == ChartItemKind.album
                ? 'Finding ${item.title} songs'
                : 'Finding ${chartItem.title} song',
          ),
        );

        final track = await _findChartTrack(
          playlistProvider,
          chartItem,
          albumContext: item.kind == ChartItemKind.album ? item : null,
        );
        if (track == null) continue;
        if (tracks.any((queued) => queued.id == track.id)) continue;

        tracks.add(track);
        final resolvedTracks = Map<String, Track>.from(
          notifier.value.resolvedTracks,
        )..[chartItem.id] = track;
        update(
          (state) => state.copyWith(
            tracks: List<Track>.from(tracks),
            resolvedTracks: resolvedTracks,
            status: item.kind == ChartItemKind.album
                ? 'Found ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} from ${item.title}'
                : 'Found ${chartItem.title}',
          ),
        );

        if (isAlbum || !autoPlayOnResolve) {
          continue;
        }

        if (!playbackStarted) {
          playbackStarted = true;
          playerProvider.setQueue(
            tracks,
            startIndex: 0,
            playlistId: playlistId,
          );
          await playerProvider.playTrack(track, quality: settings.audioQuality);
          update(
            (state) => state.copyWith(
              hasStartedPlayback: true,
              status: 'Playing ${track.title}',
            ),
          );
          if (openPlayer && context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        } else {
          playerProvider.setQueue(
            tracks,
            startIndex: 0,
            playlistId: playlistId,
          );
        }
      }

      if (tracks.isEmpty) {
        update(
          (state) => state.copyWith(
            isResolving: false,
            error: 'Could not find ${item.title} on YouTube',
            status: 'No playable match found',
          ),
        );
        return;
      }

      update(
        (state) => state.copyWith(
          isResolving: false,
          clearActiveItem: true,
          status: item.kind == ChartItemKind.album
              ? 'Ready: ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} found'
              : 'Ready to play',
        ),
      );
    } catch (e) {
      update(
        (state) => state.copyWith(
          isResolving: false,
          error: 'Could not load ${item.title}',
          status: e.toString(),
        ),
      );
    }
  }

  Future<Track?> _findChartTrack(
    PlaylistProvider playlistProvider,
    ChartItem item, {
    ChartItem? albumContext,
  }) async {
    final rawTitle = item.title.trim();
    final rawArtist = item.artist.trim();
    final cleanTitle = _cleanSearchText(item.title);
    final cleanArtist = _cleanSearchText(item.artist);
    final albumTitle = albumContext == null
        ? null
        : _cleanSearchText(albumContext.title);
    final queryCandidates = item.kind == ChartItemKind.album
        ? [
            '$rawArtist $rawTitle album songs',
            '$cleanArtist $cleanTitle album songs',
            '$cleanArtist $cleanTitle full album',
            '$rawTitle $rawArtist album',
            '$cleanTitle $cleanArtist album',
            '$rawArtist $rawTitle',
            '$cleanTitle $cleanArtist',
          ]
        : [
            '$rawArtist $rawTitle official audio',
            '$cleanArtist $cleanTitle official audio',
            '$rawTitle $rawArtist official audio',
            '$cleanArtist $cleanTitle official audio',
            if (albumTitle != null) '$rawArtist $rawTitle $albumTitle',
            if (albumTitle != null) '$cleanArtist $cleanTitle $albumTitle',
            '$rawArtist $rawTitle lyrics',
            '$cleanArtist $cleanTitle lyrics',
            '$rawTitle $rawArtist lyrics',
            '$cleanTitle $cleanArtist lyrics',
            '$rawArtist $rawTitle',
            '$cleanArtist $cleanTitle',
            '$rawTitle $rawArtist',
            '$cleanTitle $cleanArtist',
          ];
    final seenQueries = <String>{};
    final queries = [
      for (final query in queryCandidates)
        if (query.trim().isNotEmpty && seenQueries.add(query.trim()))
          query.trim(),
    ];

    for (final query in queries) {
      final results = await playlistProvider.searchSilently(query);
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  String _cleanSearchText(String value) {
    return value
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(
          RegExp(r'\b(feat|ft|with)\.?\b.*$', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildTopHits(
    BuildContext context,
    List<Playlist> playlists,
    List<Track> feedTracks,
    PlayerProvider playerProvider,
    Set<String>? favoriteIds,
  ) {
    final tracks = <String, Track>{};
    if (feedTracks.isNotEmpty) {
      for (final track in feedTracks) {
        tracks[track.id] = track;
      }
    } else {
      for (final track in playerProvider.recentlyPlayed) {
        if (favoriteIds == null || favoriteIds.contains(track.id)) {
          tracks[track.id] = track;
        }
      }
      for (final playlist in playlists) {
        for (final track in playlist.tracks) {
          if (favoriteIds == null || favoriteIds.contains(track.id)) {
            tracks[track.id] = track;
          }
        }
      }
    }
    final topTracks = tracks.values.take(6).toList();
    final title = switch (_homeTab) {
      1 => 'New from YouTube',
      2 => 'Trending on YouTube',
      3 => 'Podcasts',
      4 => 'Favourite tracks',
      _ => 'Recent plays',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        if (topTracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _homeTab == 4
                        ? 'Star tracks to fill your favourites chart.'
                        : _activeFeedKey != null
                        ? 'Pull to refresh YouTube results.'
                        : 'Open a playlist or play a track to fill your chart.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          )
        else
          ...topTracks.indexed.map((item) {
            final index = item.$1;
            final track = item.$2;
            return _TopHitTile(
              rank: index + 1,
              track: track,
              onMore: () => showTrackActionSheet(
                context,
                track: track,
                queue: topTracks,
                index: index,
                playlistId: _activeFeedKey == null
                    ? null
                    : '__feed_${_activeFeedKey!}',
              ),
              onTap: () {
                final settings = context.read<SettingsProvider>();
                playerProvider.setQueue(
                  topTracks,
                  startIndex: index,
                  playlistId: _activeFeedKey == null
                      ? null
                      : '__feed_${_activeFeedKey!}',
                );
                playerProvider.playTrack(track, quality: settings.audioQuality);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerScreen()),
                );
              },
            );
          }),
      ],
    );
  }

  List<Playlist> _filteredPlaylists(PlaylistProvider provider) {
    final playlists = List<Playlist>.from(provider.playlists);
    switch (_homeTab) {
      case 1:
      case 2:
      case 3:
        return playlists;
      case 4:
        final favoriteIds = provider.favoriteIds;
        return playlists
            .where(
              (playlist) => playlist.tracks.any(
                (track) => favoriteIds.contains(track.id),
              ),
            )
            .map(
              (playlist) => Playlist(
                id: playlist.id,
                title: playlist.title,
                description: playlist.description,
                thumbnailUrl: playlist.thumbnailUrl,
                author: playlist.author,
                videoCount: playlist.tracks
                    .where((track) => favoriteIds.contains(track.id))
                    .length,
                tracks: playlist.tracks
                    .where((track) => favoriteIds.contains(track.id))
                    .toList(),
              ),
            )
            .toList();
      default:
        return playlists;
    }
  }
}

class _EmptyShelf extends StatelessWidget {
  final String tabLabel;

  const _EmptyShelf({required this.tabLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.library_music_rounded, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No $tabLabel items yet.',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartResolveState {
  final ChartItem item;
  final List<ChartItem> items;
  final List<Track> tracks;
  final Map<String, Track> resolvedTracks;
  final String status;
  final String? activeItemId;
  final String? error;
  final bool isResolving;
  final bool hasStartedPlayback;

  const ChartResolveState({
    required this.item,
    required this.status,
    this.items = const [],
    this.tracks = const [],
    this.resolvedTracks = const {},
    this.activeItemId,
    this.error,
    this.isResolving = true,
    this.hasStartedPlayback = false,
  });

  ChartResolveState copyWith({
    List<ChartItem>? items,
    List<Track>? tracks,
    Map<String, Track>? resolvedTracks,
    String? status,
    String? activeItemId,
    bool clearActiveItem = false,
    String? error,
    bool? isResolving,
    bool? hasStartedPlayback,
  }) {
    return ChartResolveState(
      item: item,
      items: items ?? this.items,
      tracks: tracks ?? this.tracks,
      resolvedTracks: resolvedTracks ?? this.resolvedTracks,
      status: status ?? this.status,
      activeItemId: clearActiveItem ? null : activeItemId ?? this.activeItemId,
      error: error ?? this.error,
      isResolving: isResolving ?? this.isResolving,
      hasStartedPlayback: hasStartedPlayback ?? this.hasStartedPlayback,
    );
  }
}

class ChartItemDetailsSheet extends StatelessWidget {
  final ValueNotifier<ChartResolveState> notifier;
  final Future<void> Function(Track track) onPlayTrack;

  const ChartItemDetailsSheet({
    super.key,
    required this.notifier,
    required this.onPlayTrack,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return ValueListenableBuilder<ChartResolveState>(
          valueListenable: notifier,
          builder: (context, state, _) {
            final item = state.item;
            final isAlbum = item.kind == ChartItemKind.album;
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: Image.network(
                            item.artworkUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFF252525),
                              child: Icon(
                                isAlbum
                                    ? Icons.album_rounded
                                    : Icons.music_note_rounded,
                                color: Colors.white38,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAlbum ? 'Album details' : 'Song details',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '#${item.rank} • ${item.sourceName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ChartResolveStatus(state: state),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAlbum ? 'Album songs' : 'Queue preview',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (state.tracks.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundColor: Colors.white.withAlpha(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Play All',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            if (state.tracks.isNotEmpty) {
                              onPlayTrack(state.tracks.first);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.items.isEmpty)
                    ChartPendingTile(
                      title: state.status,
                      subtitle: 'Searching YouTube in the background',
                    )
                  else
                    ...state.items.take(18).map((chartItem) {
                      final track = state.resolvedTracks[chartItem.id];
                      final isActive = state.activeItemId == chartItem.id;
                      final isCurrentTrack =
                          track != null && player.currentTrack?.id == track.id;
                      final isPlaying = isCurrentTrack && player.isPlaying;
                      final isLoading =
                          (track != null &&
                              isCurrentTrack &&
                              player.isLoading) ||
                          (track == null && isActive);

                      return ChartPendingTile(
                        title: chartItem.title,
                        subtitle: track == null
                            ? isActive
                                  ? 'Finding ${chartItem.title} song'
                                  : chartItem.artist
                            : track.author ?? chartItem.artist,
                        enabled: track != null,
                        isPlaying: isPlaying,
                        isLoading: isLoading,
                        onTap: track == null ? null : () => onPlayTrack(track),
                        trailing: track != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.greenAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ],
                              )
                            : isActive
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.hourglass_empty_rounded,
                                color: Colors.white24,
                                size: 18,
                              ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ChartResolveStatus extends StatelessWidget {
  final ChartResolveState state;

  const ChartResolveStatus({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state.error != null
        ? Colors.redAccent
        : state.isResolving
        ? Theme.of(context).colorScheme.primary
        : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(28)),
      ),
      child: Row(
        children: [
          if (state.isResolving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              state.error != null
                  ? Icons.error_outline_rounded
                  : Icons.play_circle_rounded,
              color: color,
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.error ?? state.status,
              style: TextStyle(
                color: state.error != null ? Colors.redAccent : Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPendingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isPlaying;
  final bool isLoading;

  const ChartPendingTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = false,
    this.isPlaying = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? Theme.of(context).colorScheme.primary.withAlpha(70)
                    : Colors.white.withAlpha(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  enabled
                      ? Icons.play_circle_fill_rounded
                      : Icons.music_note_rounded,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTrackCard extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _HomeTrackCard({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 138,
                  height: 138,
                  child: Image.network(
                    track.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF252525),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white38,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _MiniAction(
                  icon: isCurrent && isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: onPlay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            track.author ?? 'YouTube',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartItemCard extends StatelessWidget {
  final ChartItem item;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _ChartItemCard({
    required this.item,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 138,
                  height: 138,
                  child: Image.network(
                    item.artworkUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF252525),
                      child: Icon(
                        item.kind == ChartItemKind.album
                            ? Icons.album_rounded
                            : Icons.music_note_rounded,
                        color: Colors.white38,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(190),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${item.rank}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _MiniAction(
                  icon: Icons.play_arrow_rounded,
                  onPressed: onPlay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            item.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowsePlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final bool isCurrentPlaylist;
  final bool isPlaying;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _BrowsePlaylistCard({
    required this.playlist,
    required this.isCurrentPlaylist,
    required this.isPlaying,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onTap,
    required this.onPlay,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 138,
                  height: 138,
                  child: Image.network(
                    playlist.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF252525),
                      child: const Icon(
                        Icons.album_rounded,
                        color: Colors.white38,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              if (playlist.type != 'album')
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      _MiniAction(
                        icon: isDownloaded
                            ? Icons.offline_pin_rounded
                            : isDownloading
                            ? Icons.downloading_rounded
                            : Icons.download_rounded,
                        onPressed: onDownload,
                      ),
                      const SizedBox(width: 6),
                      _MiniAction(
                        icon: isCurrentPlaylist && isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        onPressed: onPlay,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            playlist.author ?? '${playlist.videoCount} tracks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withAlpha(180),
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

class _TopHitTile extends StatelessWidget {
  final int rank;
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _TopHitTile({
    required this.rank,
    required this.track,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 8,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Image.network(
            track.thumbnailUrl ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFF252525),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        '#$rank  ${track.author ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
        onPressed: onMore,
      ),
      onTap: onTap,
    );
  }
}

class _SeeMoreCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SeeMoreCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 138,
        height: 138,
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'See more',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
