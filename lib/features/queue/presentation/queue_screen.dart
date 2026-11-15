import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/services/audio_player_service.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(queueProvider).valueOrNull ?? const <MediaItem>[];
    final current = ref.watch(playbackStateProvider).valueOrNull?.queueIndex ?? -1;
    final handler = ref.read(audioHandlerProvider);
    final playing = ref.watch(isPlayingProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => context.pop()),
        title: Text('Queue (${items.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: 'Shuffle queue', icon: const Icon(Icons.shuffle), onPressed: items.length < 2 ? null : handler.shuffleQueue),
          IconButton(
            tooltip: 'Clear queue',
            icon: const Icon(Icons.clear_all),
            onPressed: items.isEmpty
                ? null
                : () async {
                    await handler.clearQueue();
                    if (context.mounted) context.pop();
                  },
          ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.queue_music, title: 'Your queue is empty', message: 'Use "Play next" or "Add to queue" on any track.')
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                handler.moveItem(oldIndex, newIndex);
              },
              itemBuilder: (context, i) {
                final track = trackFromItem(items[i]);
                final isCurrent = i == current;
                return Dismissible(
                  key: ValueKey('q-$i-${track.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      color: scheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline)),
                  onDismissed: (_) => handler.removeAt(i),
                  child: ListTile(
                    tileColor: isCurrent ? AppColors.accent.withValues(alpha: 0.12) : null,
                    onTap: () => handler.skipToQueueItem(i),
                    leading: Stack(alignment: Alignment.center, children: [
                      Artwork(image: track.art, width: 48, radius: 8),
                      if (isCurrent)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: Icon(playing ? Icons.graphic_eq : Icons.pause, color: AppColors.accent),
                        ),
                    ]),
                    title: Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? AppColors.accent : null)),
                    subtitle: Text('${track.artist.name}${track.duration > 0 ? ' • ${fmtDuration(track.duration)}' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: ReorderableDragStartListener(
                        index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle))),
                  ),
                );
              },
            ),
    );
  }
}
