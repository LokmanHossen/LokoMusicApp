import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class GenreScreen extends ConsumerStatefulWidget {
  const GenreScreen({super.key, required this.category});
  final Category category;

  @override
  ConsumerState<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends ConsumerState<GenreScreen> {
  static const _sorts = {'week': 'This week', 'month': 'This month', 'allTime': 'All time'};
  String _time = 'week';
  String _query = '';
  Timer? _debounce;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  PagedSource<Track> _source() {
    final c = widget.category;
    final s = ref.read(sourcesProvider);
    if (_query.isNotEmpty) return s.searchTracks(_query, genre: c.genre, sort: 'popular');
    if (c.searchQuery != null && c.genre == null) return s.searchTracks(c.searchQuery!, sort: 'popular');
    if (c.searchQuery != null) return s.searchTracks(c.searchQuery!, genre: c.genre, sort: 'popular');
    return s.trending(time: _time, genre: c.genre);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final source = _source();
    final state = ref.watch(pagedTracksProvider(source));
    final notifier = ref.read(pagedTracksProvider(source).notifier);
    final actions = ref.read(playbackActionsProvider);
    final isTrending = _query.isEmpty && c.searchQuery == null;

    final seen = <String>{};
    final artists = [
      for (final t in state.items)
        if (t.artist.id.isNotEmpty && seen.add(t.artist.id)) t.artist
    ].take(12).toList();

    return Scaffold(
      body: InfiniteScroll(
        onEnd: notifier.loadMore,
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 140,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                background: DecoratedBox(
                  decoration:
                      BoxDecoration(gradient: LinearGradient(colors: c.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(padding: const EdgeInsets.only(right: 24), child: Icon(c.icon, size: 80, color: Colors.white24))),
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
                    hintText: 'Search ${c.label}',
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
                      if (mounted) setState(() => _query = v.trim());
                    });
                  },
                ),
              ),
            ),
            if (isTrending)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      children: [
                        for (final e in _sorts.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(e.value), selected: _time == e.key, onSelected: (_) => setState(() => _time = e.key)),
                          ),
                      ]),
                ),
              ),
            if (artists.isNotEmpty && _query.isEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Popular artists')),
              SliverToBoxAdapter(
                child: HList(height: 150, count: artists.length, builder: (_, i) => ArtistCard(artist: artists[i])),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(
                  title: _query.isEmpty ? (isTrending ? 'Trending in ${c.label}' : 'Top in ${c.label}') : 'Results for "$_query"'),
            ),
            if (state.items.isNotEmpty)
              SliverToBoxAdapter(
                child: PlayShuffleRow(
                  onPlay: () => actions.playTracks(state.items),
                  onShuffle: () => actions.shuffle(state.items),
                ),
              ),
            trackSliver(state.items, (i) => actions.playTracks(state.items, index: i)),
            pagedFooter<Track>(state, notifier.refresh, emptyTitle: 'No tracks found'),
          ]),
        ),
      ),
    );
  }
}
