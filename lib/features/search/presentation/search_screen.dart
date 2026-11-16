import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/data/datasources/youtube_datasource.dart';
import 'package:pulse_music/features/videos/presentation/video_list_screen.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _text = '';
  String _query = '';
  String? _genre;
  MusicLanguage? _language;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _commit(String value, {bool save = false}) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _query = q.length >= 2 ? q : '');
    if (save) ref.read(searchHistoryProvider.notifier).add(q);
  }

  void _pick(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _text = q);
    _commit(q, save: true);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search tracks, artists, albums, playlists',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _text = '');
                          _commit('');
                        }),
              ),
              onChanged: (v) {
                setState(() => _text = v);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) _commit(v);
                });
              },
              onSubmitted: (v) => _commit(v, save: true),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        avatar: const Icon(Icons.translate, size: 18),
                        label: const Text('All languages'),
                        selected: _language == null,
                        onSelected: (_) => setState(() => _language = null)),
                  ),
                  for (final l in MusicLanguage.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(l == MusicLanguage.english
                              ? l.label
                              : '${l.label} · ${l.nativeLabel}'),
                          selected: _language == l,
                          onSelected: (s) =>
                              setState(() => _language = s ? l : null)),
                    ),
                ]),
          ),
          SizedBox(
            height: 48,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: const Text('All genres'),
                        selected: _genre == null,
                        onSelected: (_) => setState(() => _genre = null)),
                  ),
                  for (final g in searchGenres)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                          label: Text(g),
                          selected: _genre == g,
                          onSelected: (s) =>
                              setState(() => _genre = s ? g : null)),
                    ),
                ]),
          ),
          Expanded(
            child: _query.isEmpty
                ? _Suggestions(text: _text, onPick: _pick)
                : _Results(
                    query: _query,
                    genre: _genre,
                    language: _language,
                    onPlayed: () =>
                        ref.read(searchHistoryProvider.notifier).add(_query)),
          ),
        ]),
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.text, required this.onPick});
  final String text;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final typed = text.trim().toLowerCase();
    final items = typed.isEmpty
        ? history
        : history.where((h) => h.toLowerCase().contains(typed)).toList();
    if (history.isEmpty && typed.isEmpty) {
      return const EmptyState(
          icon: Icons.search,
          title: 'Find your next favorite',
          message: 'Search across tracks, artists, albums and playlists.');
    }
    return ListView(children: [
      if (typed.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            Expanded(
                child: Text('Recent searches',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: ref.read(searchHistoryProvider.notifier).clear,
                child: const Text('Clear all')),
          ]),
        ),
      for (final h in items)
        ListTile(
          leading: Icon(typed.isEmpty ? Icons.history : Icons.search),
          title: Text(h),
          onTap: () => onPick(h),
          trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(searchHistoryProvider.notifier).remove(h)),
        ),
      if (typed.isNotEmpty && items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Keep typing to search…'))),
    ]);
  }
}

class _Results extends ConsumerWidget {
  const _Results(
      {required this.query,
      required this.genre,
      required this.language,
      required this.onPlayed});
  final String query;
  final String? genre;
  final MusicLanguage? language;
  final VoidCallback onPlayed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.read(sourcesProvider);
    final videos = ref.read(youtubeProvider).enabled;
    return DefaultTabController(
      length: videos ? 8 : 4,
      child: Column(children: [
        TabBar(
          isScrollable: videos,
          tabAlignment: videos ? TabAlignment.start : null,
          tabs: [
            const Tab(text: 'Tracks'),
            const Tab(text: 'Artists'),
            const Tab(text: 'Albums'),
            const Tab(text: 'Playlists'),
            if (videos) const Tab(text: 'Videos'),
            if (videos) const Tab(text: 'Songs'),
            if (videos) const Tab(text: 'Movies'),
            if (videos) const Tab(text: 'Natok'),
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            // Tracks: all providers, merged and de-duplicated.
            _TrackResults(
                source: src.searchAll(query, genre: genre, language: language),
                onPlayed: onPlayed),
            // Artist names say little about language, so artists are not filtered.
            _ArtistResults(source: src.searchArtists(query)),
            _CollectionResults(
                source: src.searchAlbumsIn(query, language),
                emptyTitle: 'No albums found',
                icon: Icons.album_outlined),
            _CollectionResults(
                source: src.searchPlaylistsIn(query, language),
                emptyTitle: 'No playlists found',
                icon: Icons.queue_music),
            // YouTube results stay separate from audio results. The tabs use
            // their appropriate category/query treatment and open only in the
            // embedded YouTube player.
            if (videos)
              VideoResults(
                  query: query,
                  language: language,
                  contentType: YouTubeContentType.all),
            if (videos)
              VideoResults(
                query: query,
                language: language,
                songs: true,
                contentType: YouTubeContentType.music,
              ),
            if (videos)
              VideoResults(
                  query: query,
                  language: language,
                  contentType: YouTubeContentType.movie),
            if (videos)
              VideoResults(
                query: '$query natok',
                language: language,
                contentType: YouTubeContentType.natok,
              ),
          ]),
        ),
      ]),
    );
  }
}

class _TrackResults extends ConsumerWidget {
  const _TrackResults({required this.source, required this.onPlayed});
  final PagedSource<Track> source;
  final VoidCallback onPlayed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedTracksProvider(source));
    final notifier = ref.read(pagedTracksProvider(source).notifier);
    final actions = ref.read(playbackActionsProvider);
    return InfiniteScroll(
      onEnd: notifier.loadMore,
      child: CustomScrollView(slivers: [
        trackSliver(state.items, (i) {
          onPlayed();
          actions.playTracks(state.items, index: i);
        }),
        pagedFooter<Track>(state, notifier.refresh,
            emptyTitle: 'No tracks found', emptyIcon: Icons.search_off),
      ]),
    );
  }
}

class _ArtistResults extends ConsumerWidget {
  const _ArtistResults({required this.source});
  final PagedSource<Artist> source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedArtistsProvider(source));
    final notifier = ref.read(pagedArtistsProvider(source).notifier);
    return InfiniteScroll(
      onEnd: notifier.loadMore,
      child: CustomScrollView(slivers: [
        SliverList.builder(
            itemCount: state.items.length,
            itemBuilder: (c, i) => ArtistTile(artist: state.items[i])),
        pagedFooter<Artist>(state, notifier.refresh,
            emptyTitle: 'No artists found', emptyIcon: Icons.person_search),
      ]),
    );
  }
}

class _CollectionResults extends ConsumerWidget {
  const _CollectionResults(
      {required this.source, required this.emptyTitle, required this.icon});
  final PagedSource<Collection> source;
  final String emptyTitle;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pagedCollectionsProvider(source));
    final notifier = ref.read(pagedCollectionsProvider(source).notifier);
    return InfiniteScroll(
      onEnd: notifier.loadMore,
      child: CustomScrollView(slivers: [
        SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (c, i) {
            final item = state.items[i];
            return ListTile(
              onTap: () => context.openCollection(item),
              leading:
                  Artwork(image: item.art, width: 52, radius: 8, icon: icon),
              title: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${item.owner.name} • ${item.trackCount} tracks'),
            );
          },
        ),
        pagedFooter<Collection>(state, notifier.refresh,
            emptyTitle: emptyTitle, emptyIcon: icon),
      ]),
    );
  }
}
