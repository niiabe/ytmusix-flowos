import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AutoDjSettingsScreen extends StatelessWidget {
  const AutoDjSettingsScreen({super.key});

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

                // Mode selector card
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
                      const Text(
                        'Auto DJ Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select how the queue will continue when it ends',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      _buildModeChips(context, settings),
                      const SizedBox(height: 18),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 14),
                      _buildModeDescription(settings.autoDjMode),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Songs count card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Continuation Songs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${settings.autoDjSongsCount}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Number of songs to append automatically',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Slider(
                        value: settings.autoDjSongsCount.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Colors.white.withAlpha(12),
                        onChanged: settings.autoDjMode == 'off'
                            ? null
                            : (v) => settings.setAutoDjSongsCount(v.round()),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Trigger threshold card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Top-up Threshold',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${settings.autoDjThreshold}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.autoDjThreshold == 1
                            ? 'Append when 1 song remains in the queue'
                            : 'Append when ${settings.autoDjThreshold} songs remain in the queue',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Slider(
                        value: settings.autoDjThreshold.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Colors.white.withAlpha(12),
                        onChanged: settings.autoDjMode == 'off'
                            ? null
                            : (v) => settings.setAutoDjThreshold(v.round()),
                      ),
                    ],
                  ),
                ),
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
          'Auto DJ',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildModeChips(BuildContext context, SettingsProvider settings) {
    final modes = [
      ('off', 'Off'),
      ('shuffleLibrary', 'Library Shuffle'),
      ('similarSongs', 'Similar Songs'),
      ('sameGenre', 'Same Genre'),
      ('sameArtist', 'Same Artist'),
      ('smartMix', 'Smart Mix'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((mode) {
        final isSelected = settings.autoDjMode == mode.$1;
        return ChoiceChip(
          selected: isSelected,
          label: Text(mode.$2),
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
          onSelected: (_) => settings.setAutoDjMode(mode.$1),
        );
      }).toList(),
    );
  }

  Widget _buildModeDescription(String mode) {
    String desc = '';
    IconData icon = Icons.info_outline_rounded;

    switch (mode) {
      case 'off':
        desc = 'Playback stops when the queue ends.';
        icon = Icons.power_settings_new_rounded;
        break;
      case 'shuffleLibrary':
        desc =
            'Picks random tracks from your favorites, downloads, and local playlists.';
        icon = Icons.shuffle_rounded;
        break;
      case 'similarSongs':
        desc =
            'Finds and appends track recommendations dynamically using YouTube Music.';
        icon = Icons.graphic_eq_rounded;
        break;
      case 'sameGenre':
        desc =
            'Analyzes vibe/genre and searches YouTube to keep playing related styles.';
        icon = Icons.category_rounded;
        break;
      case 'sameArtist':
        desc =
            'Continues playing top hits and popular tracks from the current artist.';
        icon = Icons.person_rounded;
        break;
      case 'smartMix':
        desc =
            'Personalized automatic smart mix based on listening habits, similar vibes, and releases.';
        icon = Icons.bubble_chart_rounded;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
