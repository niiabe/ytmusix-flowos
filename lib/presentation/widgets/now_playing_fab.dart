import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format_duration.dart';
import '../../domain/entities/video.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';

/// A compact floating button that navigates to the Now Playing screen.
/// Shows the current track thumbnail + animated playback indicator.
class NowPlayingFab extends StatefulWidget {
  final Track? track;
  final bool isPlaying;

  const NowPlayingFab({
    super.key,
    this.track,
    required this.isPlaying,
  });

  @override
  State<NowPlayingFab> createState() => _NowPlayingFabState();
}

class _NowPlayingFabState extends State<NowPlayingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final track = player.currentTrack ?? widget.track;
    final isPlaying = player.isPlaying;
    final position = player.position;
    final duration = player.duration;
    final isLoading = player.isLoading;

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final String durationText;
    if (track != null) {
      final formattedPos = formatDuration(position);
      final formattedDur = formatDuration(duration);
      durationText = '$formattedPos / $formattedDur';
    } else {
      durationText = '';
    }

    return ScaleTransition(
      scale: isPlaying ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
      child: CustomPaint(
        foregroundPainter: BorderProgressPainter(
          progress: progress,
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 2.0,
          borderRadius: 18.0,
        ),
        child: IntrinsicWidth(
          child: Container(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (track != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PlayerScreen()),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: track?.thumbnailUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: track!.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: const Color(0xFF282828)),
                                    errorWidget: (context, url, error) => Container(
                                      color: const Color(0xFF282828),
                                      child: const Icon(Icons.music_note, size: 18),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF222222),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white24,
                                      size: 20,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ?? 'Not Playing',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                track?.author ?? 'Select a song to start',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                              if (durationText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  durationText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: track != null ? player.togglePlayPause : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: track != null
                            ? Colors.white.withAlpha(20)
                            : Colors.white.withAlpha(8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: track != null ? Colors.white : Colors.white24,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class BorderProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  BorderProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 2.0,
    this.borderRadius = 18.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius - inset));
    final path = Path()..addRRect(rrect);

    try {
      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        final drawLength = metric.length * progress.clamp(0.0, 1.0);
        final extractPath = metric.extractPath(0.0, drawLength);
        canvas.drawPath(extractPath, paint);
      }
    } catch (_) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
