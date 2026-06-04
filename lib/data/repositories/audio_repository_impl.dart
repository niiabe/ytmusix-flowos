import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/video.dart';
import '../../domain/repositories/audio_repository.dart';
import '../datasources/remote/youtube_remote_datasource.dart';
import '../datasources/local/playlist_database.dart';
import '../../service/audio_handler.dart';

class AudioRepositoryImpl implements AudioRepository {
  final YoutubeRemoteDataSource remoteDataSource;
  final MusicAudioHandler _handler;
  final PlaylistDatabase _database;

  AudioRepositoryImpl({
    required this.remoteDataSource,
    required this._handler,
    required this._database,
  });

  @override
  Future<String> getAudioUrl(Track track, {String quality = 'low'}) async {
    final localPath = await _database.getDownloadedFilePath(track.id);
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    if (localPath != null) {
      await _database.removeDownloadedTrack(track.id);
    }
    return remoteDataSource.getAudioUrl(track.id, quality: quality);
  }

  @override
  Future<String> getVideoUrl(Track track, {String quality = 'low'}) {
    return remoteDataSource.getVideoUrl(track.id, quality: quality);
  }

  @override
  Future<List<Track>> getRecommendations(Track seed, {int limit = 20}) async {
    final recommendations = await remoteDataSource.getRecommendations(
      seed.id,
      limit: limit,
    );
    return recommendations.map((track) => track.toEntity()).toList();
  }

  @override
  Future<void> playTrack(Track track, String audioUrl) async {
    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.author ?? '',
      artUri: track.thumbnailUrl != null
          ? Uri.tryParse(track.thumbnailUrl!)
          : null,
      duration: track.duration,
    );

    final queue = _handler.queue.value;
    if (queue.isNotEmpty && queue.any((e) => e.id == track.id)) {
      _handler.mediaItem.add(item);
      await _handler.playTrack(audioUrl, item);
    } else {
      final newQueue = List<MediaItem>.from(queue);
      newQueue.add(item);
      _handler.queue.add(newQueue);
      await _handler.playTrack(audioUrl, item);
    }
  }

  @override
  Future<void> play(String url) async {
    final resolved = await _handler.resolveRedirects(url);
    await _handler.playTrack(resolved, const MediaItem(id: '', title: ''));
  }

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> resume() => _handler.play();

  @override
  Future<void> stop() => _handler.stop();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<Duration> getPosition() async => _handler.position;

  @override
  Future<Duration> getDuration() async => _handler.duration;

  @override
  Stream<Duration> get positionStream => _handler.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _handler.bufferedPositionStream;

  @override
  Stream<Duration> get durationStream => _handler.durationStream;

  @override
  Future<bool> isPlaying() async => _handler.isPlaying;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _handler.processingStateStream;

  @override
  bool get currentTrackCompleted => _handler.currentTrackCompleted;

  @override
  Future<List<Track>> getRelatedVideos(Track track) async {
    final models = await remoteDataSource.getRelatedVideos(track.id);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Stream<void> get onSkipNextRequested => _handler.skipNextRequested.stream;

  @override
  Stream<void> get onSkipPreviousRequested =>
      _handler.skipPreviousRequested.stream;

  @override
  Stream<dynamic> get mediaItemStream => _handler.mediaItem.stream;
}
