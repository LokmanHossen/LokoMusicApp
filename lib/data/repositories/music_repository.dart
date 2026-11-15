import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/utils/language_detect.dart';
import 'package:pulse_music/data/datasources/deezer_datasource.dart';
import 'package:pulse_music/data/datasources/itunes_datasource.dart';
import 'package:pulse_music/data/datasources/jamendo_datasource.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/repositories/audius_repository.dart';

/// Merges several result lists round-robin (so no single query or provider
/// dominates the top), dropping repeats by id and by normalized title+artist.
List<Track> mergeTracks(List<List<Track>> lists, {Set<String>? seenIds, Set<String>? seenSongs}) {
  final ids = seenIds ?? <String>{};
  final songs = seenSongs ?? <String>{};
  final out = <Track>[];
  final longest = lists.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  for (var i = 0; i < longest; i++) {
    for (final list in lists) {
      if (i >= list.length) continue;
      final t = list[i];
      if (ids.add(t.id) && songs.add(songKey(t.title, t.artist.name))) out.add(t);
    }
  }
  return out;
}

List<Collection> mergeCollections(List<List<Collection>> lists) {
  final ids = <String>{};
  final out = <Collection>[];
  final longest = lists.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  for (var i = 0; i < longest; i++) {
    for (final list in lists) {
      if (i < list.length && ids.add(list[i].id)) out.add(list[i]);
    }
  }
  return out;
}

/// Multi-source, multi-language access on top of the Audius repository and
/// the optional Jamendo source. Audius stays the source for artist, album and
/// playlist pages; Jamendo only contributes playable tracks.
class MusicRepository {
  MusicRepository(this.audius, this.jamendo, {DeezerDataSource? deezer, ITunesDataSource? itunes})
      : deezer = deezer ?? DeezerDataSource(),
        itunes = itunes ?? ITunesDataSource();
  final AudiusRepository audius;
  final JamendoDataSource jamendo;

  /// Preview-only sources (30-second clips) for mainstream Bangla/Hindi music.
  final DeezerDataSource deezer;
  final ITunesDataSource itunes;

  bool get hasJamendo => jamendo.enabled;

  /// Unified track search across providers: full songs from Audius and
  /// Jamendo, repeats removed. A failing secondary provider never hides the
  /// others' results.
  ///
  /// [previews] (Deezer, iTunes) is off: the app hides songs of 30 seconds or
  /// less (see [Track.isTooShort]), and every preview is exactly 30 seconds.
  Future<List<Track>> searchTracks(String query,
      {String? genre, String sort = 'relevant', MusicLanguage? language, int limit = 20, int offset = 0, bool previews = false}) async {
    Future<List<Track>> safe(Future<List<Track>> f) => f.catchError((Object _) => const <Track>[]);
    final audiusFuture = audius.searchTracks(query, genre: genre, sort: sort, limit: limit, offset: offset);
    // The other providers have no Audius-style genres; skip them when a
    // genre filter is on.
    final others = genre == null;
    final jamendoFuture = (hasJamendo && others)
        ? safe(jamendo.searchTracks(query: query, language: language, order: _jamendoOrder(sort), limit: limit ~/ 2, offset: offset ~/ 2))
        : Future.value(const <Track>[]);
    final withPreviews = previews && others;
    final deezerFuture =
        withPreviews ? safe(deezer.searchTracks(query, limit: limit ~/ 2, index: offset ~/ 2)) : Future.value(const <Track>[]);
    final itunesFuture =
        withPreviews ? safe(itunes.searchSongs(query, limit: limit ~/ 2, offset: offset ~/ 2)) : Future.value(const <Track>[]);
    final r = await Future.wait([audiusFuture, jamendoFuture, deezerFuture, itunesFuture]);
    final ids = <String>{}, songs = <String>{};
    return [
      ...mergeTracks([r[0], r[1]], seenIds: ids, seenSongs: songs),
      ...mergeTracks([r[2], r[3]], seenIds: ids, seenSongs: songs),
    ];
  }

  /// 30-second previews for a language section: iTunes (India store) and
  /// Deezer, merged and de-duplicated. Results take the section's language,
  /// since the queries themselves pick the language (e.g. "rabindra sangeet").
  Future<List<Track>> sectionPreviews(LanguageSection s, MusicLanguage language, {int limit = 20, int offset = 0}) async {
    final per = (limit / (s.queries.length * 2)).ceil().clamp(4, limit);
    final page = offset ~/ limit;
    final futures = <Future<List<Track>>>[
      for (final q in s.queries) ...[
        itunes.searchSongs(q, language: language, limit: per, offset: page * per).catchError((Object _) => const <Track>[]),
        deezer.searchTracks(q, language: language, limit: per, index: page * per).catchError((Object _) => const <Track>[]),
      ],
    ];
    return mergeTracks(await Future.wait(futures));
  }

  /// Tracks for one section of a language page. Results are not language
  /// filtered here; the paged list applies [matchesLanguage].
  Future<List<Track>> sectionTracks(LanguageSection s, {int limit = 20, int offset = 0}) async {
    if (s.trendingTime != null) {
      return audius.trending(time: s.trendingTime!, limit: limit, offset: offset);
    }
    final perQuery = (limit / s.queries.length).ceil().clamp(5, limit);
    final pages =
        await Future.wait(s.queries.map((q) => audius.searchTracks(q, sort: s.sort, limit: perQuery, offset: offset ~/ limit * perQuery)));
    return mergeTracks(pages);
  }

  Future<List<Collection>> sectionPlaylists(LanguageSection s, {int limit = 20, int offset = 0}) async {
    final pages = await Future.wait(s.queries.map((q) => audius.searchCollections(q, limit: limit, offset: offset)));
    return mergeCollections(pages).where((c) => !c.isAlbum).toList();
  }

  /// Free, Creative Commons tracks in [language] from Jamendo (empty when
  /// Jamendo is not configured).
  Future<List<Track>> jamendoByLanguage(MusicLanguage language, {String order = 'popularity_total', int limit = 20, int offset = 0}) =>
      jamendo.searchTracks(language: language, order: order, limit: limit, offset: offset);

  static String? _jamendoOrder(String audiusSort) => switch (audiusSort) {
        'popular' => 'popularity_total',
        'recent' => 'releasedate_desc',
        _ => null, // relevance, Jamendo's default
      };
}

/// True when [t] belongs to [language]. Provider-supplied languages (Jamendo)
/// are trusted as-is.
bool matchesLanguage(Track t, MusicLanguage language) => t.language == language.code;

bool collectionMatchesLanguage(Collection c, MusicLanguage language) => c.language == language.code;
