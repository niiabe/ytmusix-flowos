import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/chart_item.dart';
import '../providers/player_provider.dart';
import '../providers/chart_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../../domain/entities/video.dart';
import 'home_screen.dart';
import '../widgets/now_playing_fab.dart';

class ChartListScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ChartItem> items;
  final String playlistId;

  const ChartListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.playlistId,
  });

  @override
  State<ChartListScreen> createState() => _ChartListScreenState();
}

class _ChartListScreenState extends State<ChartListScreen> {
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
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return _buildChartItemTile(context, item, index);
                },
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChartItemTile(BuildContext context, ChartItem item, int index) {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text(
                '#${item.rank}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
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
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          item.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        onTap: () => _playChartItem(
          context,
          item,
          widget.items,
          index,
          playerProvider,
          playlistProvider,
          widget.playlistId,
          openPlayer: true,
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
            '$cleanTitle $cleanArtist official audio',
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
      if (results.isNotEmpty) {
        final ytTrack = results.first;
        return Track(
          id: ytTrack.id,
          title: item.title,
          author: item.artist,
          thumbnailUrl: item.artworkUrl ?? ytTrack.thumbnailUrl,
          duration: ytTrack.duration,
          albumId: ytTrack.albumId,
          artistId: ytTrack.artistId,
          index: ytTrack.index,
        );
      }
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
}
