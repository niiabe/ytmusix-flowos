import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'app.dart';
import 'data/datasources/local/playlist_database.dart';
import 'data/datasources/remote/youtube_remote_datasource.dart';
import 'data/repositories/audio_repository_impl.dart';
import 'data/repositories/playlist_repository_impl.dart';
import 'service/auth_service.dart';
import 'service/audio_handler.dart';
import 'service/download_service.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    final authService = AuthService();
    final remoteDataSource = YoutubeRemoteDataSource(authService: authService);
    await remoteDataSource.init();
    final localDatabase = PlaylistDatabase();
    final playlistRepository = PlaylistRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDatabase: localDatabase,
    );

    final settingsProvider = SettingsProvider();
    await settingsProvider.load();

    final audioHandler = await AudioService.init(
      builder: () => MusicAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'ytmusix_music',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: true,
        androidNotificationClickStartsActivity: true,
      ),
    );

    final audioRepository = AudioRepositoryImpl(
      remoteDataSource: remoteDataSource,
      handler: audioHandler,
      database: localDatabase,
    );

    final downloadService = DownloadService(
      remoteDataSource: remoteDataSource,
      database: localDatabase,
    );
    final downloadProvider = DownloadProvider(downloadService);
    await downloadProvider.init();

    runApp(YTMusixApp(
      playlistRepository: playlistRepository,
      audioRepository: audioRepository,
      downloadProvider: downloadProvider,
      settingsProvider: settingsProvider,
      audioHandler: audioHandler,
    ));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to initialize: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        theme: ThemeData.dark(),
      ),
    );
  }
}
