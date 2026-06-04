import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytmusix/domain/entities/playlist.dart';
import 'package:ytmusix/domain/entities/search_result_models.dart';
import 'package:ytmusix/domain/entities/video.dart';
import 'package:ytmusix/domain/repositories/playlist_repository.dart';
import 'package:ytmusix/presentation/providers/playlist_provider.dart';

void main() {
  test('silent search uses cached results for repeated queries', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakePlaylistRepository();
    final provider = PlaylistProvider(repository);

    final first = await provider.searchSilently('Asake Intro official audio');
    final second = await provider.searchSilently(
      '  asake   intro official audio ',
    );

    expect(repository.searchCount, 1);
    expect(first.single.id, 'track_1');
    expect(second.single.id, 'track_1');
  });
}

class _FakePlaylistRepository implements PlaylistRepository {
  int searchCount = 0;

  @override
  Future<List<Track>> search(String query) async {
    searchCount++;
    return [
      Track(
        id: 'track_$searchCount',
        title: query,
        author: 'Asake',
        duration: const Duration(minutes: 3),
      ),
    ];
  }

  @override
  Future<List<Track>> getPodcastFeed() async => const [];

  @override
  Future<void> deletePlaylist(String playlistId) async {}

  @override
  Future<List<Track>> getCachedTracks(String playlistId) async => const [];

  @override
  Future<Playlist?> getCachedPlaylist(String playlistId) async => null;

  @override
  Future<List<Track>> getFavoriteTracks() async => const [];

  @override
  Future<Set<String>> getFavoriteIds() async => const {};

  @override
  Future<Playlist> getFromUrl(String input) async {
    throw UnimplementedError();
  }

  @override
  Future<Playlist> getPlaylist(String playlistId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Playlist>> getSavedPlaylists() async => const [];

  @override
  Future<bool> isFavorite(String trackId) async => false;

  @override
  Future<void> removeTrack(String playlistId, String trackId) async {}

  @override
  Future<void> reorderTracks(
    String playlistId,
    List<String> trackIdsInOrder,
  ) async {}

  @override
  Future<void> savePlaylist(Playlist playlist) async {}

  @override
  Future<void> saveTrack(String playlistId, Track track) async {}

  @override
  Future<void> toggleFavorite(Track track) async {}

  @override
  Future<void> updatePlaylistTitle(String id, String newTitle) async {}

  @override
  Future<CategorizedSearchResults> searchAll(String query) async =>
      const CategorizedSearchResults();

  @override
  Future<AlbumDetailResult> getAlbum(String playlistId) async =>
      throw UnimplementedError();

  @override
  Future<ArtistDetailResult> getArtist(String artistId) async =>
      throw UnimplementedError();

  @override
  Future<void> toggleFavoriteCollection(Playlist playlist, String type) async {}

  @override
  Future<bool> isCollectionFavorite(String collectionId) async => false;

  @override
  Future<Set<String>> getFavoriteCollectionIds() async => const {};

  @override
  Future<List<Playlist>> getFavoriteCollections() async => const [];
}
