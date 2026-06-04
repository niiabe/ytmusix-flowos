import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../entities/video.dart';

abstract class AudioRepository {
  Future<String> getAudioUrl(Track track, {String quality = 'medium'});
  Future<void> playTrack(Track track, String audioUrl);
  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration> getPosition();
  Future<Duration> getDuration();
  Future<bool> isPlaying();
  Stream<ProcessingState> get processingStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration> get durationStream;
  Future<List<Track>> getRelatedVideos(Track track);
  bool get currentTrackCompleted;
  Stream<void> get onSkipNextRequested;
  Stream<void> get onSkipPreviousRequested;
  Stream<dynamic> get mediaItemStream;
}
