import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/datasources/local/playlist_database.dart';
import '../data/datasources/remote/youtube_remote_datasource.dart';
import '../domain/entities/playlist.dart';
import '../domain/entities/video.dart';
import 'auth_service.dart';

class DownloadProgress {
  final String trackId;
  final String trackTitle;
  final int currentBytes;
  final int totalBytes;
  final int tracksCompleted;
  final int totalTracks;

  DownloadProgress({
    required this.trackId,
    required this.trackTitle,
    required this.currentBytes,
    required this.totalBytes,
    this.tracksCompleted = 0,
    this.totalTracks = 0,
  });

  double get fraction => totalBytes > 0 ? currentBytes / totalBytes : 0.0;
}

class DownloadService {
  late final YoutubeRemoteDataSource _remoteDataSource;
  late final PlaylistDatabase _database;
  final AuthService _authService = AuthService();
  final http.Client _client = http.Client();

  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _completedController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;
  Stream<String> get completedStream => _completedController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool _cancelled = false;

  DownloadService({
    required YoutubeRemoteDataSource remoteDataSource,
    required PlaylistDatabase database,
  }) {
    _remoteDataSource = remoteDataSource;
    _database = database;
  }

  DownloadService.test() {
    // Test subclasses override all methods that use these fields.
  }

  Future<String> _getDownloadDir(String playlistId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'downloads', playlistId));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<void> downloadTrack(
    Track track,
    String playlistId, {
    String quality = 'medium',
  }) async {
    if (await isTrackDownloaded(track.id)) return;
    final dir = await _getDownloadDir(playlistId);
    final filePath = p.join(dir, '${track.id}.mp4');

    try {
      final headers = await _getHeaders();
      final audioUrl = await _remoteDataSource.getAudioUrl(
        track.id,
        quality: quality,
      );
      await _downloadFile(audioUrl, filePath, track, 0, 1, headers: headers);
      await _database.markTrackDownloaded(
        track.id,
        playlistId,
        filePath,
        title: track.title,
        thumbnailUrl: track.thumbnailUrl,
        durationSeconds: track.duration.inSeconds,
        author: track.author,
      );
      _completedController.add(track.id);
    } catch (e) {
      _errorController.add('Failed to download ${track.title}: $e');
      _progressController.add(
        DownloadProgress(
          trackId: track.id,
          trackTitle: track.title,
          currentBytes: 0,
          totalBytes: 0,
          tracksCompleted: 0,
          totalTracks: 1,
        ),
      );
    }
  }

  Future<void> downloadPlaylist(
    Playlist playlist, {
    String quality = 'medium',
  }) async {
    _cancelled = false;
    final dir = await _getDownloadDir(playlist.id);
    final tracks = playlist.tracks;
    final total = tracks.length;

    for (var i = 0; i < total; i++) {
      if (_cancelled) break;
      final track = tracks[i];
      final filePath = p.join(dir, '${track.id}.mp4');

      if (await isTrackDownloaded(track.id)) continue;

      try {
        final headers = await _getHeaders();
        final audioUrl = await _remoteDataSource.getAudioUrl(
          track.id,
          quality: quality,
        );
        await _downloadFile(
          audioUrl,
          filePath,
          track,
          i,
          total,
          headers: headers,
        );
        await _database.markTrackDownloaded(
          track.id,
          playlist.id,
          filePath,
          title: track.title,
          thumbnailUrl: track.thumbnailUrl,
          durationSeconds: track.duration.inSeconds,
          author: track.author,
        );
        _completedController.add(track.id);
      } catch (e) {
        _errorController.add('Failed to download ${track.title}: $e');
        _progressController.add(
          DownloadProgress(
            trackId: track.id,
            trackTitle: track.title,
            currentBytes: 0,
            totalBytes: 0,
            tracksCompleted: i,
            totalTracks: total,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(
    String url,
    String filePath,
    dynamic track,
    int trackIndex,
    int total, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    if (headers != null) request.headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain();
      throw HttpException(
        'Audio download failed with HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }
    final contentLength = response.contentLength ?? 0;
    final file = File(filePath);
    final tempFile = File('$filePath.part');
    final sink = tempFile.openWrite();
    var received = 0;

    await for (final chunk in response.stream) {
      if (_cancelled) {
        await sink.close();
        if (tempFile.existsSync()) await tempFile.delete();
        return;
      }
      sink.add(chunk);
      received += chunk.length;
      _progressController.add(
        DownloadProgress(
          trackId: track.id,
          trackTitle: track.title,
          currentBytes: received,
          totalBytes: contentLength,
          tracksCompleted: trackIndex,
          totalTracks: total,
        ),
      );
    }
    await sink.close();
    if (received == 0) {
      if (tempFile.existsSync()) await tempFile.delete();
      throw const FileSystemException('Downloaded audio file is empty');
    }
    if (file.existsSync()) await file.delete();
    await tempFile.rename(filePath);
  }

  void cancelDownload() {
    _cancelled = true;
  }

  Future<bool> isTrackDownloaded(String trackId) async {
    final path = await _database.getDownloadedFilePath(trackId);
    if (path == null) return false;
    if (File(path).existsSync()) return true;
    await _database.removeDownloadedTrack(trackId);
    return false;
  }

  Future<String?> getLocalFilePath(String trackId) async {
    final path = await _database.getDownloadedFilePath(trackId);
    if (path == null) return null;
    if (File(path).existsSync()) return path;
    await _database.removeDownloadedTrack(trackId);
    return null;
  }

  Future<Set<String>> getAllDownloadedIds() async {
    final ids = await _database.getAllDownloadedTrackIds();
    final existing = <String>{};
    for (final id in ids) {
      if (await isTrackDownloaded(id)) {
        existing.add(id);
      }
    }
    return existing;
  }

  Future<Set<String>> getFullyDownloadedPlaylistIds() async {
    await _pruneMissingDownloads();
    return _database.getFullyDownloadedPlaylistIds();
  }

  Future<void> deleteDownloadedPlaylist(String playlistId) async {
    final paths = await _database.getDownloadedFilePaths(playlistId);
    for (final path in paths) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    await _database.removeDownloadedPlaylist(playlistId);
  }

  Future<int> getTotalCacheSize() async {
    await _pruneMissingDownloads();
    final tracks = await _database.getAllDownloadedTrackIds();
    var total = 0;
    for (final id in tracks) {
      final path = await _database.getDownloadedFilePath(id);
      if (path != null) {
        try {
          total += File(path).lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int> getPlaylistCacheSize(String playlistId) async {
    await _pruneMissingDownloads();
    final paths = await _database.getDownloadedFilePaths(playlistId);
    var total = 0;
    for (final path in paths) {
      try {
        total += File(path).lengthSync();
      } catch (_) {}
    }
    return total;
  }

  Future<void> _pruneMissingDownloads() async {
    final ids = await _database.getAllDownloadedTrackIds();
    for (final id in ids) {
      final path = await _database.getDownloadedFilePath(id);
      if (path == null || !File(path).existsSync()) {
        await _database.removeDownloadedTrack(id);
      }
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final cookies = await _authService.getCookies();
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Referer': 'https://www.youtube.com/',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }
    return headers;
  }

  Future<List<Track>> getAllDownloadedTracks() async {
    await _pruneMissingDownloads();
    final models = await _database.getAllDownloadedTracks();
    return models.map((m) => m.toEntity()).toList();
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    final path = await _database.getDownloadedFilePath(trackId);
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    await _database.removeDownloadedTrack(trackId);
  }

  void dispose() {
    _client.close();
    _progressController.close();
    _completedController.close();
    _errorController.close();
  }
}
