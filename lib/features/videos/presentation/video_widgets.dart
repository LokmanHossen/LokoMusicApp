import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/data/models/youtube_video.dart';

/// Opens [video] in the full-screen embedded YouTube player.
/// What the player shows: the video and the list it was opened from (shown
/// below the player as "More videos" and used to auto-play the next one).
typedef VideoPlayArgs = ({YouTubeVideo video, List<YouTubeVideo> list});

/// Opens [video] in the full-screen embedded YouTube player.
void openVideo(BuildContext context, YouTubeVideo video, {List<YouTubeVideo> list = const []}) =>
    context.push('/video', extra: (video: video, list: list.isEmpty ? [video] : list));

/// Small "YouTube" attribution tag (YouTube's branding rules require the
/// source to be identified wherever its content appears).
class YouTubeTag extends StatelessWidget {
  const YouTubeTag({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.smart_display, size: 14, color: Color(0xFFFF0033)),
        const SizedBox(width: 4),
        Text('YouTube', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);
}

/// 16:9 thumbnail with the video length, title and channel.
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.width = 240, this.list = const [], this.onTap});
  final YouTubeVideo video;

  /// The list [video] belongs to (passed to the player).
  final List<YouTubeVideo> list;

  /// Overrides the default (open the player), e.g. inside the player itself.
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap ?? () => openVideo(context, video, list: list),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                if (video.thumbnail != null)
                  CachedNetworkImage(
                    imageUrl: video.thumbnail!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(color: scheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => ColoredBox(color: scheme.surfaceContainerHighest),
                  )
                else
                  ColoredBox(color: scheme.surfaceContainerHighest),
                const Center(child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white70)),
                if (video.durationSeconds > 0)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text(fmtDuration(video.durationSeconds), style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2)),
          const SizedBox(height: 2),
          Row(children: [
            Flexible(
              child: Text(video.channel,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 6),
            const YouTubeTag(),
          ]),
        ]),
      ),
    );
  }
}

/// Row-style video entry for full lists.
class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.video, this.list = const [], this.onTap, this.selected = false});
  final YouTubeVideo video;

  /// The list [video] belongs to (passed to the player).
  final List<YouTubeVideo> list;

  /// Overrides the default (open the player), e.g. inside the player itself.
  final VoidCallback? onTap;

  /// Highlights the row (the video now playing).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap ?? () => openVideo(context, video, list: list),
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 140,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  if (video.thumbnail != null) CachedNetworkImage(imageUrl: video.thumbnail!, fit: BoxFit.cover),
                  if (video.durationSeconds > 0)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                        child: Text(fmtDuration(video.durationSeconds), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(video.channel,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              const YouTubeTag(),
            ]),
          ),
        ]),
      ),
    );
  }
}
