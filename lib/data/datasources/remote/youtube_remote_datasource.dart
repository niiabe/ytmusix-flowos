import 'dart:async';
import 'dart:developer' as dev;
import 'package:youtube_explode_dart/youtube_explode_dart.dart'
    hide Playlist, Video;
import 'package:http/http.dart' as http;
import '../../../domain/entities/search_result_models.dart';
import '../../models/playlist_model.dart';
import '../../models/video_model.dart';
import '../../../service/auth_service.dart';
import 'authenticated_client.dart';

class YoutubeRemoteDataSource {
  static const _timeout = Duration(seconds: 30);

  final AuthService _authService;
  late final YoutubeExplode _yt;

  YoutubeRemoteDataSource({AuthService? authService})
      : _authService = authService ?? AuthService();

  Future<void> init() async {
    final cookies = await _authService.getCookies();
    final inner = AuthenticatedClient(cookies: cookies);
    final ytHttp = YoutubeHttpClient(inner);
    _yt = YoutubeExplode(httpClient: ytHttp);
    _ytMusic = ytmusic.YTMusic();
    try {
      // Use hl=en + gl=US to bypass geo-restrictions (e.g. China).
      // This presents the international catalog rather than a region-locked one.
      await _ytMusic
          .initialize(cookies: cookies, gl: 'US', hl: 'en')
          .timeout(_timeout);
    } catch (e) {
      dev.log(
        'YouTube Music API initialization failed, using YouTube fallback: $e',
        name: 'YoutubeRemoteDataSource',
      );
    }
  }

  Future<PlaylistModel> getPlaylist(String playlistId) async {
    var attempt = 0;
    final stopwatch = Stopwatch()..start();

    while (true) {
      attempt++;
      try {
        final ytPlaylist = await _yt.playlists
            .get(playlistId)
            .timeout(_timeout);

        final title = ytPlaylist.title;
        final author = ytPlaylist.author;

        final videos = await () async {
          try {
            return await _yt.playlists
                .getVideos(playlistId)
                .toList()
                .timeout(_timeout);
          } catch (e) {
            dev.log('Playlist videos fetch failed for $playlistId (attempt $attempt): $e',
                name: 'YoutubeRemoteDataSource');
            return <dynamic>[];
          }
        }();

        if (videos.isEmpty) {
          throw Exception('No videos found for playlist/mix $playlistId');
        }

        final tracks = <TrackModel>[];
        const chunkVal = 8;
        for (var i = 0; i < videos.length; i += chunkVal) {
          final chunk = videos.sublist(
            i,
            (i + chunkVal) > videos.length ? videos.length : i + chunkVal,
          );
          final chunkResults = await Future.wait(
            chunk.map((video) async {
              Duration? duration = video.duration;
              if (duration == null || duration.inSeconds == 0) {
                try {
                  final fullVideo = await _yt.videos
                      .get(video.id.value)
                      .timeout(const Duration(seconds: 3));
                  duration = fullVideo.duration;
                } catch (e) {
                  dev.log(
                    'Failed to get duration for video ${video.id.value}: $e',
                    name: 'YoutubeRemoteDataSource',
                  );
                }
              }
              return TrackModel(
                id: video.id.value,
                title: video.title,
                author: video.author,
                durationSeconds: duration?.inSeconds ?? 0,
                thumbnailUrl: _highQualityThumbnail(video.id.value),
                index: 0,
              );
            }),
          );
          tracks.addAll(chunkResults);
        }
        for (var i = 0; i < tracks.length; i++) {
          tracks[i] = TrackModel(
            id: tracks[i].id,
            title: tracks[i].title,
            author: tracks[i].author,
            durationSeconds: tracks[i].durationSeconds,
            thumbnailUrl: tracks[i].thumbnailUrl,
            index: i,
          );
        }

        final thumbnailUrl = tracks.isNotEmpty ? tracks.first.thumbnailUrl : null;

        return PlaylistModel(
          id: playlistId,
          title: title,
          author: author,
          thumbnailUrl: thumbnailUrl,
          videoCount: tracks.length,
          tracks: tracks,
        );
      } on TimeoutException {
        dev.log('Attempt $attempt timed out for playlist $playlistId',
            name: 'YoutubeRemoteDataSource');
        if (attempt >= 3 || stopwatch.elapsed > const Duration(seconds: 45)) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * attempt));
      } on Exception catch (e) {
        final msg = e.toString();
        dev.log('Playlist fetch attempt $attempt failed for $playlistId: $msg',
            name: 'YoutubeRemoteDataSource');
        if (attempt >= 3 || stopwatch.elapsed > const Duration(seconds: 45)) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  Future<TrackModel> getVideo(String videoId) async {
    final video = await _yt.videos.get(videoId);
    return TrackModel(
      id: video.id.value,
      title: video.title,
      author: video.author,
      durationSeconds: video.duration?.inSeconds ?? 0,
      thumbnailUrl: _highQualityThumbnail(video.id.value),
      index: 0,
    );
  }

  Future<List<TrackModel>> getHashtagPodcasts() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.youtube.com/hashtag/podcasts'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        final regExp = RegExp(r'"videoId"\s*:\s*"([a-zA-Z0-9_-]{11})"');
        final matches = regExp.allMatches(body);
        final videoIds = <String>[];
        for (final m in matches) {
          final id = m.group(1);
          if (id != null && !videoIds.contains(id)) {
            videoIds.add(id);
          }
        }
        
        if (videoIds.isNotEmpty) {
          final tracks = <TrackModel>[];
          final limit = videoIds.take(18).toList();
          for (var i = 0; i < limit.length; i++) {
            try {
              final video = await _yt.videos.get(limit[i]).timeout(const Duration(seconds: 3));
              tracks.add(
                TrackModel(
                  id: video.id.value,
                  title: video.title,
                  author: video.author,
                  durationSeconds: video.duration?.inSeconds ?? 0,
                  thumbnailUrl: _highQualityThumbnail(video.id.value),
                  index: i,
                ),
              );
            } catch (_) {}
          }
          if (tracks.isNotEmpty) return tracks;
        }
      }
    } catch (e) {
      dev.log('Failed to scrape podcast hashtag page: $e', name: 'YoutubeRemoteDataSource');
    }

    // Fallback: search for '#podcasts'
    try {
      final results = await _yt.search.search('#podcasts').timeout(_timeout);
      final tracks = <TrackModel>[];
      for (var i = 0; i < results.length; i++) {
        final video = results[i];
        tracks.add(
          TrackModel(
            id: video.id.value,
            title: video.title,
            author: video.author,
            durationSeconds: video.duration?.inSeconds ?? 0,
            thumbnailUrl: _highQualityThumbnail(video.id.value),
            index: i,
          ),
        );
      }
      return tracks;
    } catch (e) {
      dev.log('Podcast fallback search failed: $e', name: 'YoutubeRemoteDataSource');
      return [];
    }
  }

  /// Returns the highest-quality YouTube thumbnail URL for a given video ID.
  /// Uses maxresdefault (1280×720) which is the best YouTube offers.
  String _highQualityThumbnail(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
  }

  String _addGeoBypassParams(String url) {
    try {
      final uri = Uri.parse(url);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams['hl'] = 'en';
      queryParams['gl'] = 'US';
      queryParams['alr'] = 'yes';
      return uri.replace(queryParameters: queryParams).toString();
    } catch (e) {
      return url;
    }
  }

  Future<List<TrackModel>> getRecommendations(
    String videoId, {
    int limit = 20,
  }) async {
    try {
      final upNext = await _ytMusic.getUpNexts(videoId).timeout(_timeout);
      final tracks = upNext
          .where((item) => item.videoId.isNotEmpty)
          .take(limit)
          .map(_trackFromUpNext)
          .toList();
      if (tracks.isNotEmpty) return _withIndexes(tracks);
    } catch (e) {
      dev.log(
        'YouTube Music up next failed for $videoId, using related videos: $e',
        name: 'YoutubeRemoteDataSource',
      );
    }

    final video = await _yt.videos.get(videoId).timeout(_timeout);
    final related = await _yt.videos.getRelatedVideos(video).timeout(_timeout);
    if (related == null || related.isEmpty) return <TrackModel>[];

    final tracks = <TrackModel>[];
    for (final recommendation in related) {
      if (tracks.length >= limit) break;
      tracks.add(
        TrackModel(
          id: recommendation.id.value,
          title: recommendation.title,
          author: recommendation.author,
          durationSeconds: recommendation.duration?.inSeconds ?? 0,
          thumbnailUrl: _highQualityThumbnail(recommendation.id.value),
          index: tracks.length,
        ),
      );
    }
    return tracks;
  }

  Future<String> getVideoUrl(
    String videoId, {
    String quality = 'low',
  }) async {
    final manifest = await _yt.videos.streams
        .getManifest(videoId)
        .timeout(_timeout);
    final hlsMuxed = manifest.hls.whereType<HlsMuxedStreamInfo>().toList();
    if (hlsMuxed.isNotEmpty) {
      final best = _selectByQuality(hlsMuxed, quality);
      return _addGeoBypassParams(best.url.toString());
    }

    final iosFriendlyMuxed = manifest.muxed
        .where(
          (stream) =>
              stream.container == StreamContainer.mp4 &&
              stream.videoCodec.toLowerCase().contains('avc') &&
              stream.audioCodec.toLowerCase().contains('mp4a'),
        )
        .toList();
    if (iosFriendlyMuxed.isNotEmpty) {
      final best = _selectByQuality(iosFriendlyMuxed, quality);
      return _addGeoBypassParams(best.url.toString());
    }

    final mp4Muxed = manifest.muxed
        .where((stream) => stream.container == StreamContainer.mp4)
        .toList();
    if (mp4Muxed.isNotEmpty) {
      final best = _selectByQuality(mp4Muxed, quality);
      return _addGeoBypassParams(best.url.toString());
    }

    final fallbackMuxed = manifest.muxed.toList();
    if (fallbackMuxed.isEmpty) {
      throw Exception('No playable video streams available for video $videoId');
    }
    final best = _selectByQuality(fallbackMuxed, quality);
    return _addGeoBypassParams(best.url.toString());
  }

  Future<String> getAudioUrl(
    String videoId, {
    String quality = 'low',
  }) async {
    var attempt = 0;
    final stopwatch = Stopwatch()..start();
    while (true) {
      try {
        final manifest = await _yt.videos.streams
            .getManifest(videoId)
            .timeout(_timeout);

        final muxed = manifest.muxed;
        if (muxed.isNotEmpty) {
          final best = _selectByQuality(muxed, quality);
          return _addGeoBypassParams(best.url.toString());
        }

        final audioStreams = manifest.audioOnly.toList();
        if (audioStreams.isEmpty) {
          throw Exception('No audio streams available for video $videoId');
        }
        var candidates = audioStreams
            .where((s) =>
                s.container == StreamContainer.mp4 ||
                s.container == StreamContainer.webM)
            .toList();
        if (candidates.isEmpty) {
          candidates = audioStreams;
        }
        final bestAudio = _selectByQuality(candidates, quality);
        return _addGeoBypassParams(bestAudio.url.toString());
      } on TimeoutException {
        attempt++;
        dev.log('Attempt $attempt timed out for video $videoId',
            name: 'YoutubeRemoteDataSource');
        if (attempt >= 3 || stopwatch.elapsed > const Duration(seconds: 45)) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * attempt));
      } on Exception catch (e) {
        attempt++;
        final msg = e.toString();
        if (attempt >= 3 || stopwatch.elapsed > const Duration(seconds: 45)) {
          dev.log('All $attempt attempts failed for video $videoId: $msg',
              name: 'YoutubeRemoteDataSource');
          rethrow;
        }
        if (msg.contains('requestLimit') || msg.contains('429')) {
          dev.log('Rate limited on attempt $attempt for video $videoId',
              name: 'YoutubeRemoteDataSource');
          await Future.delayed(Duration(seconds: 2 * attempt));
        } else {
          dev.log('Non-retryable error on attempt $attempt for video $videoId: $msg',
              name: 'YoutubeRemoteDataSource');
          rethrow;
        }
      }
    }
  }

  AudioStreamInfo _selectByQuality(List<AudioStreamInfo> streams, String quality) {
    final sorted = List<AudioStreamInfo>.from(streams)
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
    switch (quality) {
      case 'low':
        return sorted.first;
      case 'high':
        return sorted.last;
      case 'medium':
      default:
        return sorted[sorted.length ~/ 2];
    }
  }

  Future<List<TrackModel>> getRelatedVideos(String videoId,
      {int maxResults = 20}) async {
    final video = await _yt.videos.get(videoId);
    final related = await _yt.videos.getRelatedVideos(video);
    final videos = related?.take(maxResults).toList() ?? [];
    final tracks = <TrackModel>[];
    for (var i = 0; i < results.length; i++) {
      final video = results[i];
      tracks.add(
        TrackModel(
          id: video.id.value,
          title: video.title,
          author: video.author,
          durationSeconds: video.duration?.inSeconds ?? 0,
          thumbnailUrl: _highQualityThumbnail(video.id.value),
          index: i,
        ),
      );
    }
    return tracks;
  }

  List<TrackModel> _withIndexes(List<TrackModel> tracks) {
    return [
      for (var i = 0; i < tracks.length; i++)
        TrackModel(
          id: tracks[i].id,
          title: tracks[i].title,
          author: tracks[i].author,
          durationSeconds: tracks[i].durationSeconds,
          thumbnailUrl: tracks[i].thumbnailUrl,
          index: i,
        ),
    ];
  }

  TrackModel _trackFromSong(ytmusic.SongDetailed song, int index) {
    return TrackModel(
      id: song.videoId,
      title: song.name,
      author: song.artist.name,
      durationSeconds: song.duration ?? 0,
      thumbnailUrl: _highQualityThumbnail(song.videoId),
      index: index,
      albumId: song.album?.albumId,
      artistId: song.artist.artistId,
    );
  }

  TrackModel _trackFromVideo(ytmusic.VideoDetailed video, int index) {
    return TrackModel(
      id: video.videoId,
      title: video.name,
      author: video.artist.name,
      durationSeconds: video.duration ?? 0,
      thumbnailUrl: _highQualityThumbnail(video.videoId),
      index: index,
      artistId: video.artist.artistId,
    );
  }

  TrackModel _trackFromUpNext(ytmusic.UpNextsDetails item) {
    return TrackModel(
      id: item.videoId,
      title: item.title,
      author: item.artists.name,
      durationSeconds: item.duration,
      thumbnailUrl: _highQualityThumbnail(item.videoId),
      index: 0,
    );
  }

  String? _bestThumbnail(List<ytmusic.ThumbnailFull> thumbnails) {
    if (thumbnails.isEmpty) return null;
    final sorted = List<ytmusic.ThumbnailFull>.from(thumbnails)
      ..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
    return sorted.last.url;
  }

  Future<CategorizedSearchResults> searchAll(String query) async {
    try {
      final resultsList = await Future.wait([
        _ytMusic.searchSongs(query).timeout(_timeout),
        _ytMusic.searchVideos(query).timeout(_timeout),
        _ytMusic.searchAlbums(query).timeout(_timeout),
        _ytMusic.searchArtists(query).timeout(_timeout),
        _ytMusic.searchPlaylists(query).timeout(_timeout),
      ]);

      final songs = <TrackModel>[];
      final videos = <TrackModel>[];
      final albums = <AlbumResult>[];
      final artists = <ArtistResult>[];
      final playlists = <PlaylistResult>[];

      for (final song in resultsList[0]) {
        if (song is ytmusic.SongDetailed) {
          songs.add(_trackFromSong(song, songs.length));
        }
      }

      for (final video in resultsList[1]) {
        if (video is ytmusic.VideoDetailed) {
          videos.add(_trackFromVideo(video, videos.length));
        }
      }

      for (final album in resultsList[2]) {
        if (album is ytmusic.AlbumDetailed) {
          albums.add(
            AlbumResult(
              id: album.albumId,
              title: album.name,
              artist: album.artist.name,
              artistId: album.artist.artistId,
              year: album.year,
              thumbnailUrl: _bestThumbnail(album.thumbnails),
            ),
          );
        }
      }

      for (final artist in resultsList[3]) {
        if (artist is ytmusic.ArtistDetailed) {
          artists.add(
            ArtistResult(
              id: artist.artistId,
              name: artist.name,
              thumbnailUrl: _bestThumbnail(artist.thumbnails),
            ),
          );
        }
      }

      for (final playlist in resultsList[4]) {
        if (playlist is ytmusic.PlaylistDetailed) {
          playlists.add(
            PlaylistResult(
              id: playlist.playlistId,
              title: playlist.name,
              artist: playlist.artist.name,
              thumbnailUrl: _bestThumbnail(playlist.thumbnails),
            ),
          );
        }
      }

      return CategorizedSearchResults(
        songs: songs.map((m) => m.toEntity()).toList(),
        videos: videos.map((m) => m.toEntity()).toList(),
        albums: albums,
        artists: artists,
        playlists: playlists,
      );
    } catch (e) {
      dev.log(
        'Categorized search failed for "$query": $e',
        name: 'YoutubeRemoteDataSource',
      );
      return const CategorizedSearchResults();
    }
  }

  Future<AlbumDetailResult> getAlbum(String albumId) async {
    final album = await _ytMusic.getAlbum(albumId).timeout(_timeout);
    final tracks = <TrackModel>[];
    for (var i = 0; i < album.songs.length; i++) {
      final song = album.songs[i];
      tracks.add(_trackFromSong(song, i));
    }
    return AlbumDetailResult(
      id: album.playlistId,
      title: album.name,
      artist: album.artist.name,
      artistId: album.artist.artistId,
      year: album.year,
      thumbnailUrl: _bestThumbnail(album.thumbnails),
      tracks: tracks.map((m) => m.toEntity()).toList(),
    );
  }

  Future<ArtistDetailResult> getArtist(String artistId) async {
    final artist = await _ytMusic.getArtist(artistId).timeout(_timeout);
    final topSongs = <TrackModel>[];
    for (var i = 0; i < artist.topSongs.length; i++) {
      topSongs.add(_trackFromSong(artist.topSongs[i], i));
    }
    final albums = <AlbumResult>[];
    for (final album in artist.topAlbums) {
      albums.add(
        AlbumResult(
          id: album.albumId,
          title: album.name,
          artist: artist.name,
          artistId: artistId,
          year: album.year,
          thumbnailUrl: _bestThumbnail(album.thumbnails),
        ),
      );
    }
    final singles = <AlbumResult>[];
    for (final single in artist.topSingles) {
      singles.add(
        AlbumResult(
          id: single.albumId,
          title: single.name,
          artist: artist.name,
          artistId: artistId,
          year: single.year,
          thumbnailUrl: _bestThumbnail(single.thumbnails),
        ),
      );
    }
    return ArtistDetailResult(
      id: artist.artistId,
      name: artist.name,
      thumbnailUrl: _bestThumbnail(artist.thumbnails),
      topSongs: topSongs.map((m) => m.toEntity()).toList(),
      albums: albums,
      singles: singles,
    );
  }

  void dispose() {
    _yt.close();
  }
}
