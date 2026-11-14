import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

/// Reusable "view all" screen for tracks, albums/playlists or artists.
class ListScreen extends StatelessWidget {
  const ListScreen({super.key, required this.args});
  final ListArgs args;

  @override
  Widget build(BuildContext context) {
    if (args.tracks != null) return _TracksList(title: args.title, source: args.tracks!);
    if (args.collections != null) return _CollectionsGrid(title: args.title, source: args.collections!);
    return _ArtistsList(title: args.title, source: args.artists!);
  }
}

class _TracksList extends ConsumerWidget {
  const _TracksList({required this.title, required this.source});
  final String title;
  final PagedSource<Track> source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedTracksProvider(source));
    final notifier = ref.read(pagedTracksProvider(source).notifier);
    final actions = ref.read(playbackActionsProvider);
    return Scaffold(
      body: InfiniteScroll(
        onEnd: notifier.loadMore,
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(slivers: [
            SliverAppBar(pinned: true, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (state.items.isNotEmpty)
              SliverToBoxAdapter(
                child: PlayShuffleRow(onPlay: () => actions.playTracks(state.items), onShuffle: () => actions.shuffle(state.items)),
              ),
            trackSliver(state.items, (i) => actions.playTracks(state.items, index: i)),
            pagedFooter<Track>(state, notifier.refresh, emptyTitle: 'No tracks found'),
          ]),
        ),
      ),
    );
  }
}

class _CollectionsGrid extends ConsumerWidget {
  const _CollectionsGrid({required this.title, required this.source});
  final String title;
  final PagedSource<Collection> source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedCollectionsProvider(source));
    final notifier = ref.read(pagedCollectionsProvider(source).notifier);
    return Scaffold(
      body: InfiniteScroll(
        onEnd: notifier.loadMore,
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(slivers: [
            SliverAppBar(pinned: true, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: 0.78),
                itemCount: state.items.length,
                itemBuilder: (c, i) => CollectionCard(collection: state.items[i]),
              ),
            ),
            pagedFooter<Collection>(state, notifier.refresh, emptyTitle: 'Nothing found', emptyIcon: Icons.album_outlined),
          ]),
        ),
      ),
    );
  }
}

class _ArtistsList extends ConsumerWidget {
  const _ArtistsList({required this.title, required this.source});
  final String title;
  final PagedSource<Artist> source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedArtistsProvider(source));
    final notifier = ref.read(pagedArtistsProvider(source).notifier);
    return Scaffold(
      body: InfiniteScroll(
        onEnd: notifier.loadMore,
        child: CustomScrollView(slivers: [
          SliverAppBar(pinned: true, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          SliverList.builder(itemCount: state.items.length, itemBuilder: (c, i) => ArtistTile(artist: state.items[i])),
          pagedFooter<Artist>(state, notifier.refresh, emptyTitle: 'No artists found', emptyIcon: Icons.person_search),
        ]),
      ),
    );
  }
}
