import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();
    final playing = ref.watch(isPlayingProvider);
    final buffering = ref.watch(isBufferingProvider);
    final scheme = Theme.of(context).colorScheme;
    final handler = ref.read(audioHandlerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/player'),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
              child: Row(children: [
                Artwork(image: track.art, width: 44, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(track.artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ]),
                ),
                if (buffering)
                  const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                else
                  IconButton(
                    tooltip: playing ? 'Pause' : 'Play',
                    iconSize: 30,
                    onPressed: () => ref.read(playbackActionsProvider).togglePlay(),
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                IconButton(tooltip: 'Next', onPressed: handler.skipToNext, icon: const Icon(Icons.skip_next_rounded)),
                IconButton(
                  tooltip: 'Close player',
                  onPressed: () async {
                    // stop() also ends the background service and its notification;
                    // clearQueue() empties the queue, which hides this bar.
                    await handler.stop();
                    await handler.clearQueue();
                  },
                  icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
            _MiniProgress(durationSeconds: track.duration),
          ]),
        ),
      ),
    );
  }
}

class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.durationSeconds});
  final int durationSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final value = durationSeconds > 0 ? (pos.inMilliseconds / (durationSeconds * 1000)).clamp(0.0, 1.0) : null;
    return LinearProgressIndicator(
      value: value,
      minHeight: 2.5,
      backgroundColor: Colors.transparent,
      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
    );
  }
}
