import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/audio_quality.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyPrebufferCount = 'prebufferCount';
  static const _keyAudioQuality = 'audioQuality';
  static const _keyCrossfadeEnabled = 'crossfadeEnabled';
  static const _keyAutoDjMode = 'autoDjMode';
  static const _keyAutoDjSongsCount = 'autoDjSongsCount';
  static const _keyAutoDjThreshold = 'autoDjThreshold';

  static const defaultPrebufferCount = 2;
  static const defaultAutoDjSongsCount = 5;
  static const defaultAutoDjThreshold = 2;

  int _prebufferCount = defaultPrebufferCount;
  AudioQuality _audioQuality = AudioQuality.low;
  bool _crossfadeEnabled = false;
  String _autoDjMode = 'off';
  int _autoDjSongsCount = defaultAutoDjSongsCount;
  int _autoDjThreshold = defaultAutoDjThreshold;

  int get prebufferCount => _prebufferCount;
  AudioQuality get audioQuality => _audioQuality;
  bool get crossfadeEnabled => _crossfadeEnabled;
  String get autoDjMode => _autoDjMode;
  int get autoDjSongsCount => _autoDjSongsCount;
  int get autoDjThreshold => _autoDjThreshold;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prebufferCount = prefs.getInt(_keyPrebufferCount) ?? defaultPrebufferCount;
    final qualityStr = prefs.getString(_keyAudioQuality);
    _audioQuality = qualityStr != null
        ? AudioQuality.values.firstWhere(
            (q) => q.name == qualityStr,
            orElse: () => AudioQuality.low,
          )
        : AudioQuality.low;
    _crossfadeEnabled = prefs.getBool(_keyCrossfadeEnabled) ?? false;
    _autoDjMode = prefs.getString(_keyAutoDjMode) ?? 'off';
    _autoDjSongsCount =
        prefs.getInt(_keyAutoDjSongsCount) ?? defaultAutoDjSongsCount;
    _autoDjThreshold =
        prefs.getInt(_keyAutoDjThreshold) ?? defaultAutoDjThreshold;
    notifyListeners();
  }

  Future<void> setPrebufferCount(int count) async {
    _prebufferCount = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrebufferCount, count);
    notifyListeners();
  }

  Future<void> setAudioQuality(AudioQuality quality) async {
    _audioQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioQuality, quality.name);
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool enabled) async {
    _crossfadeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCrossfadeEnabled, enabled);
    notifyListeners();
  }

  Future<void> setAutoDjMode(String mode) async {
    _autoDjMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAutoDjMode, mode);
    notifyListeners();
  }

  Future<void> setAutoDjSongsCount(int count) async {
    _autoDjSongsCount = count.clamp(1, 20);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoDjSongsCount, _autoDjSongsCount);
    notifyListeners();
  }

  Future<void> setAutoDjThreshold(int threshold) async {
    _autoDjThreshold = threshold.clamp(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoDjThreshold, _autoDjThreshold);
    notifyListeners();
  }
}
