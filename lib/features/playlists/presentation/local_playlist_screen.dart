import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class LocalPlaylistScreen extends ConsumerWidget {
  const LocalPlaylistScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(localPlaylistsProvider);
    final matches = lists.where((p) => p.id == id);
    final actions = ref.read(playbackActionsProvider);
    final notifier = ref.read(localPlaylistsProvider.notifier);
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.playlist_remove, title: 'Playlist not found'));
    }
    final p = matches.first;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await askText(context, title: 'Rename playlist', initial: p.name);
                  if (name != null && name.isNotEmpty) notifier.rename(p.id, name);
                } else if (v == 'delete') {
                  notifier.delete(p.id);
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Artwork(image: p.tracks.isEmpty ? null : p.tracks.first.art, width: 96, icon: Icons.queue_music),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text('${p.tracks.length} tracks${p.totalSeconds > 0 ? ' • ${fmtTotal(p.totalSeconds)}' : ''}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: PlayShuffleRow(
            onPlay: () => actions.playTracks(p.tracks),
            onShuffle: () => actions.shuffle(p.tracks),
            extras: [
              IconButton(tooltip: 'Add to queue', onPressed: () => actions.addAllToQueue(p.tracks), icon: const Icon(Icons.queue_music))
            ],
          ),
        ),
        if (p.tracks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
                icon: Icons.library_add_outlined, title: 'This playlist is empty', message: 'Use "Add to playlist" from any track menu.'),
          )
        else
          trackSliver(p.tracks, (i) => actions.playTracks(p.tracks, index: i), onRemove: (Track t) => notifier.removeTrack(p.id, t.id)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}
