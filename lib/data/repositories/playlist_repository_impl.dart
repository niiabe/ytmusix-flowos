import '../../domain/entities/playlist.dart';
import '../../domain/entities/search_result_models.dart';
import '../../domain/entities/video.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/local/playlist_database.dart';
import '../datasources/remote/youtube_remote_datasource.dart';
import '../models/playlist_model.dart';
import '../models/video_model.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final YoutubeRemoteDataSource remoteDataSource;
  final PlaylistDatabase localDatabase;

  PlaylistRepositoryImpl({
    required this.remoteDataSource,
    required this.localDatabase,
  });

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    final playlistModel = await remoteDataSource.getPlaylist(playlistId);
    await localDatabase.insertPlaylist(playlistModel);
    final trackModels = playlistModel.tracks;
    await localDatabase.insertTracks(playlistId, trackModels);
    return playlistModel.toEntity();
  }

  @override
  Future<Playlist> getFromUrl(String input) async {
    final trimmed = input.trim();

    final videoId = _parseVideoId(trimmed);
    final playlistId = _parsePlaylistId(trimmed);

    if (playlistId != null) {
      final playlist = await remoteDataSource.getPlaylist(playlistId);
      await localDatabase.insertPlaylist(playlist);
      await localDatabase.insertTracks(playlist.id, playlist.tracks);
      return playlist.toEntity();
    }

    if (videoId != null) {
      final track = await remoteDataSource.getVideo(videoId);
      final playlist = Playlist(
        id: videoId,
        title: track.title,
        author: track.author,
        thumbnailUrl: track.thumbnailUrl,
        videoCount: 1,
        tracks: [track.toEntity()],
      );
      await localDatabase.insertPlaylist(
        PlaylistModel(
          id: playlist.id,
          title: playlist.title,
          thumbnailUrl: playlist.thumbnailUrl,
          author: playlist.author,
          videoCount: 1,
        ),
      );
      await localDatabase.insertTrack(
        playlist.id,
        TrackModel(
          id: track.id,
          title: track.title,
          thumbnailUrl: track.thumbnailUrl,
          durationSeconds: track.durationSeconds,
          author: track.author,
          index: 0,
        ),
      );
      return playlist;
    }

    throw Exception('Could not parse YouTube URL or ID: $input');
  }

  String? _parseVideoId(String input) {
    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?.*v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtu\.be/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com/shorts/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:m\.youtube\.com/watch\?.*v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'^([a-zA-Z0-9_-]{11})$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _parsePlaylistId(String input) {
    final patterns = [
      RegExp(r'(?:list=)([a-zA-Z0-9_-]+)'),
      RegExp(r'^([a-zA-Z0-9_-]{13,})$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) return match.group(1);
    }
    return null;
  }

  @override
  Future<List<Playlist>> getSavedPlaylists() async {
    final models = await localDatabase.getAllPlaylists();
    final playlists = <Playlist>[];
    for (final model in models) {
      final tracks = await getCachedTracks(model.id);
      playlists.add(
        Playlist(
          id: model.id,
          title: model.title,
          description: model.description,
          thumbnailUrl: model.thumbnailUrl,
          author: model.author,
          videoCount: model.videoCount,
          tracks: tracks,
        ),
      );
    }
    return playlists;
  }

  @override
  Future<void> savePlaylist(Playlist playlist) async {
    await localDatabase.insertPlaylist(
      PlaylistModel(
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: playlist.thumbnailUrl,
        author: playlist.author,
        videoCount: playlist.tracks.length,
      ),
    );
    await localDatabase.insertTracks(
      playlist.id,
      playlist.tracks
          .map(
            (t) => TrackModel(
              id: t.id,
              title: t.title,
              thumbnailUrl: t.thumbnailUrl,
              durationSeconds: t.duration.inSeconds,
              author: t.author,
              index: t.index,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await localDatabase.deletePlaylist(playlistId);
  }

  @override
  Future<void> saveTrack(String playlistId, Track track) async {
    await localDatabase.insertTrack(
      playlistId,
      TrackModel(
        id: track.id,
        title: track.title,
        thumbnailUrl: track.thumbnailUrl,
        durationSeconds: track.duration.inSeconds,
        author: track.author,
        index: track.index,
      ),
    );
  }

  @override
  Future<void> updatePlaylistTitle(String id, String newTitle) async {
    await localDatabase.updatePlaylistTitle(id, newTitle);
  }

  @override
  Future<void> removeTrack(String playlistId, String trackId) async {
    await localDatabase.removeTrack(playlistId, trackId);
  }

  @override
  Future<void> reorderTracks(
    String playlistId,
    List<String> trackIdsInOrder,
  ) async {
    await localDatabase.reorderTracks(playlistId, trackIdsInOrder);
  }

  @override
  Future<void> toggleFavorite(Track track) async {
    await localDatabase.toggleFavoriteTrack(
      TrackModel(
        id: track.id,
        title: track.title,
        thumbnailUrl: track.thumbnailUrl,
        durationSeconds: track.duration.inSeconds,
        author: track.author,
        index: track.index,
      ),
    );
  }

  @override
  Future<bool> isFavorite(String trackId) async {
    return localDatabase.isTrackFavorite(trackId);
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    return localDatabase.getFavoriteTrackIds();
  }

  @override
  Future<List<Track>> getFavoriteTracks() async {
    final models = await localDatabase.getFavoriteTracks();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Track>> search(String query) async {
    final models = await remoteDataSource.search(query);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Track>> getPodcastFeed() async {
    final models = await remoteDataSource.getHashtagPodcasts();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Track>> getCachedTracks(String playlistId) async {
    final models = await localDatabase.getTracks(playlistId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Playlist?> getCachedPlaylist(String playlistId) async {
    final playlists = await localDatabase.getAllPlaylists();
    final match = playlists.where((p) => p.id == playlistId).firstOrNull;
    if (match == null) return null;
    final tracks = await getCachedTracks(playlistId);
    return Playlist(
      id: match.id,
      title: match.title,
      description: match.description,
      thumbnailUrl: match.thumbnailUrl,
      author: match.author,
      videoCount: match.videoCount,
      tracks: tracks,
    );
  }

  @override
  Future<CategorizedSearchResults> searchAll(String query) async {
    return remoteDataSource.searchAll(query);
  }

  @override
  Future<AlbumDetailResult> getAlbum(String playlistId) async {
    return remoteDataSource.getAlbum(playlistId);
  }

  @override
  Future<ArtistDetailResult> getArtist(String artistId) async {
    return remoteDataSource.getArtist(artistId);
  }

  @override
  Future<void> toggleFavoriteCollection(Playlist playlist, String type) async {
    await localDatabase.toggleFavoriteCollection(
      PlaylistModel(
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: playlist.thumbnailUrl,
        author: playlist.author,
        videoCount: playlist.videoCount,
      ),
      type,
    );
  }

  @override
  Future<bool> isCollectionFavorite(String collectionId) async {
    return localDatabase.isCollectionFavorite(collectionId);
  }

  @override
  Future<Set<String>> getFavoriteCollectionIds() async {
    return localDatabase.getFavoriteCollectionIds();
  }

  @override
  Future<List<Playlist>> getFavoriteCollections() async {
    final models = await localDatabase.getFavoriteCollections();
    return models.map((m) => m.toEntity()).toList();
  }
}
