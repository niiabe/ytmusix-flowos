import '../entities/playlist.dart';
import '../entities/search_result_models.dart';
import '../entities/video.dart';

abstract class PlaylistRepository {
  Future<Playlist> getPlaylist(String playlistId);
  Future<Playlist> getFromUrl(String input);
  Future<List<Playlist>> getSavedPlaylists();
  Future<void> savePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String playlistId);
  Future<void> saveTrack(String playlistId, Track track);
  Future<List<Track>> getCachedTracks(String playlistId);
  Future<Playlist?> getCachedPlaylist(String playlistId);
  Future<List<Track>> search(String query);
  Future<List<Track>> getPodcastFeed();
  Future<CategorizedSearchResults> searchAll(String query);
  Future<AlbumDetailResult> getAlbum(String playlistId);
  Future<ArtistDetailResult> getArtist(String artistId);
  Future<void> toggleFavorite(Track track);
  Future<bool> isFavorite(String trackId);
  Future<Set<String>> getFavoriteIds();
  Future<List<Track>> getFavoriteTracks();
  Future<void> updatePlaylistTitle(String id, String newTitle);
  Future<void> removeTrack(String playlistId, String trackId);
  Future<void> reorderTracks(String playlistId, List<String> trackIdsInOrder);
  Future<void> toggleFavoriteCollection(Playlist playlist, String type);
  Future<bool> isCollectionFavorite(String collectionId);
  Future<Set<String>> getFavoriteCollectionIds();
  Future<List<Playlist>> getFavoriteCollections();
}
