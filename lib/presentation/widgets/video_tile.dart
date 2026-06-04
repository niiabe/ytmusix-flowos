import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../core/utils/format_duration.dart';
import '../../domain/entities/video.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback? onDownload;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onMore;

  const TrackTile({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.onTap,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.onDownload,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final player = isCurrent ? context.watch<PlayerProvider>() : null;
    final progress = (player != null && player.duration.inMilliseconds > 0)
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary.withAlpha(80)
              : Colors.white.withAlpha(12),
        ),
      ),
      child: Stack(
        children: [
          if (isCurrent)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    color: Theme.of(context).colorScheme.primary.withAlpha(28),
                  ),
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: CachedNetworkImage(
                  imageUrl: track.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: const Color(0xFF282828)),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.music_video_rounded, color: Colors.grey),
                ),
              ),
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isCurrent ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            subtitle: Text(
              '${track.author ?? 'Unknown'} · ${formatDuration(track.duration)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleFavorite != null)
                  IconButton(
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: isFavorite ? const Color(0xFFFF7FA4) : null,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onToggleFavorite,
                  ),
                if (isCurrent && player != null)
                  Icon(
                    player.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  )
                else if (isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isDownloaded)
                  const Icon(
                    Icons.offline_pin_rounded,
                    size: 18,
                    color: Colors.greenAccent,
                  )
                else if (onDownload != null)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDownload,
                  ),
                if (onMore != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onMore,
                  ),
              ],
            ),
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
