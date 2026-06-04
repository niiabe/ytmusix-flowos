import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/video.dart';
import '../../service/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService;

  DownloadProvider(this._downloadService);

  Set<String> _downloadedTrackIds = {};
  final Map<String, DownloadProgress> _activeDownloads = {};
  final Set<String> _downloadingPlaylists = {};
  final Set<String> _downloadedPlaylists = {};
  final Map<String, double> _playlistDownloadProgress = {};
  List<Track> _downloadedTracks = [];

  Set<String> get downloadedTrackIds => _downloadedTrackIds;
  Map<String, DownloadProgress> get activeDownloads => _activeDownloads;
  Set<String> get downloadingPlaylists => _downloadingPlaylists;
  Set<String> get downloadedPlaylists => _downloadedPlaylists;
  Map<String, double> get playlistDownloadProgress => _playlistDownloadProgress;
  List<Track> get downloadedTracks => _downloadedTracks;

  StreamSubscription? _progressSub;
  StreamSubscription? _completedSub;

  bool isDownloadingPlaylist(String playlistId) =>
      _downloadingPlaylists.contains(playlistId);

  bool isPlaylistFullyDownloaded(String playlistId) =>
      _downloadedPlaylists.contains(playlistId);

  double? getPlaylistDownloadProgress(String playlistId) =>
      _playlistDownloadProgress[playlistId];

  DownloadProgress? getProgress(String trackId) => _activeDownloads[trackId];

  Future<void> init() async {
    _downloadedTrackIds = await _downloadService.getAllDownloadedIds();
    _downloadedPlaylists.addAll(
      await _downloadService.getFullyDownloadedPlaylistIds(),
    );
    await loadDownloadedTracks();
  }

  Future<void> downloadPlaylist(
    Playlist playlist, {
    String quality = 'medium',
  }) async {
    if (_downloadingPlaylists.contains(playlist.id)) return;

    _downloadingPlaylists.add(playlist.id);
    _playlistDownloadProgress[playlist.id] = 0.0;
    notifyListeners();

    _progressSub?.cancel();
    _completedSub?.cancel();

    _progressSub = _downloadService.progressStream.listen((progress) {
      _activeDownloads[progress.trackId] = progress;
      if (progress.totalTracks > 0) {
        _playlistDownloadProgress[playlist.id] =
            (progress.tracksCompleted + progress.fraction) /
            progress.totalTracks;
      }
      notifyListeners();
    });

    _completedSub = _downloadService.completedStream.listen((trackId) {
      _downloadedTrackIds.add(trackId);
      _activeDownloads.remove(trackId);
      notifyListeners();
    });

    await _downloadService.downloadPlaylist(playlist, quality: quality);

    _downloadingPlaylists.remove(playlist.id);
    _playlistDownloadProgress.remove(playlist.id);
    await _refreshDownloadedIds();
    await _refreshDownloadedPlaylists();
    final allDownloaded = playlist.tracks.every(
      (t) => _downloadedTrackIds.contains(t.id),
    );
    if (allDownloaded) {
      _downloadedPlaylists.add(playlist.id);
    }
    _activeDownloads.clear();
    _progressSub?.cancel();
    _completedSub?.cancel();
    notifyListeners();
  }

  Future<void> downloadTrack(
    Track track,
    String playlistId, {
    String quality = 'medium',
  }) async {
    if (_downloadedTrackIds.contains(track.id)) return;
    if (_activeDownloads.containsKey(track.id)) return;
    _activeDownloads[track.id] = DownloadProgress(
      trackId: track.id,
      trackTitle: track.title,
      currentBytes: 0,
      totalBytes: 0,
      tracksCompleted: 0,
      totalTracks: 1,
    );
    notifyListeners();
    await _downloadService.downloadTrack(track, playlistId, quality: quality);
    _activeDownloads.remove(track.id);
    await _refreshDownloadedIds();
    await _refreshDownloadedPlaylists();
    notifyListeners();
  }

  Future<void> preDownloadUpcoming(
    List<Track> queue,
    int currentIndex,
    String playlistId, {
    int prebufferCount = 2,
    String quality = 'low',
  }) async {
    if (queue.isEmpty) return;
    final start = (currentIndex + 1).clamp(0, queue.length);
    final end = (start + prebufferCount).clamp(0, queue.length);
    final futures = <Future<void>>[];
    for (var i = start; i < end; i++) {
      final track = queue[i];
      if (_downloadedTrackIds.contains(track.id)) continue;
      if (_activeDownloads.containsKey(track.id)) continue;
      futures.add(
        _downloadService
            .downloadTrack(track, playlistId, quality: quality)
            .then((_) {
              _downloadedTrackIds.add(track.id);
            })
            .catchError((e) {
              dev.log(
                'Pre-download failed for ${track.id}: $e',
                name: 'DownloadProvider',
              );
            }),
      );
    }
    await Future.wait(futures);
    await _refreshDownloadedPlaylists();
    notifyListeners();
  }

  void cancelDownload() {
    _downloadService.cancelDownload();
    _downloadingPlaylists.clear();
    _activeDownloads.clear();
    _playlistDownloadProgress.clear();
    notifyListeners();
  }

  Future<bool> isTrackDownloaded(String trackId) async {
    return _downloadService.isTrackDownloaded(trackId);
  }

  Future<String?> getLocalFilePath(String trackId) async {
    return _downloadService.getLocalFilePath(trackId);
  }

  Future<void> deleteDownloadedPlaylist(String playlistId) async {
    await _downloadService.deleteDownloadedPlaylist(playlistId);
    await _refreshDownloadedIds();
    await _refreshDownloadedPlaylists();
    notifyListeners();
  }

  Future<int> getTotalCacheSize() => _downloadService.getTotalCacheSize();

  Future<int> getPlaylistCacheSize(String playlistId) =>
      _downloadService.getPlaylistCacheSize(playlistId);

  Future<void> _refreshDownloadedIds() async {
    _downloadedTrackIds = await _downloadService.getAllDownloadedIds();
  }

  Future<void> _refreshDownloadedPlaylists() async {
    _downloadedPlaylists
      ..clear()
      ..addAll(await _downloadService.getFullyDownloadedPlaylistIds());
  }

  Future<void> loadDownloadedTracks() async {
    _downloadedTracks = await _downloadService.getAllDownloadedTracks();
    notifyListeners();
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    await _downloadService.deleteDownloadedTrack(trackId);
    await _refreshDownloadedIds();
    await loadDownloadedTracks();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _completedSub?.cancel();
    _activeDownloads.clear();
    _downloadingPlaylists.clear();
    _playlistDownloadProgress.clear();
    _downloadService.dispose();
    super.dispose();
  }
}
