import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytmusix/core/constants/repeat_mode.dart' as repeat;
import 'package:ytmusix/domain/entities/video.dart';
import 'package:ytmusix/domain/repositories/audio_repository.dart';
import 'package:ytmusix/presentation/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioRepository repository;
  late PlayerProvider player;

  const track1 = Track(id: '1', title: 'Track 1', duration: Duration(seconds: 100));
  const track2 = Track(id: '2', title: 'Track 2', duration: Duration(seconds: 120));
  const track3 = Track(id: '3', title: 'Track 3', duration: Duration(seconds: 140));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAudioRepository();
    player = PlayerProvider(repository);
  });

  tearDown(() {
    player.dispose();
    repository.dispose();
  });

  test('setQueue initializes queue, index, and current track', () {
    player.setQueue([track1, track2, track3], startIndex: 1);
    expect(player.queue, [track1, track2, track3]);
    expect(player.currentIndex, 1);
    expect(player.currentTrack, null);
  });

  test('toggleShuffle shuffles queue and keeps current track at index 0', () {
    player.setQueue([track1, track2, track3], startIndex: 1);
    player.playTrack(track2); // sets currentTrack to track2

    player.toggleShuffle();
    expect(player.shuffleMode, true);
    expect(player.queue.length, 3);
    expect(player.queue[0], track2); // current track moved to first position
    expect(player.currentIndex, 0);

    player.toggleShuffle();
    expect(player.shuffleMode, false);
    expect(player.queue, [track1, track2, track3]);
    expect(player.currentIndex, 1);
  });

  test('cycleRepeatMode cycles through repeat modes', () {
    expect(player.repeatMode, repeat.PlaybackRepeatMode.none);
    player.cycleRepeatMode();
    expect(player.repeatMode, repeat.PlaybackRepeatMode.one);
    player.cycleRepeatMode();
    expect(player.repeatMode, repeat.PlaybackRepeatMode.all);
    player.cycleRepeatMode();
    expect(player.repeatMode, repeat.PlaybackRepeatMode.none);
  });

  test('removeFromQueue updates state correctly', () {
    player.setQueue([track1, track2, track3], startIndex: 1);
    player.playTrack(track2);

    // Remove non-current track after current index
    player.removeFromQueue(2);
    expect(player.queue, [track1, track2]);
    expect(player.currentIndex, 1);

    // Remove current track
    player.removeFromQueue(1);
    expect(player.queue, [track1]);
    expect(player.currentIndex, 0);
    expect(player.currentTrack, track1);
  });

  test('reorderQueue updates queue order and adjusts current index', () {
    player.setQueue([track1, track2, track3], startIndex: 1);
    player.playTrack(track2);

    // Reorder track1 (idx 0) to end (idx 2)
    player.reorderQueue(0, 2);
    expect(player.queue, [track2, track3, track1]);
    expect(player.currentIndex, 0);
  });

  test('sleepTimer sets remaining duration and cancels correctly', () async {
    player.startSleepTimer(const Duration(seconds: 10));
    expect(player.isSleepTimerActive, true);
    expect(player.sleepTimerRemaining, const Duration(seconds: 10));

    player.cancelSleepTimer();
    expect(player.isSleepTimerActive, false);
    expect(player.sleepTimerRemaining, null);
  });
}

class FakeAudioRepository implements AudioRepository {
  final processingController = StreamController<ProcessingState>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final bufferedPositionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final skipNextController = StreamController<void>.broadcast();
  final skipPreviousController = StreamController<void>.broadcast();
  final mediaItemController = StreamController<dynamic>.broadcast();

  final playedTrackIds = <String>[];
  final requestedQualities = <String>[];

  bool playing = false;

  @override
  Future<String> getAudioUrl(Track track, {String quality = 'medium'}) async {
    requestedQualities.add(quality);
    return 'audio:${track.id}:$quality';
  }

  @override
  Future<String> getVideoUrl(Track track, {String quality = 'medium'}) async {
    return 'video:${track.id}:$quality';
  }

  @override
  Future<List<Track>> getRecommendations(Track seed, {int limit = 20}) async {
    return [];
  }

  @override
  Future<List<Track>> getRelatedVideos(Track track) async {
    return [];
  }

  @override
  Future<void> playTrack(Track track, String audioUrl) async {
    playedTrackIds.add(track.id);
    playing = true;
    mediaItemController.add(MediaItem(
      id: track.id,
      title: track.title,
      artist: track.author ?? '',
      duration: track.duration,
    ));
  }

  @override
  Future<void> play(String url) async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> resume() async {
    playing = true;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<Duration> getPosition() async => Duration.zero;

  @override
  Future<Duration> getDuration() async => Duration.zero;

  @override
  Future<bool> isPlaying() async => playing;

  @override
  Stream<ProcessingState> get processingStateStream =>
      processingController.stream;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      bufferedPositionController.stream;

  @override
  Stream<Duration> get durationStream => durationController.stream;

  @override
  bool get currentTrackCompleted => !playing;

  @override
  Stream<void> get onSkipNextRequested => skipNextController.stream;

  @override
  Stream<void> get onSkipPreviousRequested => skipPreviousController.stream;

  @override
  Stream<dynamic> get mediaItemStream => mediaItemController.stream;

  void dispose() {
    processingController.close();
    positionController.close();
    bufferedPositionController.close();
    durationController.close();
    skipNextController.close();
    skipPreviousController.close();
    mediaItemController.close();
  }
}
