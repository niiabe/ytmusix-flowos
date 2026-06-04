import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/audio_quality.dart';
import '../../core/constants/repeat_mode.dart' as repeat;
import '../../domain/entities/video.dart';
import '../../domain/repositories/audio_repository.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../service/audio_handler.dart';
import 'download_provider.dart';
import 'settings_provider.dart';

// ---------------------------------------------------------------------------
// URL cache — maps trackId -> resolved stream URL so the next-track load
// is instant when the URL was prefetched during the current track's playback.
// ---------------------------------------------------------------------------

class PlayerProvider extends ChangeNotifier {
  final AudioRepository _audioRepository;
  final DownloadProvider? _downloadProvider;
  final SettingsProvider? _settingsProvider;

  PlayerProvider(
    this._audioRepository, {
    this._downloadProvider,
    this._settingsProvider,
  }) {
    _skipNextSubscription = _audioRepository.onSkipNextRequested.listen((_) {
      next();
    });
    _skipPrevSubscription = _audioRepository.onSkipPreviousRequested.listen((
      _,
    ) {
      previous();
    });
    _mediaItemSub = _audioRepository.mediaItemStream.listen((item) {
      if (item == null) return;
      final index = _queue.indexWhere((t) => t.id == item.id);
      if (index != -1 && _currentIndex != index) {
        _currentIndex = index;
        _currentTrack = _queue[index];
        _position = Duration.zero;
        _duration = item.duration ?? _currentTrack!.duration;
        notifyListeners();
        for (final cb in _trackChangedListeners) {
          cb();
        }
      }
    });
  }

  Track? _currentTrack;
  List<Track> _queue = [];
  List<Track>? _originalQueue;
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _shuffleMode = false;
  bool _isAutoplaying = false;
  repeat.PlaybackRepeatMode _repeatMode = repeat.PlaybackRepeatMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  String? _error;
  String? _currentPlaylistId;
  StreamSubscription? _skipNextSubscription;
  StreamSubscription? _skipPrevSubscription;
  StreamSubscription? _mediaItemSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferedPositionSub;
  StreamSubscription? _playbackStateSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _completionSubscription;
  bool _isHandlingCompletion = false;

  Timer? _sleepTimer;
  Timer? _sleepTimerTick;
  Duration? _sleepTimerRemaining;

  /// Preloaded stream URL cache. Key = track.id, value = resolved URL.
  final Map<String, String> _urlCache = {};
  bool _isPrebuffering = false;

  final List<VoidCallback> _trackChangedListeners = [];

  void addTrackChangedListener(VoidCallback cb) {
    _trackChangedListeners.add(cb);
  }

  void removeTrackChangedListener(VoidCallback cb) {
    _trackChangedListeners.remove(cb);
  }

  static const _recentlyPlayedKey = 'recently_played';
  static const _maxRecent = 20;
  List<Track> _recentlyPlayed = [];

  List<Track> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  Future<void> loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recentlyPlayedKey);
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List<dynamic>;
      _recentlyPlayed = list.map((e) {
        final m = e as Map<String, dynamic>;
        return Track(
          id: m['id'] as String,
          title: m['title'] as String,
          author: m['author'] as String?,
          thumbnailUrl: m['thumbnailUrl'] as String?,
          duration: Duration(seconds: m['durationSeconds'] as int? ?? 0),
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> _addToRecentlyPlayed(Track track) async {
    _recentlyPlayed.removeWhere((t) => t.id == track.id);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > _maxRecent) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, _maxRecent);
    }
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      _recentlyPlayed
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'author': t.author,
              'thumbnailUrl': t.thumbnailUrl,
              'durationSeconds': t.duration.inSeconds,
            },
          )
          .toList(),
    );
    await prefs.setString(_recentlyPlayedKey, json);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) {
      if (_queue.length > 1) {
        final newIdx = index < _queue.length - 1 ? index : index - 1;
        _queue.removeAt(index);
        _currentIndex = newIdx.clamp(0, _queue.length - 1);
        _currentTrack = _queue.isNotEmpty ? _queue[_currentIndex] : null;
      } else {
        _queue.removeAt(index);
        _currentTrack = null;
        _currentIndex = 0;
      }
    } else {
      _queue.removeAt(index);
      if (index < _currentIndex) _currentIndex--;
    }
    _syncQueueToHandler();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else {
      if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
        _currentIndex++;
      }
    }
    _syncQueueToHandler();
    notifyListeners();
  }

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isAutoplaying => _isAutoplaying;
  bool get shuffleMode => _shuffleMode;
  repeat.PlaybackRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;
  String? get error => _error;
  String? get currentPlaylistId => _currentPlaylistId;
  bool get isSleepTimerActive => _sleepTimer != null;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  AudioQuality get lastPlaybackQuality => _lastPlaybackQuality;

  void setQueue(List<Track> tracks, {int startIndex = 0, String? playlistId}) {
    _queue = tracks;
    _currentIndex = startIndex;
    _currentPlaylistId = playlistId;
    _originalQueue = null;
    _shuffleMode = false;
    _error = null;
    _syncQueueToHandler();
    notifyListeners();
  }

  void toggleShuffle() {
    if (_shuffleMode) {
      if (_originalQueue != null) {
        final currentId = _currentTrack?.id;
        _queue = List.from(_originalQueue!);
        _currentIndex = _queue.indexWhere((t) => t.id == currentId);
        if (_currentIndex < 0) _currentIndex = 0;
      }
      _originalQueue = null;
      _shuffleMode = false;
    } else {
      _originalQueue = List.from(_queue);
      final currentId = _currentTrack?.id;
      final currentIdx = _queue.indexWhere((t) => t.id == currentId);
      if (currentIdx >= 0) {
        final current = _queue.removeAt(currentIdx);
        _queue.shuffle(Random());
        _queue.insert(0, current);
        _currentIndex = 0;
      } else {
        _queue.shuffle(Random());
        _currentIndex = 0;
      }
      _shuffleMode = true;
    }
    _syncQueueToHandler();
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode =
        repeat.PlaybackRepeatMode.values[(_repeatMode.index + 1) %
            repeat.PlaybackRepeatMode.values.length];
    notifyListeners();
    if (_audioHandler != null) {
      final mode = switch (_repeatMode) {
        repeat.PlaybackRepeatMode.none => AudioServiceRepeatMode.none,
        repeat.PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
        repeat.PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
      };
      _audioHandler!.setRepeatMode(mode);
    }
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerTick?.cancel();
    _sleepTimerRemaining = duration;
    _sleepTimer = Timer(duration, () {
      _sleepTimerRemaining = Duration.zero;
      _sleepTimer = null;
      _sleepTimerTick?.cancel();
      _sleepTimerTick = null;
      stop();
    });
    _sleepTimerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining!.inSeconds > 0) {
        _sleepTimerRemaining =
            _sleepTimerRemaining! - const Duration(seconds: 1);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerTick?.cancel();
    _sleepTimer = null;
    _sleepTimerTick = null;
    _sleepTimerRemaining = null;
    notifyListeners();
  }

  Future<void> playTrack(
    Track track, {
    AudioQuality quality = AudioQuality.low,
  }) async {
    _isLoading = true;
    _error = null;
    _currentTrack = track;
    _position = Duration.zero;
    _duration = track.duration;
    _stopPolling();
    notifyListeners();
 
    try {
      _addToRecentlyPlayed(track);
      // Check preload cache first — avoids the 2-5s URL resolution wait.
      final cachedUrl = _urlCache.remove(track.id);
      final audioUrl = cachedUrl ??
          await _audioRepository.getAudioUrl(
            track,
            quality: quality.name,
          );
      await _audioRepository.playTrack(track, audioUrl);
      _isPlaying = true;
      _startPolling();
      if (_audioHandler == null) {
        _listenForCompletion();
      }
      for (final cb in _trackChangedListeners) {
        cb();
      }
      // Kick off background prefetch for upcoming tracks.
      unawaited(_prebufferNext(_currentIndex + 1, quality));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Preloads stream URLs for the next [count] tracks into [_urlCache].
  Future<void> _prebufferNext(int fromIndex, AudioQuality quality) async {
    if (_isPrebuffering) return;
    _isPrebuffering = true;
    final count = 2; // matches SettingsProvider.defaultPrebufferCount
    try {
      for (var i = fromIndex; i < fromIndex + count && i < _queue.length; i++) {
        final track = _queue[i];
        if (_urlCache.containsKey(track.id)) continue;
        try {
          final url = await _audioRepository.getAudioUrl(
            track,
            quality: quality.name,
          );
          _urlCache[track.id] = url;
        } catch (_) {
          // Prefetch failures are silent — url will be fetched on demand.
        }
      }
      // Evict URLs for tracks that are 3+ positions behind current index.
      final staleThreshold = _currentIndex - 3;
      if (staleThreshold > 0) {
        final staleIds = _queue
            .sublist(0, staleThreshold.clamp(0, _queue.length))
            .map((t) => t.id)
            .toSet();
        _urlCache.removeWhere((id, _) => staleIds.contains(id));
      }
    } finally {
      _isPrebuffering = false;
    }
  }

  Future<String> getVideoUrl(
    Track track, {
    AudioQuality quality = AudioQuality.low,
  }) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await playTrack(_queue[index], quality: quality);
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioRepository.pause();
        _isPlaying = false;
      } else {
        await _audioRepository.resume();
        _isPlaying = true;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to toggle playback: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    final previous = _position;
    _position = position;
    notifyListeners();
    try {
      await _audioRepository.seek(position);
    } catch (e) {
      _position = previous;
      _error = 'Failed to seek: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (_currentIndex + 1 < _queue.length) {
      await playFromQueue(_currentIndex + 1);
    } else if (_repeatMode == repeat.PlaybackRepeatMode.all &&
        _queue.isNotEmpty) {
      await playFromQueue(0);
    } else if (_currentTrack != null) {
      await _fetchAutoplayRecommendations();
    }
  }

  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    } else {
      await seekTo(Duration.zero);
    }
  }

  void _startPolling() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    _positionSub = _audioRepository.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _bufferedPositionSub = _audioRepository.bufferedPositionStream.listen((
      pos,
    ) {
      _bufferedPosition = pos;
      notifyListeners();
    });
    _durationSub = _audioRepository.durationStream.listen((dur) {
      _duration = dur;
      notifyListeners();
    });
  }

  void _stopPolling() {
    _positionSub?.cancel();
    _positionSub = null;
    _durationSub?.cancel();
    _durationSub = null;
    _bufferedPositionSub?.cancel();
    _bufferedPositionSub = null;
  }

  Future<void> stop() async {
    _stopPolling();
    _completionSubscription?.cancel();
    await _audioRepository.stop();
    _isPlaying = false;
    _position = Duration.zero;
    _bufferedPosition = Duration.zero;
    notifyListeners();
  }

  Future<void> clearQueue() async {
    _queue = [];
    _currentIndex = 0;
    _currentTrack = null;
    _currentPlaylistId = null;
    _originalQueue = null;
    _shuffleMode = false;
    _audioHandler?.clearQueue();
    await stop();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  MusicAudioHandler? _audioHandler;

  bool _areQueuesEqual(List<Track> q1, List<Track> q2) {
    if (q1.length != q2.length) return false;
    for (int i = 0; i < q1.length; i++) {
      if (q1[i].id != q2[i].id) return false;
    }
    return true;
  }

  void _listenForCompletion() {
    _completionSubscription?.cancel();
    _completionSubscription = _audioRepository.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed) {
        unawaited(_handleCompletion());
      }
    });
  }

  Future<void> _handleCompletion() async {
    if (_isHandlingCompletion || _queue.isEmpty) return;
    _isHandlingCompletion = true;

    try {
      if (_repeatMode == repeat.PlaybackRepeatMode.one) {
        await playFromQueue(_currentIndex);
        return;
      }
      if (_currentIndex + 1 < _queue.length) {
        await playFromQueue(_currentIndex + 1);
        return;
      }
      if (_repeatMode == repeat.PlaybackRepeatMode.all) {
        await playFromQueue(0);
        return;
      }

      await _playRecommendationsFromCurrentTrack();
    } finally {
      _isHandlingCompletion = false;
    }
  }

  Future<void> handleTrackCompletion() async {
    await _handleCompletion();
  }

  Future<void> _playRecommendationsFromCurrentTrack() async {
    final seed = _currentTrack ?? _queue[_currentIndex];
    _isLoading = true;
    notifyListeners();

    try {
      final recommendations = await _audioRepository.getRecommendations(seed);
      final seenIds = _queue.map((track) => track.id).toSet();
      final uniqueRecommendations = <Track>[];
      for (final track in recommendations) {
        if (seenIds.add(track.id)) {
          uniqueRecommendations.add(track);
        }
      }

      if (uniqueRecommendations.isEmpty) {
        _isPlaying = false;
        return;
      }

      final firstRecommendationIndex = _queue.length;
      _queue = [..._queue, ...uniqueRecommendations];
      _currentIndex = firstRecommendationIndex;
      notifyListeners();
      await playTrack(_queue[_currentIndex], quality: _lastPlaybackQuality);
    } catch (e) {
      _isPlaying = false;
      _error = 'Failed to load recommendations: ${e.toString()}';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setAudioHandler(MusicAudioHandler handler) {
    _audioHandler = handler;
    _playbackStateSub?.cancel();
    _playbackStateSub = handler.playbackState.listen((state) {
      bool changed = false;
      if (_isPlaying != state.playing) {
        _isPlaying = state.playing;
        changed = true;
      }
      final newMode = switch (state.repeatMode) {
        AudioServiceRepeatMode.none => repeat.PlaybackRepeatMode.none,
        AudioServiceRepeatMode.one => repeat.PlaybackRepeatMode.one,
        AudioServiceRepeatMode.all => repeat.PlaybackRepeatMode.all,
        _ => repeat.PlaybackRepeatMode.none,
      };
      if (_repeatMode != newMode) {
        _repeatMode = newMode;
        changed = true;
      }
      if (changed) {
        notifyListeners();
      }
    });
    _queueSub?.cancel();
    _queueSub = handler.queue.listen((items) {
      final newTracks = items.map((item) => Track(
        id: item.id,
        title: item.title,
        author: item.artist,
        thumbnailUrl: item.artUri?.toString(),
        duration: item.duration ?? Duration.zero,
      )).toList();
      if (!_areQueuesEqual(_queue, newTracks)) {
        _queue = newTracks;
        notifyListeners();
      }
    });
    _queueSub?.cancel();
    _queueSub = handler.queue.listen((items) {
      final newTracks = items.map((item) => Track(
        id: item.id,
        title: item.title,
        author: item.artist,
        thumbnailUrl: item.artUri?.toString(),
        duration: item.duration ?? Duration.zero,
      )).toList();
      if (!_areQueuesEqual(_queue, newTracks)) {
        _queue = newTracks;
        notifyListeners();
      }
    });
    _syncQueueToHandler();
    final mode = switch (_repeatMode) {
      repeat.PlaybackRepeatMode.none => AudioServiceRepeatMode.none,
      repeat.PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
      repeat.PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
    };
    _audioHandler!.setRepeatMode(mode);
  }

  MediaItem _trackToMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.author ?? '',
      artUri: track.thumbnailUrl != null
          ? Uri.tryParse(track.thumbnailUrl!)
          : null,
      duration: track.duration,
    );
  }

  void _syncQueueToHandler() {
    if (_audioHandler != null) {
      final items = _queue.map(_trackToMediaItem).toList();
      _audioHandler!.setQueue(items, startIndex: _currentIndex);
    }
  }

  void setCrossfadeEnabled(bool enabled) {
    _audioHandler?.customAction('setCrossfadeEnabled', {'enabled': enabled});
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTimerTick?.cancel();
    _stopPolling();
    _completionSubscription?.cancel();
    _queueSub?.cancel();
    _skipNextSubscription?.cancel();
    _skipPrevSubscription?.cancel();
    _mediaItemSub?.cancel();
    _playbackStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    super.dispose();
  }
}
