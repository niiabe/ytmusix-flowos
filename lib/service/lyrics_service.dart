import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../domain/entities/video.dart';

class LyricsResult {
  final String trackName;
  final String artistName;
  final String? plainLyrics;
  final List<LyricLine> syncedLines;
  final int duration;

  const LyricsResult({
    required this.trackName,
    required this.artistName,
    this.plainLyrics,
    this.syncedLines = const [],
    this.duration = 0,
  });

  bool get hasSyncedLyrics => syncedLines.isNotEmpty;
  bool get hasAnyLyrics =>
      syncedLines.isNotEmpty ||
      (plainLyrics != null && plainLyrics!.isNotEmpty);
}

class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

class LyricsService {
  final http.Client _client;
  final Map<String, LyricsResult?> _cache = {};

  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  Future<LyricsResult?> getLyrics(Track track) async {
    final cacheKey = track.id;
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final rawTitle = track.title;
    final rawArtist = track.author ?? '';
    final duration = track.duration.inSeconds;

    try {
      final titleA = _cleanTitle(rawTitle);
      final artistA = _cleanArtist(rawArtist);

      // Strategy A: robust search with title and artist
      var result = await _search(titleA, artistA, duration);
      if (result != null && result.hasAnyLyrics) {
        _cache[cacheKey] = result;
        return result;
      }

      // Strategy B: hyphen split (e.g. Artist - Title)
      String? splitTitle;
      String? splitArtist;
      final hyphenIndex = rawTitle.indexOf(RegExp(r'\s+[-–—]\s+'));
      if (hyphenIndex != -1) {
        final parts = rawTitle.split(RegExp(r'\s+[-–—]\s+'));
        if (parts.length >= 2) {
          splitArtist = _cleanArtist(parts[0]);
          splitTitle = _cleanTitle(parts[1]);

          result = await _search(splitTitle, splitArtist, duration);
          if (result != null && result.hasAnyLyrics) {
            _cache[cacheKey] = result;
            return result;
          }
        }
      }

      // Strategy C: title-only search
      result = await _search(titleA, '', duration);
      if (result != null && result.hasAnyLyrics) {
        _cache[cacheKey] = result;
        return result;
      }

      // Strategy D: split-title only search
      if (splitTitle != null) {
        result = await _search(splitTitle, '', duration);
        if (result != null && result.hasAnyLyrics) {
          _cache[cacheKey] = result;
          return result;
        }
      }

      _cache[cacheKey] = null;
      return null;
    } catch (e) {
      dev.log(
        'Lyrics lookup failed for ${track.id}: $e',
        name: 'LyricsService',
      );
      _cache[cacheKey] = null;
      return null;
    }
  }

  Future<LyricsResult?> _search(
    String title,
    String artist,
    int duration,
  ) async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': title,
      if (artist.isNotEmpty) 'artist_name': artist,
    });
    final response = await _client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;

    final parsed = results
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .where((result) => result.hasAnyLyrics)
        .toList();
    if (parsed.isEmpty) return null;

    // Rank candidates by combining title similarity, artist similarity, duration difference, and synced preference
    parsed.sort((a, b) {
      int aScore = 0;
      int bScore = 0;

      aScore += _titleScore(a.trackName, title);
      bScore += _titleScore(b.trackName, title);

      aScore += _artistScore(a.artistName, artist);
      bScore += _artistScore(b.artistName, artist);

      if (duration > 0) {
        final aDiff = (a.duration - duration).abs();
        final bDiff = (b.duration - duration).abs();

        if (aDiff <= 4) {
          aScore += 60;
        } else if (aDiff <= 12) {
          aScore += 30;
        } else if (aDiff <= 25) {
          aScore += 10;
        } else if (aDiff > 45) {
          aScore -= 50;
        }

        if (bDiff <= 4) {
          bScore += 60;
        } else if (bDiff <= 12) {
          bScore += 30;
        } else if (bDiff <= 25) {
          bScore += 10;
        } else if (bDiff > 45) {
          bScore -= 50;
        }
      }

      if (a.hasSyncedLyrics) aScore += 40;
      if (b.hasSyncedLyrics) bScore += 40;

      return bScore.compareTo(aScore);
    });
    return parsed.first;
  }

  LyricsResult _fromJson(Map<String, dynamic> json) {
    final synced = json['syncedLyrics'] as String?;
    final plain = json['plainLyrics'] as String?;
    final dur = json['duration'] != null 
        ? (json['duration'] as num).round() 
        : 0;
    return LyricsResult(
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      plainLyrics: plain?.trim(),
      syncedLines: _parseSyncedLyrics(synced),
      duration: dur,
    );
  }

  List<LyricLine> _parseSyncedLyrics(String? lyrics) {
    if (lyrics == null || lyrics.trim().isEmpty) return const [];
    final lines = <LyricLine>[];
    final regex = RegExp(r'^\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)$');
    for (final raw in lyrics.split('\n')) {
      final match = regex.firstMatch(raw.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = (match.group(3) ?? '0').padRight(3, '0');
      final millis = int.parse(fraction.substring(0, 3));
      final text = match.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      lines.add(
        LyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          ),
          text: text,
        ),
      );
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\([^)]*(official|visualizer|video|audio|lyrics?)[^)]*\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\[[^\]]*(official|visualizer|video|audio|lyrics?)[^\]]*\]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(official|music|lyric|lyrics?)\s+(video|audio)$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*\(?\s*f(ea)?t\.\s+[^)]+\)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanArtist(String? artist) {
    return (artist ?? '')
        .replaceAll(RegExp(r'\s+-\s+Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _titleScore(String candidate, String target) {
    final a = _normalize(candidate);
    final b = _normalize(target);
    if (a == b) return 100;
    if (a.contains(b) || b.contains(a)) return 50;
    return 0;
  }

  int _artistScore(String candidate, String target) {
    if (target.isEmpty) return 0;
    final a = _normalize(candidate);
    final b = _normalize(target);
    if (a == b) return 80;
    if (a.contains(b) || b.contains(a)) return 40;
    return 0;
  }

  void dispose() => _client.close();
}
