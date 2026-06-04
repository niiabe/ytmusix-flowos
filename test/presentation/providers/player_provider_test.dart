import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ytmusix/core/constants/audio_quality.dart';
import 'package:ytmusix/domain/entities/video.dart';
import 'package:ytmusix/domain/repositories/audio_repository.dart';
import 'package:ytmusix/presentation/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioRepository repository;
  late PlayerProvider player;

  const seed = Track(id: 'seed', title: 'Seed');
  const nextTrack = Track(id: 'next', title: 'Next');
  const recommendation = Track(id: 'rec', title: 'Recommendation');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAudioRepository();
    player = PlayerProvider(repository);
  });

  tearDown(() {
    player.dispose();
    repository.dispose();
  });

  test('repeat one replays the current track on completion', () async {
    player.setQueue([seed], startIndex: 0);
    player.cycleRepeatMode();
    await player.playTrack(seed, quality: AudioQuality.high);

    repository.completeCurrentTrack();
    await pumpEvents();

    expect(repository.playedTrackIds, ['seed', 'seed']);
    expect(repository.requestedQualities, ['high', 'high']);
    expect(repository.recommendationCallCount, 0);
  });

  test('repeat all wraps to the first track on queue end', () async {
    player.setQueue([seed, nextTrack], startIndex: 1);
    player.cycleRepeatMode();
    player.cycleRepeatMode();
    await player.playTrack(nextTrack, quality: AudioQuality.medium);

    repository.completeCurrentTrack();
    await pumpEvents();

    expect(player.currentIndex, 0);
    expect(repository.playedTrackIds, ['next', 'seed']);
    expect(repository.requestedQualities, ['medium', 'medium', 'medium']);
    expect(repository.recommendationCallCount, 0);
  });

  test('no repeat advances to the next queued track', () async {
    player.setQueue([seed, nextTrack], startIndex: 0);
    await player.playTrack(seed, quality: AudioQuality.high);

    repository.completeCurrentTrack();
    await pumpEvents();

    expect(player.currentIndex, 1);
    expect(repository.playedTrackIds, ['seed', 'next']);
    expect(repository.requestedQualities, ['high', 'high']);
    expect(repository.recommendationCallCount, 0);
  });

  test('no repeat fetches and plays recommendations at queue end', () async {
    repository.recommendations = [recommendation];
    player.setQueue([seed], startIndex: 0);
    await player.playTrack(seed, quality: AudioQuality.medium);

    repository.completeCurrentTrack();
    await pumpEvents();

    expect(repository.recommendationSeeds, ['seed']);
    expect(player.queue.map((track) => track.id), ['seed', 'rec']);
    expect(player.currentIndex, 1);
    expect(repository.playedTrackIds, ['seed', 'rec']);
    expect(repository.requestedQualities, ['medium', 'medium']);
  });

  test('empty recommendations leave playback ended without an error', () async {
    repository.recommendations = [];
    player.setQueue([seed], startIndex: 0);
    await player.playTrack(seed);

    repository.completeCurrentTrack();
    await pumpEvents();

    expect(player.isPlaying, isFalse);
    expect(player.queue.map((track) => track.id), ['seed']);
    expect(player.error, isNull);
    expect(repository.playedTrackIds, ['seed']);
  });

  test(
    'recommendations are filtered against queued and duplicate tracks',
    () async {
      repository.recommendations = [
        seed,
        recommendation,
        recommendation,
        const Track(id: 'rec-2', title: 'Recommendation 2'),
      ];
      player.setQueue([seed], startIndex: 0);
      await player.playTrack(seed);

      repository.completeCurrentTrack();
      await pumpEvents();

      expect(player.queue.map((track) => track.id), ['seed', 'rec', 'rec-2']);
      expect(player.currentTrack?.id, 'rec');
      expect(repository.playedTrackIds, ['seed', 'rec']);
    },
  );

  test('completion guard prevents duplicate recommendation fetches', () async {
    final recommendations = Completer<List<Track>>();
    repository.recommendationsCompleter = recommendations;
    player.setQueue([seed], startIndex: 0);
    await player.playTrack(seed);

    repository.completeCurrentTrack();
    repository.completeCurrentTrack();
    await Future<void>.delayed(Duration.zero);

    expect(repository.recommendationCallCount, 1);

    recommendations.complete([recommendation]);
    await pumpEvents();

    expect(repository.recommendationCallCount, 1);
    expect(repository.playedTrackIds, ['seed', 'rec']);
  });

  test('manual next at queue end does not fetch recommendations', () async {
    repository.recommendations = [recommendation];
    player.setQueue([seed], startIndex: 0);
    await player.playTrack(seed);

    await player.next();
    await pumpEvents();

    expect(repository.recommendationCallCount, 0);
    expect(repository.playedTrackIds, ['seed']);
  });
}

Future<void> pumpEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
  final recommendationSeeds = <String>[];

  List<Track> recommendations = const [];
  Completer<List<Track>>? recommendationsCompleter;
  int recommendationCallCount = 0;
  bool playing = false;

  void completeCurrentTrack() {
    playing = false;
    processingController.add(ProcessingState.completed);
  }

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
    recommendationCallCount++;
    recommendationSeeds.add(seed.id);
    if (recommendationsCompleter != null) {
      return recommendationsCompleter!.future;
    }
    return recommendations.take(limit).toList();
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
