import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/data/datasources/jamendo_datasource.dart';
import 'package:pulse_music/data/repositories/music_repository.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/repositories/audius_repository.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';

// ---- Pagination ----------------------------------------------------------------

class PagedSource<T> {
  PagedSource(this.key, this.load, {this.pageSize = 20, this.filter, this.idOf});
  final String key;
  final int pageSize;
  final Future<List<T>> Function(int offset, int limit) load;

  /// Keeps only matching items (e.g. a language). Pages that filter down to
  /// nothing are skipped automatically, so pagination doesn't stop early.
  final bool Function(T item)? filter;

  /// Item identity for de-duplicating across pages (merged sources overlap).
  final String Function(T item)? idOf;

  @override
  bool operator ==(Object other) => other is PagedSource<T> && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class PagedState<T> {
  const PagedState({this.items = const [], this.loading = false, this.hasMore = true, this.error});
  final List<T> items;
  final bool loading, hasMore;
  final String? error;

  PagedState<T> copyWith({List<T>? items, bool? loading, bool? hasMore, String? error, bool clearError = false}) => PagedState<T>(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class PagedController<T> extends AutoDisposeFamilyNotifier<PagedState<T>, PagedSource<T>> {
  bool _busy = false;
  bool _disposed = false;
  int _offset = 0;
  final _seen = <String>{};

  /// Raw pages fetched in a row while looking for items that pass the filter.
  static const _maxSkippedPages = 4;

  @override
  PagedState<T> build(PagedSource<T> arg) {
    ref.onDispose(() => _disposed = true);
    Future.microtask(loadMore);
    return PagedState<T>(loading: true);
  }

  Future<void> loadMore() async {
    if (_busy || _disposed || !state.hasMore) return;
    _busy = true;
    state = state.copyWith(loading: true, clearError: true);
    try {
      var raw = <T>[];
      var kept = <T>[];
      for (var tries = 0; tries < _maxSkippedPages; tries++) {
        raw = await arg.load(_offset, arg.pageSize);
        if (_disposed) return;
        _offset += arg.pageSize;
        kept = [
          for (final item in raw)
            if ((arg.filter?.call(item) ?? true) && (arg.idOf == null || _seen.add(arg.idOf!(item)))) item
        ];
        if (kept.isNotEmpty || raw.isEmpty) break;
      }
      state = state.copyWith(items: [...state.items, ...kept], hasMore: raw.isNotEmpty, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: Failure.from(e).message);
    } finally {
      _busy = false;
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _busy = false;
    _offset = 0;
    _seen.clear();
    state = PagedState<T>(loading: true);
    await loadMore();
  }
}

final pagedTracksProvider =
    NotifierProvider.autoDispose.family<PagedController<Track>, PagedState<Track>, PagedSource<Track>>(PagedController<Track>.new);
final pagedCollectionsProvider = NotifierProvider.autoDispose
    .family<PagedController<Collection>, PagedState<Collection>, PagedSource<Collection>>(PagedController<Collection>.new);
final pagedArtistsProvider =
    NotifierProvider.autoDispose.family<PagedController<Artist>, PagedState<Artist>, PagedSource<Artist>>(PagedController<Artist>.new);

// ---- Source factories ------------------------------------------------------------

String _trackId(Track t) => t.id;
String _collectionId(Collection c) => c.id;
String _artistId(Artist a) => a.id;

class Sources {
  Sources(this.repo, this.music);
  final AudiusRepository repo;
  final MusicRepository music;

  /// Unified track search: Audius plus Jamendo (when configured), merged and
  /// de-duplicated, optionally limited to one language.
  PagedSource<Track> searchAll(String q, {String? genre, String sort = 'relevant', MusicLanguage? language}) => PagedSource(
        'search:all:$q:$genre:$sort:${language?.code}',
        (o, l) => music.searchTracks(q, genre: genre, sort: sort, language: language, limit: l, offset: o),
        filter: language == null ? null : (t) => matchesLanguage(t, language),
        idOf: _trackId,
      );

  PagedSource<Collection> searchAlbumsIn(String q, MusicLanguage? language) => PagedSource(
        'search:al:$q:${language?.code}',
        pageSize: 40,
        (o, l) async => (await repo.searchCollections(q, limit: l, offset: o)).where((c) => c.isAlbum).toList(),
        filter: language == null ? null : (c) => collectionMatchesLanguage(c, language),
        idOf: _collectionId,
      );

  PagedSource<Collection> searchPlaylistsIn(String q, MusicLanguage? language) => PagedSource(
        'search:p:$q:${language?.code}',
        pageSize: 40,
        (o, l) async => (await repo.searchCollections(q, limit: l, offset: o)).where((c) => !c.isAlbum).toList(),
        filter: language == null ? null : (c) => collectionMatchesLanguage(c, language),
        idOf: _collectionId,
      );

  /// Tracks for a language-page section, kept to that language.
  PagedSource<Track> languageTracks(MusicLanguage language, LanguageSection s) => PagedSource(
        'lang:${s.id}',
        (o, l) => music.sectionTracks(s, limit: l, offset: o),
        filter: (t) => matchesLanguage(t, language),
        idOf: _trackId,
      );

  PagedSource<Collection> languagePlaylists(MusicLanguage language, LanguageSection s) => PagedSource(
        'lang:${s.id}',
        (o, l) => music.sectionPlaylists(s, limit: l, offset: o),
        filter: (c) => collectionMatchesLanguage(c, language),
        idOf: _collectionId,
      );

  /// Artists behind a section's language-matched tracks (Audius artist search
  /// is too fuzzy to filter by language).
  PagedSource<Artist> languageArtists(MusicLanguage language, LanguageSection s) => PagedSource(
        'lang:${s.id}',
        (o, l) async => [
          for (final t in await music.sectionTracks(s, limit: l, offset: o))
            if (matchesLanguage(t, language) && t.artist.id.isNotEmpty) t.artist
        ],
        idOf: _artistId,
      );

  /// 30-second previews (iTunes + Deezer) for a language section.
  PagedSource<Track> languagePreviews(MusicLanguage language, LanguageSection s) => PagedSource(
        'lang:${s.id}',
        (o, l) => music.sectionPreviews(s, language, limit: l, offset: o),
        idOf: _trackId,
      );

  PagedSource<Track> jamendoLanguage(MusicLanguage language) => PagedSource(
        'jamendo:${language.code}',
        (o, l) => music.jamendoByLanguage(language, limit: l, offset: o),
        idOf: _trackId,
      );

  PagedSource<Track> trending({String time = 'week', String? genre}) =>
      PagedSource('trending:$time:$genre', (o, l) => repo.trending(time: time, genre: genre, limit: l, offset: o));

  PagedSource<Track> newReleases() => PagedSource('underground', (o, l) => repo.underground(limit: l, offset: o));

  PagedSource<Track> recommended() => PagedSource('recommended', (o, l) => repo.trending(time: 'month', limit: l, offset: o));

  PagedSource<Track> searchTracks(String q, {String? genre, String sort = 'relevant'}) =>
      PagedSource('search:t:$q:$genre:$sort', (o, l) => repo.searchTracks(q, genre: genre, sort: sort, limit: l, offset: o));

  PagedSource<Artist> searchArtists(String q) => PagedSource('search:a:$q', (o, l) => repo.searchArtists(q, limit: l, offset: o));

  PagedSource<Collection> searchAlbums(String q) => PagedSource(
      'search:al:$q',
      pageSize: 40,
      (o, l) async => (await repo.searchCollections(q, limit: l, offset: o)).where((c) => c.isAlbum).toList());

  PagedSource<Collection> searchPlaylists(String q) => PagedSource(
      'search:p:$q',
      pageSize: 40,
      (o, l) async => (await repo.searchCollections(q, limit: l, offset: o)).where((c) => !c.isAlbum).toList());

  PagedSource<Collection> popularAlbums() => PagedSource('albums', pageSize: 40, (o, l) => repo.albums(limit: l, offset: o));

  PagedSource<Collection> popularPlaylists() => PagedSource('playlists', pageSize: 40, (o, l) => repo.playlists(limit: l, offset: o));

  PagedSource<Track> userTracks(String id, {String sort = 'plays'}) =>
      PagedSource('user:$id:t:$sort', (o, l) => repo.userTracks(id, sort: sort, limit: l, offset: o));

  PagedSource<Collection> userAlbums(String id) => PagedSource('user:$id:al', (o, l) => repo.userAlbums(id, limit: l, offset: o));

  PagedSource<Collection> userPlaylists(String id) => PagedSource('user:$id:p', (o, l) => repo.userPlaylists(id, limit: l, offset: o));
}

final jamendoProvider = Provider<JamendoDataSource>((ref) => JamendoDataSource());
final musicRepositoryProvider =
    Provider<MusicRepository>((ref) => MusicRepository(ref.watch(repositoryProvider), ref.watch(jamendoProvider)));

final sourcesProvider = Provider<Sources>((ref) => Sources(ref.watch(repositoryProvider), ref.watch(musicRepositoryProvider)));

/// First page of a language-page section, for the horizontal rows. "View all"
/// opens the full paged list from [Sources].
final languageSectionTracksProvider = FutureProvider.autoDispose.family<List<Track>, (MusicLanguage, LanguageSection)>((ref, a) async {
  final (language, section) = a;
  final tracks = await ref.watch(musicRepositoryProvider).sectionTracks(section, limit: 30);
  return tracks.where((t) => matchesLanguage(t, language)).take(20).toList();
});

final languageSectionPlaylistsProvider =
    FutureProvider.autoDispose.family<List<Collection>, (MusicLanguage, LanguageSection)>((ref, a) async {
  final (language, section) = a;
  final lists = await ref.watch(musicRepositoryProvider).sectionPlaylists(section, limit: 30);
  return lists.where((c) => collectionMatchesLanguage(c, language)).take(20).toList();
});

final languageSectionArtistsProvider = FutureProvider.autoDispose.family<List<Artist>, (MusicLanguage, LanguageSection)>((ref, a) async {
  final (language, section) = a;
  final tracks = await ref.watch(musicRepositoryProvider).sectionTracks(section, limit: 40);
  final seen = <String>{};
  return [
    for (final t in tracks)
      if (matchesLanguage(t, language) && t.artist.id.isNotEmpty && seen.add(t.artist.id)) t.artist
  ].take(15).toList();
});

final languageSectionPreviewsProvider = FutureProvider.autoDispose.family<List<Track>, (MusicLanguage, LanguageSection)>((ref, a) {
  final (language, section) = a;
  return ref.watch(musicRepositoryProvider).sectionPreviews(section, language, limit: 24);
});

final jamendoLanguageProvider = FutureProvider.autoDispose
    .family<List<Track>, MusicLanguage>((ref, language) => ref.watch(musicRepositoryProvider).jamendoByLanguage(language, limit: 20));

// ---- Home sections (HomeController) ---------------------------------------------

final trendingProvider = FutureProvider<List<Track>>((ref) => ref.watch(repositoryProvider).trending(time: 'week'));
final popularProvider = FutureProvider<List<Track>>((ref) => ref.watch(repositoryProvider).trending(time: 'allTime'));
final newReleasesProvider = FutureProvider<List<Track>>((ref) => ref.watch(repositoryProvider).underground());
final recommendedProvider = FutureProvider<List<Track>>((ref) => ref.watch(repositoryProvider).trending(time: 'month'));

final featuredArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final tracks = await ref.watch(popularProvider.future);
  final seen = <String>{};
  return [
    for (final t in tracks)
      if (t.artist.id.isNotEmpty && seen.add(t.artist.id)) t.artist
  ].take(12).toList();
});

final popularAlbumsProvider = FutureProvider<List<Collection>>((ref) => ref.watch(repositoryProvider).albums(limit: 40));
final popularPlaylistsProvider = FutureProvider<List<Collection>>((ref) => ref.watch(repositoryProvider).playlists(limit: 40));

/// Most frequent genre in recently played / favourite tracks.
final topGenreProvider = Provider<String>((ref) {
  final counts = <String, int>{};
  for (final t in [...ref.watch(recentProvider), ...ref.watch(favoritesProvider).tracks]) {
    final g = t.genre;
    if (g != null && g.isNotEmpty) counts[g] = (counts[g] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'Electronic';
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
});

final madeForYouProvider =
    FutureProvider<List<Track>>((ref) => ref.watch(repositoryProvider).trending(time: 'month', genre: ref.watch(topGenreProvider)));

// ---- Detail screens ---------------------------------------------------------------

final artistProvider = FutureProvider.autoDispose.family<Artist, String>((ref, id) => ref.watch(repositoryProvider).user(id));
final artistPopularProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) => ref.watch(repositoryProvider).userTracks(id, sort: 'plays', limit: 30));
final artistLatestProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, id) => ref.watch(repositoryProvider).userTracks(id, sort: 'date', limit: 15));
final artistAlbumsProvider =
    FutureProvider.autoDispose.family<List<Collection>, String>((ref, id) => ref.watch(repositoryProvider).userAlbums(id, limit: 20));
final artistPlaylistsProvider =
    FutureProvider.autoDispose.family<List<Collection>, String>((ref, id) => ref.watch(repositoryProvider).userPlaylists(id, limit: 20));

final collectionProvider = FutureProvider.autoDispose.family<Collection, String>((ref, id) => ref.watch(repositoryProvider).collection(id));
final collectionTracksProvider =
    FutureProvider.autoDispose.family<List<Track>, String>((ref, id) => ref.watch(repositoryProvider).collectionTracks(id));
