import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(audiusClientProvider).clearCache();
    for (final p in [trendingProvider, popularProvider, newReleasesProvider, recommendedProvider, popularAlbumsProvider, popularPlaylistsProvider, madeForYouProvider]) {
      ref.invalidate(p);
    }
    ref.invalidate(featuredArtistsProvider);
    await ref.read(trendingProvider.future).then((_) {}, onError: (_) {});
  }

  Widget _trackSection(BuildContext context, WidgetRef ref, String title, FutureProvider<List<Track>> provider,
      PagedSource<Track> viewAll) {
    final actions = ref.read(playbackActionsProvider);
    return AsyncSection<Track>(
      title: title,
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      onViewAll: () => context.openList(ListArgs.tracks(title, viewAll)),
      itemBuilder: (c, items, i) => TrackCard(track: items[i], onTap: () => actions.playTracks(items, index: i)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(playbackActionsProvider);
    final src = ref.read(sourcesProvider);
    final recent = ref.watch(recentProvider);
    final scheme = Theme.of(context).colorScheme;
    final genre = ref.watch(topGenreProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text('What are you in the mood for?', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ]),
                ),
                IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.openDetail('settings')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: InkWell(
                onTap: () => context.go('/search'),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.search, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Songs, artists, albums, playlists', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
            const SectionHeader(title: 'Browse by language'),
            HList(
              height: 92,
              count: MusicLanguage.values.length,
              builder: (c, i) => LanguageCard(language: MusicLanguage.values[i], width: 150, height: 92),
            ),
            if (recent.isNotEmpty) ...[
              SectionHeader(title: 'Recently played', onViewAll: () => context.go('/library')),
              HList(
                height: 210,
                count: recent.length.clamp(0, 12),
                builder: (c, i) => TrackCard(track: recent[i], onTap: () => actions.playTracks(recent, index: i)),
              ),
            ],
            _trackSection(context, ref, 'Trending music', trendingProvider, src.trending()),
            _trackSection(context, ref, 'Popular tracks', popularProvider, src.trending(time: 'allTime')),
            _trackSection(context, ref, 'New releases', newReleasesProvider, src.newReleases()),
            AsyncSection<Artist>(
              title: 'Featured artists',
              value: ref.watch(featuredArtistsProvider),
              height: 150,
              skeletonWidth: 110,
              skeletonCircle: true,
              onRetry: () => ref.invalidate(featuredArtistsProvider),
              itemBuilder: (c, items, i) => ArtistCard(artist: items[i]),
            ),
            AsyncSection<Collection>(
              title: 'Popular albums',
              value: ref.watch(popularAlbumsProvider),
              onRetry: () => ref.invalidate(popularAlbumsProvider),
              onViewAll: () => context.openList(ListArgs.collections('Popular albums', src.popularAlbums())),
              itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
            ),
            _trackSection(context, ref, 'Recommended', recommendedProvider, src.recommended()),
            AsyncSection<Collection>(
              title: 'Popular playlists',
              value: ref.watch(popularPlaylistsProvider),
              onRetry: () => ref.invalidate(popularPlaylistsProvider),
              onViewAll: () => context.openList(ListArgs.collections('Popular playlists', src.popularPlaylists())),
              itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
            ),
            SectionHeader(title: 'Browse by category', onViewAll: () => context.go('/explore')),
            HList(
              height: 92,
              count: Categories.all.length,
              builder: (c, i) => CategoryCard(category: Categories.all[i], width: 150, height: 92),
            ),
            AsyncSection<Track>(
              title: 'Made for you',
              value: ref.watch(madeForYouProvider),
              onRetry: () => ref.invalidate(madeForYouProvider),
              onViewAll: () => context.openList(ListArgs.tracks('Made for you', src.trending(time: 'month', genre: genre))),
              itemBuilder: (c, items, i) => TrackCard(track: items[i], onTap: () => actions.playTracks(items, index: i)),
            ),
          ]),
        ),
      ),
    );
  }
}

class LanguageCard extends StatelessWidget {
  const LanguageCard({super.key, required this.language, this.width, this.height});
  final MusicLanguage language;
  final double? width, height;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.openLanguage(language),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: language.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(
              right: 10,
              bottom: 4,
              child: Text(language.nativeLabel,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.3))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(language.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
          ]),
        ),
      );
}

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, this.width, this.height});
  final Category category;
  final double? width, height;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.openGenre(category),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: category.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(right: -10, bottom: -10, child: Icon(category.icon, size: 72, color: Colors.white.withValues(alpha: 0.25))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(category.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
          ]),
        ),
      );
}
