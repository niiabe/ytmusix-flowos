import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/network_utils.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/entities/video.dart';
import '../data/datasources/local/playlist_database.dart';
import '../data/datasources/remote/youtube_remote_datasource.dart';
import 'auth_service.dart';

class MusicAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player1 = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: const Duration(seconds: 3),
        automaticallyWaitsToMinimizeStalling: true,
      ),
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 3),
        maxBufferDuration: const Duration(seconds: 15),
        bufferForPlaybackDuration: const Duration(milliseconds: 800),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 2),
      ),
    ),
  );

  final AudioPlayer _player2 = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: const Duration(seconds: 3),
        automaticallyWaitsToMinimizeStalling: true,
      ),
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 3),
        maxBufferDuration: const Duration(seconds: 15),
        bufferForPlaybackDuration: const Duration(milliseconds: 800),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 2),
      ),
    ),
  );

  bool _isPlayer1Active = true;
  AudioPlayer get _activePlayer => _isPlayer1Active ? _player1 : _player2;
  AudioPlayer get _inactivePlayer => _isPlayer1Active ? _player2 : _player1;

  final AuthService _authService = AuthService();
  late final PlaylistDatabase _database;
  late final YoutubeRemoteDataSource _remoteDataSource;
  bool _dataSourceInitialized = false;
  AudioRepository? _audioRepository;

  bool _crossfadeEnabled = false;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  int? _crossfadeTargetIndex;
  bool _isHandlingCompletion = false;
  bool _fetchingRecommendations = false;

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  void setRepository(AudioRepository repository) {
    _audioRepository = repository;
  }

  final skipNextRequested = StreamController<void>.broadcast();
  final skipPreviousRequested = StreamController<void>.broadcast();

  static const _controls = [
    MediaControl.skipToPrevious,
    MediaControl.play,
    MediaControl.pause,
    MediaControl.skipToNext,
  ];

  static const _systemActions = <MediaAction>{
    MediaAction.skipToPrevious,
    MediaAction.play,
    MediaAction.pause,
    MediaAction.skipToNext,
  };

  PlaybackState get _defaultPlaybackState => PlaybackState(
    controls: _controls,
    systemActions: _systemActions,
    androidCompactActionIndices: [1, 0, 3],
    processingState: AudioProcessingState.idle,
    playing: false,
    updatePosition: Duration.zero,
    speed: 0.0,
  );

  var _queue = <MediaItem>[];
  int? _currentIndex;

  StreamSubscription? _player1StateSub;
  StreamSubscription? _player2StateSub;
  StreamSubscription? _player1ProcessingSub;
  StreamSubscription? _player2ProcessingSub;
  StreamSubscription? _position1Sub;
  StreamSubscription? _position2Sub;
  StreamSubscription? _duration1Sub;
  StreamSubscription? _duration2Sub;
  StreamSubscription? _buffered1Sub;
  StreamSubscription? _buffered2Sub;

  final _positionController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _processingStateController = StreamController<ProcessingState>.broadcast();

  MusicAudioHandler() {
    _database = PlaylistDatabase();
    _remoteDataSource = YoutubeRemoteDataSource(authService: _authService);
    _loadCrossfadeSettings();
    playbackState.add(_defaultPlaybackState);

    _player1StateSub = _player1.playerStateStream.listen((state) {
      if (_isPlayer1Active) _onPlayerState(state);
    });
    _player2StateSub = _player2.playerStateStream.listen((state) {
      if (!_isPlayer1Active) _onPlayerState(state);
    });

    _player1ProcessingSub = _player1.processingStateStream.listen((state) {
      if (_isPlayer1Active) _onProcessingState(state);
    });
    _player2ProcessingSub = _player2.processingStateStream.listen((state) {
      if (!_isPlayer1Active) _onProcessingState(state);
    });

    _position1Sub = _player1.positionStream.listen((pos) {
      if (_isPlayer1Active) {
        _handlePositionUpdate(pos, _player1);
        _positionController.add(pos);
      }
    });
    _position2Sub = _player2.positionStream.listen((pos) {
      if (!_isPlayer1Active) {
        _handlePositionUpdate(pos, _player2);
        _positionController.add(pos);
      }
    });

    _player1.bufferedPositionStream.listen((pos) {
      if (_isPlayer1Active) _bufferedPositionController.add(pos);
    });
    _player2.bufferedPositionStream.listen((pos) {
      if (!_isPlayer1Active) _bufferedPositionController.add(pos);
    });

    _duration1Sub = _player1.durationStream.listen((dur) {
      if (dur != null && _isPlayer1Active) {
        _durationController.add(dur);
        final item = mediaItem.value;
        if (item != null) {
          mediaItem.add(item.copyWith(duration: dur));
        }
      }
    });
    _duration2Sub = _player2.durationStream.listen((dur) {
      if (dur != null && !_isPlayer1Active) {
        _durationController.add(dur);
        final item = mediaItem.value;
        if (item != null) {
          mediaItem.add(item.copyWith(duration: dur));
        }
      }
    });
  }

  Future<void> _loadCrossfadeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _crossfadeEnabled = prefs.getBool('crossfadeEnabled') ?? false;
    } catch (_) {}
  }

  void _onPlayerState(PlayerState state) {
    final current = playbackState.valueOrNull ?? _defaultPlaybackState;
    playbackState.add(
      current.copyWith(
        playing: state.playing,
        speed: state.playing ? 1.0 : 0.0,
        processingState: _convertState(state.processingState),
        controls: _controls,
        systemActions: _systemActions,
        androidCompactActionIndices: [1, 0, 3],
        repeatMode: _repeatMode,
      ),
    );
  }

  void _onProcessingState(ProcessingState state) {
    if (state == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_isHandlingCompletion || _currentIndex == null || _queue.isEmpty) return;
    _isHandlingCompletion = true;

    try {
      if (_repeatMode == AudioServiceRepeatMode.one) {
        await _playAtIndex(_currentIndex!);
        return;
      }

      if (_currentIndex! + 1 < _queue.length) {
        await _playAtIndex(_currentIndex! + 1);
        return;
      }

      if (_repeatMode == AudioServiceRepeatMode.all) {
        await _playAtIndex(0);
        return;
      }

      await _playRecommendations();
    } finally {
      _isHandlingCompletion = false;
    }
  }

  Future<void> _playRecommendations() async {
    if (_audioRepository == null || _currentIndex == null || _queue.isEmpty) return;
    final currentItem = _queue[_currentIndex!];
    try {
      final seed = Track(
        id: currentItem.id,
        title: currentItem.title,
        author: currentItem.artist,
        thumbnailUrl: currentItem.artUri?.toString(),
        duration: currentItem.duration ?? Duration.zero,
      );
      final recommendations = await _audioRepository!.getRecommendations(seed);
      final seenIds = _queue.map((item) => item.id).toSet();
      final newItems = <MediaItem>[];
      for (final track in recommendations) {
        if (seenIds.add(track.id)) {
          newItems.add(MediaItem(
            id: track.id,
            title: track.title,
            artist: track.author ?? '',
            artUri: track.thumbnailUrl != null ? Uri.tryParse(track.thumbnailUrl!) : null,
            duration: track.duration,
          ));
        }
      }
      if (newItems.isNotEmpty) {
        _queue.addAll(newItems);
        queue.add(_queue);
        await _playAtIndex(_currentIndex! + 1);
      } else {
        await stop();
      }
    } catch (_) {
      await stop();
    }
  }

  AudioProcessingState _convertState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  bool get isPlaying => _activePlayer.playing;

  Duration get position => _activePlayer.position;

  Duration get duration => _activePlayer.duration ?? Duration.zero;

  Stream<ProcessingState> get processingStateStream => _processingStateController.stream;

  Stream<Duration> get positionStream => _positionController.stream;

  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;

  Stream<Duration> get durationStream => _durationController.stream;

  int? get currentIndex => _currentIndex;
  int get queueLength => _queue.length;

  bool get currentTrackCompleted =>
      !_activePlayer.playing && _activePlayer.processingState == ProcessingState.completed;

  Future<void> playTrack(String url, MediaItem item) async {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    _currentIndex = _queue.indexWhere((e) => e.id == item.id);
    if (_currentIndex == -1) _currentIndex = null;
    mediaItem.add(item);
    final AudioSource source;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final client = http.Client();
      try {
        final headers = await _getHeaders();
        final resolvedUrl = await NetworkUtils.resolveRedirects(
          client,
          url,
          headers: headers,
        );
        source = AudioSource.uri(
          Uri.parse(resolvedUrl),
          headers: Platform.isIOS ? headers : null,
          tag: item,
        );
      } finally {
        client.close();
      }
    } else {
      source = AudioSource.file(url, tag: item);
    }

    final active = _activePlayer;
    await active.stop();
    await active.setAudioSource(source);
    active.setVolume(1.0);
    unawaited(active.play());

    if (active.duration != null) {
      _durationController.add(active.duration!);
    }
    _positionController.add(active.position);
    _processingStateController.add(active.processingState);
  }

  Future<void> setQueue(List<MediaItem> items, {int startIndex = 0}) async {
    _queue = List.from(items);
    _currentIndex = startIndex;
    queue.add(_queue);
  }

  void clearQueue() {
    _queue = [];
    _currentIndex = null;
  }

  @override
  Future<void> play() async {
    unawaited(_activePlayer.play());
    if (_isCrossfading) {
      unawaited(_inactivePlayer.play());
    }
  }

  @override
  Future<void> pause() async {
    await _activePlayer.pause();
    if (_isCrossfading) {
      await _inactivePlayer.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    await _activePlayer.seek(position);
  }

  @override
  Future<void> stop() async {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    await _activePlayer.stop();
    playbackState.add(
      _defaultPlaybackState.copyWith(
        controls: _controls,
        systemActions: _systemActions,
        androidCompactActionIndices: [1, 0, 3],
        speed: 0.0,
      ),
    );
  }

  @override
  Future<void> skipToNext() async {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    if (_currentIndex != null && _currentIndex! + 1 < _queue.length) {
      await _playAtIndex(_currentIndex! + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    if (_currentIndex != null && _currentIndex! > 0) {
      await _playAtIndex(_currentIndex! - 1);
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    final item = _queue[index];
    mediaItem.add(item);

    final url = await _resolveUrlForItem(item);
    if (url == null || url.isEmpty) return;

    final AudioSource source;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final client = http.Client();
      try {
        final headers = await _getHeaders();
        final resolvedUrl = await NetworkUtils.resolveRedirects(
          client,
          url,
          headers: headers,
        );
        source = AudioSource.uri(
          Uri.parse(resolvedUrl),
          headers: Platform.isIOS ? headers : null,
          tag: item,
        );
      } finally {
        client.close();
      }
    } else {
      source = AudioSource.file(url, tag: item);
    }

    final active = _activePlayer;
    await active.stop();
    await active.setAudioSource(source);
    active.setVolume(1.0);
    unawaited(active.play());

    if (active.duration != null) {
      _durationController.add(active.duration!);
    }
    _positionController.add(active.position);
    _processingStateController.add(active.processingState);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
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

  Future<Map<String, String>> getHeaders() => _getHeaders();

  Future<String> resolveRedirects(String url) async {
    final client = http.Client();
    try {
      return await NetworkUtils.resolveRedirects(client, url, headers: null);
    } finally {
      client.close();
    }
  }

  Future<String?> _resolveUrlForItem(MediaItem item) async {
    String? url;
    try {
      final localPath = await _database.getDownloadedFilePath(item.id);
      if (localPath != null && File(localPath).existsSync()) {
        url = localPath;
      } else {
        if (localPath != null) {
          await _database.removeDownloadedTrack(item.id);
        }
        await _ensureDataSourceInitialized();
        url = await _remoteDataSource.getAudioUrl(item.id, quality: 'low');
      }
    } catch (_) {}

    if ((url == null || url.isEmpty) && _audioRepository != null) {
      try {
        final track = Track(
          id: item.id,
          title: item.title,
          author: item.artist,
          thumbnailUrl: item.artUri?.toString(),
          duration: item.duration ?? Duration.zero,
        );
        url = await _audioRepository!.getAudioUrl(track);
      } catch (_) {}
    }
    return url;
  }

  Future<void> _ensureDataSourceInitialized() async {
    if (!_dataSourceInitialized) {
      await _remoteDataSource.init();
      _dataSourceInitialized = true;
    }
  }

  void _handlePositionUpdate(Duration pos, AudioPlayer player) {
    final current = playbackState.valueOrNull ?? _defaultPlaybackState;
    playbackState.add(
      current.copyWith(
        updatePosition: pos,
        speed: player.playing ? 1.0 : 0.0,
        controls: _controls,
        systemActions: _systemActions,
        androidCompactActionIndices: [1, 0, 3],
        repeatMode: _repeatMode,
      ),
    );

    final dur = player.duration;
    if (dur != null && dur.inSeconds > 7) {
      final remaining = dur - pos;
      if (_crossfadeEnabled && remaining <= const Duration(seconds: 7) && !_isCrossfading) {
        _checkAndStartCrossfade();
      }
    }
  }

  Future<void> _checkAndStartCrossfade() async {
    if (_currentIndex == null || _queue.isEmpty) return;

    int? nextIndex;
    if (_repeatMode == AudioServiceRepeatMode.one) {
      nextIndex = _currentIndex;
    } else if (_currentIndex! + 1 < _queue.length) {
      nextIndex = _currentIndex! + 1;
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      nextIndex = 0;
    }

    if (nextIndex != null) {
      await _startCrossfade(nextIndex);
    } else {
      _fetchAndAppendRecommendationsForCrossfade();
    }
  }

  Future<void> _fetchAndAppendRecommendationsForCrossfade() async {
    if (_fetchingRecommendations || _audioRepository == null || _currentIndex == null || _queue.isEmpty) return;
    _fetchingRecommendations = true;
    try {
      final currentItem = _queue[_currentIndex!];
      final seed = Track(
        id: currentItem.id,
        title: currentItem.title,
        author: currentItem.artist,
        thumbnailUrl: currentItem.artUri?.toString(),
        duration: currentItem.duration ?? Duration.zero,
      );
      final recommendations = await _audioRepository!.getRecommendations(seed);
      final seenIds = _queue.map((item) => item.id).toSet();
      final newItems = <MediaItem>[];
      for (final track in recommendations) {
        if (seenIds.add(track.id)) {
          newItems.add(MediaItem(
            id: track.id,
            title: track.title,
            artist: track.author ?? '',
            artUri: track.thumbnailUrl != null ? Uri.tryParse(track.thumbnailUrl!) : null,
            duration: track.duration,
          ));
        }
      }
      if (newItems.isNotEmpty) {
        _queue.addAll(newItems);
        queue.add(_queue);
      }
    } catch (_) {
    } finally {
      _fetchingRecommendations = false;
    }
  }

  Future<void> _startCrossfade(int nextIndex) async {
    _isCrossfading = true;
    _crossfadeTargetIndex = nextIndex;
    final nextItem = _queue[nextIndex];

    final nextUrl = await _resolveUrlForItem(nextItem);
    if (nextUrl == null || nextUrl.isEmpty) {
      _isCrossfading = false;
      _crossfadeTargetIndex = null;
      return;
    }

    final AudioSource source;
    if (nextUrl.startsWith('http://') || nextUrl.startsWith('https://')) {
      final client = http.Client();
      try {
        final headers = await _getHeaders();
        final resolvedUrl = await NetworkUtils.resolveRedirects(
          client,
          nextUrl,
          headers: headers,
        );
        source = AudioSource.uri(
          Uri.parse(resolvedUrl),
          headers: Platform.isIOS ? headers : null,
          tag: nextItem,
        );
      } finally {
        client.close();
      }
    } else {
      source = AudioSource.file(nextUrl, tag: nextItem);
    }

    final inactive = _inactivePlayer;
    final active = _activePlayer;

    await inactive.stop();
    await inactive.setAudioSource(source);
    inactive.setVolume(0.0);
    unawaited(inactive.play());

    mediaItem.add(nextItem);

    int step = 0;
    const totalSteps = 70;
    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      step++;
      final volumeActive = (1.0 - (step / totalSteps)).clamp(0.0, 1.0);
      final volumeInactive = (step / totalSteps).clamp(0.0, 1.0);

      active.setVolume(volumeActive);
      inactive.setVolume(volumeInactive);

      if (step >= totalSteps) {
        timer.cancel();
        await _completeCrossfade();
      }
    });
  }

  Future<void> _completeCrossfade() async {
    final active = _activePlayer;
    final inactive = _inactivePlayer;

    _isPlayer1Active = !_isPlayer1Active;
    if (_crossfadeTargetIndex != null) {
      _currentIndex = _crossfadeTargetIndex;
    }
    _crossfadeTargetIndex = null;

    await active.stop();
    active.setVolume(1.0);
    inactive.setVolume(1.0);

    _isCrossfading = false;

    if (inactive.duration != null) {
      _durationController.add(inactive.duration!);
    }
    _positionController.add(inactive.position);
    _processingStateController.add(inactive.processingState);
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _inactivePlayer.stop();
    _activePlayer.setVolume(1.0);
    _inactivePlayer.setVolume(1.0);
    _isCrossfading = false;
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'setCrossfadeEnabled') {
      _crossfadeEnabled = extras?['enabled'] ?? false;
      if (!_crossfadeEnabled && _isCrossfading) {
        _cancelCrossfade();
      }
    }
    return super.customAction(name, extras);
  }

  void dispose() {
    _player1StateSub?.cancel();
    _player2StateSub?.cancel();
    _player1ProcessingSub?.cancel();
    _player2ProcessingSub?.cancel();
    _position1Sub?.cancel();
    _position2Sub?.cancel();
    _duration1Sub?.cancel();
    _duration2Sub?.cancel();
    _buffered1Sub?.cancel();
    _buffered2Sub?.cancel();
    _crossfadeTimer?.cancel();
    _positionController.close();
    _bufferedPositionController.close();
    _durationController.close();
    _processingStateController.close();
    _player1.dispose();
    _player2.dispose();
  }
}
