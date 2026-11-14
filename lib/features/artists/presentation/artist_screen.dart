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

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(id));
    return Scaffold(
      body: artistAsync.when(
        loading: () => const _ArtistSkeleton(),
        error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(artistProvider(id)))),
        data: (artist) => _ArtistBody(artist: artist),
      ),
    );
  }
}

class _ArtistSkeleton extends StatelessWidget {
  const _ArtistSkeleton();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Row(children: [ShimmerBox(width: 84, height: 84, circle: true), SizedBox(width: 16), ShimmerBox(width: 180, height: 20)])),
          for (var i = 0; i < 6; i++) const TileSkeleton(),
        ]),
      );
}

class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = artist.id;
    final src = ref.read(sourcesProvider);
    final actions = ref.read(playbackActionsProvider);
    final popular = ref.watch(artistPopularProvider(id));
    final scheme = Theme.of(context).colorScheme;
    final following = ref.watch(favoritesProvider.select((f) => f.hasArtist(id)));
    final popularTracks = popular.valueOrNull ?? const <Track>[];

    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        expandedHeight: 240,
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(fit: StackFit.expand, children: [
            if (!artist.cover.isEmpty)
              Artwork(image: artist.cover, radius: 0)
            else
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.6), AppColors.accentWarm.withValues(alpha: 0.4)]))),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Artwork(image: artist.avatar, width: 76, circle: true, icon: Icons.person),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(artist.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                    if (artist.verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 20, color: AppColors.accent)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${fmtCount(artist.followers)} followers • ${artist.trackCount} tracks', style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              ),
            ]),
            if (artist.bio != null) ...[const SizedBox(height: 14), ExpandableText(artist.bio!)],
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: PlayShuffleRow(
          onPlay: () => actions.playTracks(popularTracks),
          onShuffle: () => actions.shuffle(popularTracks),
          extras: [
            following
                ? OutlinedButton(onPressed: () => ref.read(favoritesProvider.notifier).toggleArtist(artist), child: const Text('Following'))
                : OutlinedButton(onPressed: () => ref.read(favoritesProvider.notifier).toggleArtist(artist), child: const Text('Follow')),
            const SizedBox(width: 8),
          ],
        ),
      ),
      SliverToBoxAdapter(child: SectionHeader(title: 'Popular tracks', onViewAll: () => context.openList(ListArgs.tracks('${artist.name} · Popular', src.userTracks(id))))),
      popular.when(
        loading: () => SliverList.builder(itemCount: 5, itemBuilder: (_, __) => const TileSkeleton()),
        error: (e, _) => SliverToBoxAdapter(child: SizedBox(height: 140, child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(artistPopularProvider(id))))),
        data: (tracks) => tracks.isEmpty
            ? const SliverToBoxAdapter(child: SizedBox(height: 140, child: EmptyState(icon: Icons.music_off, title: 'No tracks yet')))
            : trackSliver(tracks.take(5).toList(), (i) => actions.playTracks(tracks, index: i)),
      ),
      SliverToBoxAdapter(
        child: AsyncSection<Track>(
          title: 'Latest releases',
          value: ref.watch(artistLatestProvider(id)),
          onRetry: () => ref.invalidate(artistLatestProvider(id)),
          onViewAll: () => context.openList(ListArgs.tracks('${artist.name} · Latest', src.userTracks(id, sort: 'date'))),
          itemBuilder: (c, items, i) => TrackCard(track: items[i], onTap: () => actions.playTracks(items, index: i)),
        ),
      ),
      SliverToBoxAdapter(
        child: AsyncSection<Collection>(
          title: 'Albums',
          value: ref.watch(artistAlbumsProvider(id)),
          onRetry: () => ref.invalidate(artistAlbumsProvider(id)),
          onViewAll: () => context.openList(ListArgs.collections('${artist.name} · Albums', src.userAlbums(id))),
          itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
        ),
      ),
      SliverToBoxAdapter(
        child: AsyncSection<Collection>(
          title: 'Playlists',
          value: ref.watch(artistPlaylistsProvider(id)),
          onRetry: () => ref.invalidate(artistPlaylistsProvider(id)),
          onViewAll: () => context.openList(ListArgs.collections('${artist.name} · Playlists', src.userPlaylists(id))),
          itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }
}
