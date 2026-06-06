import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/audio_quality.dart';
import '../providers/settings_provider.dart';
import '../../service/keep_alive_service.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _buildPageHeader(context),
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
                      _buildPrebufferSlider(settings),
                      const SizedBox(height: 28),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 18),
                      _buildQualitySelector(context, settings),
                    ],
                  ),
                ),
                if (KeepAliveService.isAndroidPlatform) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withAlpha(14)),
                    ),
                    child: const _AndroidBackgroundSettings(),
                  ),
                ],
              ],
            );
          },
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
          'Playback',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildPrebufferSlider(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pre-download ahead tracks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            Text(
              '${settings.prebufferCount}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: settings.prebufferCount.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) => settings.setPrebufferCount(v.round()),
        ),
        Text(
          'Number of upcoming tracks to pre-download (0 = disabled)',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildQualitySelector(BuildContext context, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Audio quality',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AudioQuality.values.map((quality) {
            final isSelected = settings.audioQuality == quality;
            return ChoiceChip(
              selected: isSelected,
              label: Text(_qualityLabel(quality)),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.white.withAlpha(12),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withAlpha(18),
                ),
              ),
              onSelected: (_) => settings.setAudioQuality(quality),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text(
          _qualityDescription(settings.audioQuality),
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }

  String _qualityLabel(AudioQuality q) {
    switch (q) {
      case AudioQuality.low:
        return 'Low (~64 kbps)';
      case AudioQuality.medium:
        return 'Medium (~128 kbps)';
      case AudioQuality.high:
        return 'High (best available)';
    }
  }

  String _qualityDescription(AudioQuality q) {
    switch (q) {
      case AudioQuality.low:
        return 'Uses less data, fastest loading';
      case AudioQuality.medium:
        return 'Balanced quality and data usage';
      case AudioQuality.high:
        return 'Best audio quality, more data usage';
    }
  }
}

class _AndroidBackgroundSettings extends StatefulWidget {
  const _AndroidBackgroundSettings();

  @override
  State<_AndroidBackgroundSettings> createState() =>
      __AndroidBackgroundSettingsState();
}

class __AndroidBackgroundSettingsState
    extends State<_AndroidBackgroundSettings> {
  bool _isOptimized = true;
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final disabled = await KeepAliveService.isBatteryOptimizationDisabled();
    final running = await KeepAliveService.isKeepAliveServiceRunning();
    if (mounted) {
      setState(() {
        _isOptimized = !disabled;
        _isServiceRunning = running;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Android Background Performance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Keep-Alive Service',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: const Text(
            'Keep a persistent foreground service active to prevent playback crashes',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Switch(
            value: _isServiceRunning,
            onChanged: (value) async {
              if (value) {
                await KeepAliveService.startKeepAliveService();
              } else {
                await KeepAliveService.stopKeepAliveService();
              }
              _checkStatus();
            },
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Battery Optimization',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            _isOptimized
                ? 'Status: Optimized (may terminate playback in background)'
                : 'Status: Unrestricted (recommended)',
            style: TextStyle(
              color: _isOptimized ? Colors.amber[400] : Colors.green[400],
              fontSize: 12,
            ),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOptimized
                  ? Colors.white.withAlpha(14)
                  : Colors.green.withAlpha(24),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () async {
              if (_isOptimized) {
                await KeepAliveService.requestDisableBatteryOptimization();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Battery optimization is already disabled. Opening system settings...'),
                  ),
                );
                await KeepAliveService.requestDisableBatteryOptimization();
              }
              Future.delayed(const Duration(seconds: 2), _checkStatus);
            },
            child: Text(
              _isOptimized ? 'Disable' : 'Disabled',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
