import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/audio_repository.dart';
import 'domain/repositories/playlist_repository.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'service/audio_handler.dart';
import 'presentation/screens/home_screen.dart';

class YTMusixApp extends StatelessWidget {
  final PlaylistRepository playlistRepository;
  final AudioRepository audioRepository;
  final DownloadProvider downloadProvider;
  final SettingsProvider settingsProvider;
  final MusicAudioHandler audioHandler;

  const YTMusixApp({
    super.key,
    required this.playlistRepository,
    required this.audioRepository,
    required this.downloadProvider,
    required this.settingsProvider,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(
          create: (_) => PlaylistProvider(playlistRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => PlayerProvider(
            audioRepository,
            downloadProvider: downloadProvider,
            settingsProvider: settingsProvider,
          )..setAudioHandler(audioHandler),
        ),
        ChangeNotifierProvider.value(
          value: downloadProvider,
        ),
      ],
      child: MaterialApp(
        title: 'YTMusix',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
