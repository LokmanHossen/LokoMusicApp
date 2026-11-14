import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

/// Discovery page for one language: its sections, an optional Jamendo row and
/// a search box that searches only within the language.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key, required this.language});
  final MusicLanguage language;

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(audiusClientProvider).clearCache();
    ref.invalidate(languageSectionTracksProvider);
    ref.invalidate(languageSectionArtistsProvider);
    ref.invalidate(languageSectionPlaylistsProvider);
    ref.invalidate(jamendoLanguageProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.language;
    final sections = languageSections[lang] ?? const [];
    final src = ref.read(sourcesProvider);
    final actions = ref.read(playbackActionsProvider);
    final hasJamendo = ref.read(musicRepositoryProvider).hasJamendo;

    Widget section(LanguageSection s) {
      final key = (lang, s);
      switch (s.kind) {
        case SectionKind.tracks:
          return AsyncSection<Track>(
            title: s.title,
            value: ref.watch(languageSectionTracksProvider(key)),
            onRetry: () => ref.invalidate(languageSectionTracksProvider(key)),
            onViewAll: () => context.openList(ListArgs.tracks(s.title, src.languageTracks(lang, s))),
            itemBuilder: (c, items, i) => TrackCard(track: items[i], onTap: () => actions.playTracks(items, index: i)),
          );
        case SectionKind.artists:
          return AsyncSection<Artist>(
            title: s.title,
            value: ref.watch(languageSectionArtistsProvider(key)),
            height: 150,
            skeletonWidth: 110,
            skeletonCircle: true,
            onRetry: () => ref.invalidate(languageSectionArtistsProvider(key)),
            onViewAll: () => context.openList(ListArgs.artists(s.title, src.languageArtists(lang, s))),
            itemBuilder: (c, items, i) => ArtistCard(artist: items[i]),
          );
        case SectionKind.playlists:
          return AsyncSection<Collection>(
            title: s.title,
            value: ref.watch(languageSectionPlaylistsProvider(key)),
            onRetry: () => ref.invalidate(languageSectionPlaylistsProvider(key)),
            onViewAll: () => context.openList(ListArgs.collections(s.title, src.languagePlaylists(lang, s))),
            itemBuilder: (c, items, i) => CollectionCard(collection: items[i], width: 140),
          );
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(lang.label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              background: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: lang.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(lang.nativeLabel, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white24)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search ${lang.label} songs',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          }),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    final q = v.trim();
                    if (mounted) setState(() => _query = q.length >= 2 ? q : '');
                  });
                },
              ),
            ),
          ),
          if (_query.isNotEmpty)
            ..._results(src.searchAll(_query, language: lang))
          else ...[
            for (final s in sections) SliverToBoxAdapter(child: section(s)),
            if (hasJamendo)
              SliverToBoxAdapter(
                child: AsyncSection<Track>(
                  title: 'Free ${lang.label} music · Jamendo',
                  value: ref.watch(jamendoLanguageProvider(lang)),
                  onRetry: () => ref.invalidate(jamendoLanguageProvider(lang)),
                  onViewAll: () => context.openList(ListArgs.tracks('Free ${lang.label} music', src.jamendoLanguage(lang))),
                  itemBuilder: (c, items, i) => TrackCard(track: items[i], onTap: () => actions.playTracks(items, index: i)),
                ),
              ),
            const SliverToBoxAdapter(child: _SourceNote()),
          ],
        ]),
      ),
    );
  }

  List<Widget> _results(PagedSource<Track> source) {
    final state = ref.watch(pagedTracksProvider(source));
    final notifier = ref.read(pagedTracksProvider(source).notifier);
    final actions = ref.read(playbackActionsProvider);
    return [
      SliverToBoxAdapter(child: SectionHeader(title: 'Results for "$_query"')),
      SliverList.builder(
        itemCount: state.items.length,
        itemBuilder: (c, i) {
          // Near the end: fetch the next page (loadMore ignores repeat calls).
          if (i >= state.items.length - 3) Future.microtask(notifier.loadMore);
          return TrackTile(track: state.items[i], onTap: () => actions.playTracks(state.items, index: i));
        },
      ),
      pagedFooter<Track>(state, notifier.refresh, emptyTitle: 'No ${widget.language.label} songs found', emptyIcon: Icons.search_off),
    ];
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Text(
          'Songs come from Audius, where artists upload their own music. Language is detected from titles and tags, so some songs may be missing or misplaced.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      );
}
