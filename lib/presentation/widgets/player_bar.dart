import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/repeat_mode.dart' as repeat;
import '../providers/player_provider.dart';
import 'queue_sheet.dart';

class PlayerBar extends StatelessWidget {
  final VoidCallback? onTap;

  const PlayerBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (player.currentTrack == null) return const SizedBox.shrink();

        final hasNext =
            player.queue.isNotEmpty &&
            player.currentIndex + 1 < player.queue.length;

        final progress = player.duration.inMilliseconds > 0
            ? (player.position.inMilliseconds / player.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
            : 0.0;
        final bufferProgress = player.duration.inMilliseconds > 0
            ? (player.bufferedPosition.inMilliseconds /
                      player.duration.inMilliseconds)
                  .clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF191919),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: CachedNetworkImage(
                            imageUrl: player.currentTrack!.thumbnailUrl ?? '',
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: const Color(0xFF282828)),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.currentTrack!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              player.currentTrack!.author ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.queue_music_rounded,
                              size: 18,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                builder: (_) => const QueueSheet(),
                              );
                            },
                            tooltip: 'Queue (${player.queue.length})',
                          ),
                          if (player.shuffleMode)
                            Icon(
                              Icons.shuffle,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          if (player.repeatMode !=
                              repeat.PlaybackRepeatMode.none)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                player.repeatMode ==
                                        repeat.PlaybackRepeatMode.one
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          if (player.isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.fast_rewind_rounded),
                              onPressed: player.previous,
                              iconSize: 22,
                            ),
                            IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              onPressed: player.togglePlayPause,
                              iconSize: 34,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            IconButton(
                              icon: const Icon(Icons.fast_forward_rounded),
                              onPressed: hasNext ? () => player.next() : null,
                              iconSize: 22,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      children: [
                        LinearProgressIndicator(
                          value: bufferProgress,
                          minHeight: 3,
                          backgroundColor: Colors.white.withAlpha(18),
                          color: Colors.white.withAlpha(70),
                        ),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  if (player.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        player.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
