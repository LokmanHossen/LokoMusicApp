import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/features/home/presentation/home_screen.dart' show CategoryCard, LanguageCard;

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.read(sourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w800))),
      body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: SectionHeader(title: 'Languages')),
        SliverToBoxAdapter(
          child: HList(
            height: 92,
            count: MusicLanguage.values.length,
            builder: (c, i) => LanguageCard(language: MusicLanguage.values[i], width: 150, height: 92),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader(title: 'Genres & moods')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.9),
            itemCount: Categories.all.length,
            itemBuilder: (c, i) => CategoryCard(category: Categories.all[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: AsyncSection<Collection>(
            title: 'Trending playlists',
            value: ref.watch(popularPlaylistsProvider),
            onRetry: () => ref.invalidate(popularPlaylistsProvider),
            onViewAll: () => context.openList(ListArgs.collections('Trending playlists', src.popularPlaylists())),
            itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
          ),
        ),
        SliverToBoxAdapter(
          child: AsyncSection<Collection>(
            title: 'Popular albums',
            value: ref.watch(popularAlbumsProvider),
            onRetry: () => ref.invalidate(popularAlbumsProvider),
            onViewAll: () => context.openList(ListArgs.collections('Popular albums', src.popularAlbums())),
            itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}
