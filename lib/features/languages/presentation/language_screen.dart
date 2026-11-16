import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/data/datasources/youtube_datasource.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/features/videos/presentation/video_list_screen.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';
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
    ref.invalidate(languageSectionPreviewsProvider);
    ref.invalidate(youtubeLanguageVideosProvider);
    ref.invalidate(youtubeLanguageSongsProvider);
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
            onViewAll: () => context.openList(
                ListArgs.tracks(s.title, src.languageTracks(lang, s))),
            itemBuilder: (c, items, i) => TrackCard(
                track: items[i],
                onTap: () => actions.playTracks(items, index: i)),
          );
        case SectionKind.artists:
          return AsyncSection<Artist>(
            title: s.title,
            value: ref.watch(languageSectionArtistsProvider(key)),
            height: 150,
            skeletonWidth: 110,
            skeletonCircle: true,
            onRetry: () => ref.invalidate(languageSectionArtistsProvider(key)),
            onViewAll: () => context.openList(
                ListArgs.artists(s.title, src.languageArtists(lang, s))),
            itemBuilder: (c, items, i) => ArtistCard(artist: items[i]),
          );
        case SectionKind.playlists:
          return AsyncSection<Collection>(
            title: s.title,
            value: ref.watch(languageSectionPlaylistsProvider(key)),
            onRetry: () =>
                ref.invalidate(languageSectionPlaylistsProvider(key)),
            onViewAll: () => context.openList(
                ListArgs.collections(s.title, src.languagePlaylists(lang, s))),
            itemBuilder: (c, items, i) =>
                CollectionCard(collection: items[i], width: 140),
          );
        case SectionKind.previews:
          return AsyncSection<Track>(
            title: s.title,
            value: ref.watch(languageSectionPreviewsProvider(key)),
            onRetry: () => ref.invalidate(languageSectionPreviewsProvider(key)),
            onViewAll: () => context.openList(
                ListArgs.tracks(s.title, src.languagePreviews(lang, s))),
            itemBuilder: (c, items, i) => TrackCard(
                track: items[i],
                onTap: () => actions.playTracks(items, index: i)),
          );
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 40,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(lang.label,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText:
                      'Search YouTube songs, movies, ${_languageDramaLabel(lang)}',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  prefixIcon: const Icon(Icons.search),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
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
                    if (mounted) {
                      setState(() => _query = q.length >= 2 ? q : '');
                    }
                  });
                },
              ),
            ),
          ),
          if (ref.read(youtubeProvider).enabled)
            SliverToBoxAdapter(
                child: _LanguageVideoTabs(
                    language: lang, query: _query.isEmpty ? null : _query)),
          if (_query.isNotEmpty)
            ..._results(src.searchAll(_query, language: lang))
          else ...[
            // YouTube music videos: a separate row (YouTube data is never mixed
            // into the other lists). Plays only in the embedded video player.
            if (ref.read(youtubeProvider).enabled)
              SliverToBoxAdapter(
                child: AsyncSection<YouTubeVideo>(
                  title: 'Music videos · YouTube',
                  value: ref.watch(youtubeLanguageVideosProvider(lang)),
                  height: 222,
                  skeletonWidth: 160,
                  onRetry: () =>
                      ref.invalidate(youtubeLanguageVideosProvider(lang)),
                  onViewAll: () => context.openVideoList(VideoListArgs(
                      '${lang.label} music videos', youtubeLanguageQuery[lang]!,
                      language: lang)),
                  itemBuilder: (c, items, i) =>
                      VideoCard(video: items[i], list: items),
                ),
              ),
            // Single songs from YouTube in this language (no compilations).
            if (ref.read(youtubeProvider).enabled)
              SliverToBoxAdapter(
                child: AsyncSection<YouTubeVideo>(
                  title: '${lang.label} songs · YouTube',
                  value: ref.watch(youtubeLanguageSongsProvider(lang)),
                  height: 222,
                  skeletonWidth: 160,
                  onRetry: () =>
                      ref.invalidate(youtubeLanguageSongsProvider(lang)),
                  onViewAll: () => context.openVideoList(VideoListArgs(
                      '${lang.label} songs', youtubeSongQuery[lang]!,
                      language: lang, songs: true)),
                  itemBuilder: (c, items, i) =>
                      VideoCard(video: items[i], list: items),
                ),
              ),
            for (final s in sections) SliverToBoxAdapter(child: section(s)),
            if (hasJamendo)
              SliverToBoxAdapter(
                child: AsyncSection<Track>(
                  title: 'Free ${lang.label} music · Jamendo',
                  value: ref.watch(jamendoLanguageProvider(lang)),
                  onRetry: () => ref.invalidate(jamendoLanguageProvider(lang)),
                  onViewAll: () => context.openList(ListArgs.tracks(
                      'Free ${lang.label} music', src.jamendoLanguage(lang))),
                  itemBuilder: (c, items, i) => TrackCard(
                      track: items[i],
                      onTap: () => actions.playTracks(items, index: i)),
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
          return TrackTile(
              track: state.items[i],
              onTap: () => actions.playTracks(state.items, index: i));
        },
      ),
      pagedFooter<Track>(state, notifier.refresh,
          emptyTitle: 'No ${widget.language.label} songs found',
          emptyIcon: Icons.search_off),
    ];
  }
}

/// A compact YouTube-style tab view. Each tab owns a fresh [VideoResults]
/// instance, so its API request starts only after the user opens that tab.
class _LanguageVideoTabs extends StatelessWidget {
  const _LanguageVideoTabs({required this.language, this.query});

  final MusicLanguage language;
  final String? query;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            height: 540,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      query == null
                          ? 'Browse YouTube'
                          : 'YouTube results for "$query"',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'Music'),
                  const Tab(text: 'Movies'),
                  Tab(text: _languageDramaLabel(language)),
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _videoResults(YouTubeContentType.music),
                  _videoResults(YouTubeContentType.movie),
                  _videoResults(YouTubeContentType.natok),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _videoResults(YouTubeContentType type) => VideoResults(
        key: ValueKey('${language.code}-${type.name}'),
        query: _queryFor(type),
        language: language,
        contentType: type,
      );

  String _queryFor(YouTubeContentType type) {
    if (query == null) return youtubeLanguageContentQuery(language, type);
    if (type != YouTubeContentType.natok) return query!;
    final keyword = switch (language) {
      MusicLanguage.bangla => 'natok',
      MusicLanguage.hindi => 'tv serial',
      MusicLanguage.english => 'drama',
    };
    return '$query $keyword';
  }
}

String _languageDramaLabel(MusicLanguage language) => switch (language) {
      MusicLanguage.bangla => 'Natok',
      MusicLanguage.hindi => 'Serials',
      MusicLanguage.english => 'TV Shows',
    };

class _SourceNote extends StatelessWidget {
  const _SourceNote();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Text(
          'Songs come from Audius, where artists upload their own music. Language is detected from titles and tags, so some songs may be missing or misplaced. YouTube content plays only in the video player while the app is open.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12),
        ),
      );
}
