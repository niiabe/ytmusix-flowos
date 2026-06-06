import 'package:flutter/material.dart';
import 'playback_settings_screen.dart';
import 'youtube_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'about_screen.dart';
import 'auto_dj_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 28),
            _buildSettingsItem(
              context,
              icon: Icons.tune_rounded,
              title: 'Playback',
              subtitle: 'Pre-downloads, audio quality settings',
              page: const PlaybackSettingsScreen(),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.bubble_chart_rounded,
              title: 'Auto DJ',
              subtitle: 'Queue continuation modes and mix tuning',
              page: const AutoDjSettingsScreen(),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.account_circle_rounded,
              title: 'YouTube Account',
              subtitle: 'Login status and preferences',
              page: const YoutubeSettingsScreen(),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.import_export_rounded,
              title: 'Backup & Restore',
              subtitle: 'Export/import playlist configurations',
              page: const BackupSettingsScreen(),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.storage_rounded,
              title: 'Storage & Cache',
              subtitle: 'Cache downloads size, clear downloads',
              page: const StorageSettingsScreen(),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About App',
              subtitle: 'Changelog, licenses, creators',
              page: const AboutScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(14)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
