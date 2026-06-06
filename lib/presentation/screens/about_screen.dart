import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/pixel_logo.dart';
import 'licenses_screen.dart';
import 'contributors_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '1.0.0';
            final build = snapshot.data?.buildNumber ?? '1';
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _PageHeader(
                  title: 'About',
                  onBack: () => Navigator.pop(context),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withAlpha(14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const LogoWithHeadset(size: 104),
                            const SizedBox(height: 18),
                            const Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Version $version ($build)',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _InfoRow(
                        icon: Icons.music_note_rounded,
                        title: 'YouTube Music Streamer',
                        body:
                            'Stream audio from public YouTube playlists, single videos, and mixes.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoRow(
                        icon: Icons.cloud_off_rounded,
                        title: 'Offline-first playback',
                        body:
                            'Downloaded tracks play from local cache before using the network.',
                      ),
                      const SizedBox(height: 14),
                      const _InfoRow(
                        icon: Icons.shield_outlined,
                        title: 'Personal use',
                        body:
                            'For personal, educational use only. Not affiliated with YouTube.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ActionTile(
                  icon: Icons.article_rounded,
                  title: 'Open source licenses',
                  subtitle: 'Flutter, plugins, and package notices',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LicensesScreen()),
                  ),
                ),
                const SizedBox(height: 18),
                _ActionTile(
                  icon: Icons.people_rounded,
                  title: 'Contributors',
                  subtitle: 'Meet the creators behind the app',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContributorsScreen()),
                  ),
                ),
                const SizedBox(height: 18),
                const _ChangelogSection(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChangelogSection extends StatelessWidget {
  const _ChangelogSection();

  static const _items = [
    (
      '1.5.0',
      'Apple Music–style Now Playing overhaul: sheet drag handle, enlarged artwork, bigger title/artist text, negative remaining-time display, and a micro quality/bitrate badge. All action controls (Lyrics, Crossfade, Auto DJ, Save, Queue) consolidated into a single bottom bar. Replaced skip icons with fast-rewind/forward; removed filled-circle play/pause for a flat aesthetic; enlarged secondary control icons to 28 px. Added Auto DJ with five modes (Library Shuffle, Similar Songs, Same Genre, Same Artist, Smart Mix), equal-power crossfade with pitch warping, and persisted mode selection. Apple Music–style synced lyrics with animated active-line highlight, ShaderMask fade edges, and auto-scroll centering. Fixed Recent tab single-track routing, album browse navigation, and single-track playlist direct playback.',
    ),
    (
      '1.4.2',
      'Redesigned the search screen with category-specific parallel searches, standard track tiles, cached network images, and pill-shaped chips. Implemented seamless progress switching between audio and video modes with automatic background audio pausing and video end-progression.',
    ),
    (
      '1.4.1',
      'Fixed background audio playback and track auto-play progression on Android devices, and introduced a toggleable 7-second crossfade feature on the Now Playing screen.',
    ),
    (
      '1.4.0',
      'Added favorite collection support (playlists and albums), fully rebuilt iOS background playback auto-advance and dynamic island integration, resolved layout overflow bugs, and optimized the Now Playing FAB with dynamic sizing.',
    ),
    (
      '1.3.0',
      'Added floating player controls with play/pause and progress seekbar border to FAB, removed mini-player layout, optimized audio quality settings defaults, added geo-restrictions bypass, resolved playlist duration mapping, fixed search playlist navigation, and adjusted artist page layouts.',
    ),
    (
      '1.2.0',
      'Added Apple Music chart shelves with scoped Top 100 songs, album detail playback, recommendation autoplay, cached chart/search lookups, a custom video player, and refreshed About details.',
    ),
    (
      '1.1.0',
      'Improved playlist browsing, downloads, favourites, queue tools, and playback controls.',
    ),
    (
      '1.0.0',
      'Initial Android release for streaming public YouTube playlists, videos, and mixes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'Changelog',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._items.indexed.map((entry) {
            final index = entry.$1;
            final item = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _items.length - 1 ? 0 : 14,
              ),
              child: _ChangelogItem(version: item.$1, body: item.$2),
            );
          }),
        ],
      ),
    );
  }
}

class _ChangelogItem extends StatelessWidget {
  final String version;
  final String body;

  const _ChangelogItem({required this.version, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            version,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            body,
            style: const TextStyle(color: Colors.white54, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF191919),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: onBack,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(color: Colors.white54, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(14)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
