import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

/// Shows an Audius album or playlist (albums are playlists with isAlbum).
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.id, this.initial});
  final String id;
  final Collection? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(collectionProvider(id));
    final tracksAsync = ref.watch(collectionTracksProvider(id));
    final actions = ref.read(playbackActionsProvider);
    final scheme = Theme.of(context).colorScheme;
    final c = detail.valueOrNull ?? initial;
    final tracks = tracksAsync.valueOrNull ?? const <Track>[];
    final fav = c == null ? false : ref.watch(favoritesProvider.select((f) => f.hasCollection(c.id)));

    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: detail.hasError
            ? ErrorState(message: detail.error.toString(), onRetry: () => ref.invalidate(collectionProvider(id)))
            : ListView(children: [const SizedBox(height: 16), for (var i = 0; i < 6; i++) const TileSkeleton()]),
      );
    }

    final totalSeconds = tracks.fold<int>(0, (a, t) => a + t.duration);
    final meta = [
      c.isAlbum ? 'Album' : 'Playlist',
      '${tracks.isNotEmpty ? tracks.length : c.trackCount} tracks',
      if (totalSeconds > 0) fmtTotal(totalSeconds),
      if (fmtDate(c.releaseDate).isNotEmpty) fmtDate(c.releaseDate),
    ].join(' • ');

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(pinned: true, title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 12))]),
                  child: Artwork(image: c.art, radius: 18, icon: c.isAlbum ? Icons.album : Icons.queue_music),
                ),
              ),
              const SizedBox(height: 20),
              Text(c.name,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              InkWell(
                onTap: c.owner.id.isEmpty ? null : () => context.openArtist(c.owner.id),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.owner.name, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                  if (c.owner.verified)
                    const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.accent)),
                ]),
              ),
              const SizedBox(height: 4),
              Text(meta, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              if (c.description != null) ...[const SizedBox(height: 10), ExpandableText(c.description!, maxLines: 2)],
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: PlayShuffleRow(
            onPlay: () => actions.playTracks(tracks),
            onShuffle: () => actions.shuffle(tracks),
            extras: [
              IconButton(
                tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => ref.read(favoritesProvider.notifier).toggleCollection(c),
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? AppColors.accentWarm : null),
              ),
              IconButton(tooltip: 'Add to queue', onPressed: () => actions.addAllToQueue(tracks), icon: const Icon(Icons.queue_music)),
              IconButton(
                  tooltip: 'Save to my playlist',
                  onPressed: tracks.isEmpty ? null : () => showAddToPlaylistSheet(context, ref, tracks),
                  icon: const Icon(Icons.playlist_add)),
            ],
          ),
        ),
        tracksAsync.when(
          loading: () => SliverList.builder(itemCount: 6, itemBuilder: (_, __) => const TileSkeleton()),
          error: (e, _) => SliverFillRemaining(
              hasScrollBody: false, child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(collectionTracksProvider(id)))),
          data: (list) => list.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.music_off, title: 'No playable tracks', message: 'Tracks may be hidden or unavailable.'))
              : trackSliver(list, (i) => actions.playTracks(list, index: i), numbered: true),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}
