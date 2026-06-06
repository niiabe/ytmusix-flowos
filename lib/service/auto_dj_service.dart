// ignore_for_file: prefer_initializing_formals

import 'dart:developer' as dev;
import 'package:hive/hive.dart';
import '../domain/entities/video.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/repositories/playlist_repository.dart';
import '../data/datasources/local/playlist_database.dart';

class AutoDjService {
  final AudioRepository _audioRepository;
  final PlaylistRepository _playlistRepository;
  final PlaylistDatabase _database = PlaylistDatabase();
  final Set<String> _recentlyPlayedIds = <String>{};
  final List<String> _recentlyPlayedOrder = <String>[];

  static const int _maxRecentlyPlayedIds = 100;

  AutoDjService({
    required AudioRepository audioRepository,
    required PlaylistRepository playlistRepository,
  }) : _audioRepository = audioRepository,
       _playlistRepository = playlistRepository;

  Future<List<Track>> getContinuationTracks({
    required String mode,
    required int count,
    required Track currentTrack,
    List<String> excludeIds = const [],
  }) async {
    if (mode == 'off' || count <= 0) {
      return const [];
    }

    try {
      _rememberTrackId(currentTrack.id);
      final effectiveExcludeIds = <String>{
        ...excludeIds,
        ..._recentlyPlayedIds,
      }.toList();

      final tracks = switch (mode) {
        'shuffleLibrary' => await _getShuffleLibrary(
          count,
          effectiveExcludeIds,
        ),
        'similarSongs' => await _getSimilarSongs(
          currentTrack,
          count,
          effectiveExcludeIds,
        ),
        'sameGenre' => await _getSameGenre(
          currentTrack,
          count,
          effectiveExcludeIds,
        ),
        'sameArtist' => await _getSameArtist(
          currentTrack,
          count,
          effectiveExcludeIds,
        ),
        'smartMix' => await _getSmartMix(
          currentTrack,
          count,
          effectiveExcludeIds,
        ),
        _ => const <Track>[],
      };

      for (final track in tracks) {
        _rememberTrackId(track.id);
      }
      return tracks;
    } catch (e) {
      dev.log('AutoDJ failed for mode $mode: $e', name: 'AutoDjService');
      return const [];
    }
  }

  void _rememberTrackId(String id) {
    if (id.isEmpty || _recentlyPlayedIds.contains(id)) return;

    _recentlyPlayedIds.add(id);
    _recentlyPlayedOrder.add(id);

    while (_recentlyPlayedOrder.length > _maxRecentlyPlayedIds) {
      final expired = _recentlyPlayedOrder.removeAt(0);
      _recentlyPlayedIds.remove(expired);
    }
  }

  Future<List<Track>> _getShuffleLibrary(
    int count,
    List<String> excludeIds,
  ) async {
    final library = await _getLibraryPool();
    if (library.isEmpty) return const [];

    final filtered = library.where((t) => !excludeIds.contains(t.id)).toList();
    if (filtered.isEmpty) return const [];

    filtered.shuffle();
    return filtered.take(count).toList();
  }

  Future<List<Track>> _getSimilarSongs(
    Track seed,
    int count,
    List<String> excludeIds,
  ) async {
    try {
      final recs = await _audioRepository.getRecommendations(
        seed,
        limit: count + 5,
      );
      return recs.where((t) => !excludeIds.contains(t.id)).take(count).toList();
    } catch (e) {
      dev.log('Failed to fetch similar songs: $e', name: 'AutoDjService');
      return _getShuffleLibrary(count, excludeIds);
    }
  }

  Future<List<Track>> _getSameGenre(
    Track seed,
    int count,
    List<String> excludeIds,
  ) async {
    try {
      // Since genre is not explicitly tagged, we query a style-matched playlist mix.
      final query = '${seed.author ?? ""} ${seed.title} style mix';
      final searchResults = await _playlistRepository.search(query);
      if (searchResults.isNotEmpty) {
        final filtered = searchResults
            .where((t) => !excludeIds.contains(t.id) && t.id != seed.id)
            .toList();
        if (filtered.isNotEmpty) {
          filtered.shuffle();
          return filtered.take(count).toList();
        }
      }
    } catch (e) {
      dev.log(
        'Failed to fetch genre matching tracks: $e',
        name: 'AutoDjService',
      );
    }
    return _getSimilarSongs(seed, count, excludeIds);
  }

  Future<List<Track>> _getSameArtist(
    Track seed,
    int count,
    List<String> excludeIds,
  ) async {
    final artistName = seed.author;
    if (artistName == null || artistName.isEmpty) {
      return _getSimilarSongs(seed, count, excludeIds);
    }

    try {
      // If we have artistId, load artist details.
      if (seed.artistId != null && seed.artistId!.isNotEmpty) {
        final artistDetail = await _playlistRepository.getArtist(
          seed.artistId!,
        );
        final topTracks = artistDetail.topSongs;
        if (topTracks.isNotEmpty) {
          final filtered = topTracks
              .where((t) => !excludeIds.contains(t.id) && t.id != seed.id)
              .toList();
          if (filtered.isNotEmpty) return filtered.take(count).toList();
        }
      }

      // Fallback: search for top songs of the artist.
      final searchResults = await _playlistRepository.search(
        '$artistName top tracks',
      );
      final filtered = searchResults
          .where((t) => !excludeIds.contains(t.id) && t.id != seed.id)
          .toList();
      if (filtered.isNotEmpty) {
        return filtered.take(count).toList();
      }
    } catch (e) {
      dev.log('Failed same artist auto dj: $e', name: 'AutoDjService');
    }
    return _getSimilarSongs(seed, count, excludeIds);
  }

  Future<List<Track>> _getSmartMix(
    Track seed,
    int count,
    List<String> excludeIds,
  ) async {
    final list = <Track>[];

    // 1. Load library pool tracks.
    final libraryPool = await _getShuffleLibrary(
      (count * 0.4).ceil(),
      excludeIds,
    );
    list.addAll(libraryPool);

    // Update exclusions.
    final currentExcludes = [...excludeIds, ...list.map((t) => t.id)];

    // 2. Load similar tracks.
    final similarCount = (count * 0.4).ceil();
    if (similarCount > 0) {
      final similarPool = await _getSimilarSongs(
        seed,
        similarCount,
        currentExcludes,
      );
      list.addAll(similarPool);
    }

    // Update exclusions.
    final finalExcludes = [...currentExcludes, ...list.map((t) => t.id)];

    // 3. Load from home feeds in Hive.
    final homeCount = count - list.length;
    if (homeCount > 0) {
      try {
        final box = Hive.box('home_feeds');
        final feedKeys = ['new', 'trend', 'podcasts'];
        final allFeedTracks = <Track>[];
        for (final k in feedKeys) {
          final data = box.get(k) as List?;
          if (data != null) {
            for (final map in data) {
              if (map is Map) {
                final trackMap = Map<String, dynamic>.from(map);
                allFeedTracks.add(
                  Track(
                    id: trackMap['id'] as String,
                    title: trackMap['title'] as String,
                    thumbnailUrl: trackMap['thumbnailUrl'] as String?,
                    duration: Duration(
                      seconds: trackMap['durationSeconds'] as int? ?? 0,
                    ),
                    author: trackMap['author'] as String?,
                  ),
                );
              }
            }
          }
        }
        final filteredFeeds = allFeedTracks
            .where((t) => !finalExcludes.contains(t.id))
            .toList();
        if (filteredFeeds.isNotEmpty) {
          filteredFeeds.shuffle();
          list.addAll(filteredFeeds.take(homeCount));
        }
      } catch (e) {
        dev.log('Failed loading smart mix feeds: $e', name: 'AutoDjService');
      }
    }

    // Final fallback/fill.
    if (list.length < count) {
      final fillCount = count - list.length;
      final fill = await _getShuffleLibrary(fillCount, [
        ...excludeIds,
        ...list.map((t) => t.id),
      ]);
      list.addAll(fill);
    }

    return list.take(count).toList();
  }

  Future<List<Track>> _getLibraryPool() async {
    try {
      final favs = await _database.getFavoriteTracks();
      final downloads = await _database.getAllDownloadedTracks();
      final playlists = await _database.getAllPlaylists();

      final pool = <String, Track>{};
      for (final m in favs) {
        pool[m.id] = m.toEntity();
      }
      for (final m in downloads) {
        pool[m.id] = m.toEntity();
      }
      for (final p in playlists) {
        final tracks = await _database.getTracks(p.id);
        for (final m in tracks) {
          pool[m.id] = m.toEntity();
        }
      }
      return pool.values.toList();
    } catch (e) {
      dev.log('Failed to fetch library pool: $e', name: 'AutoDjService');
      return const [];
    }
  }
}
