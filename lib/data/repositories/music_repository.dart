import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/utils/language_detect.dart';
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
  MusicRepository(this.audius, this.jamendo);
  final AudiusRepository audius;
  final JamendoDataSource jamendo;

  bool get hasJamendo => jamendo.enabled;

  /// Unified track search across providers. A failing secondary provider
  /// never hides the primary provider's results.
  Future<List<Track>> searchTracks(String query,
      {String? genre, String sort = 'relevant', MusicLanguage? language, int limit = 20, int offset = 0}) async {
    final audiusFuture = audius.searchTracks(query, genre: genre, sort: sort, limit: limit, offset: offset);
    // Jamendo has no Audius-style genres; skip it when a genre filter is on.
    final jamendoFuture = (hasJamendo && genre == null)
        ? jamendo
            .searchTracks(query: query, language: language, order: _jamendoOrder(sort), limit: limit ~/ 2, offset: offset ~/ 2)
            .catchError((Object _) => const <Track>[])
        : Future.value(const <Track>[]);
    final results = await Future.wait([audiusFuture, jamendoFuture]);
    return mergeTracks(results);
  }

  /// Tracks for one section of a language page. Results are not language
  /// filtered here; the paged list applies [matchesLanguage].
  Future<List<Track>> sectionTracks(LanguageSection s, {int limit = 20, int offset = 0}) async {
    if (s.trendingTime != null) {
      return audius.trending(time: s.trendingTime!, limit: limit, offset: offset);
    }
    final perQuery = (limit / s.queries.length).ceil().clamp(5, limit);
    final pages = await Future.wait(s.queries.map((q) =>
        audius.searchTracks(q, sort: s.sort, limit: perQuery, offset: offset ~/ limit * perQuery)));
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
