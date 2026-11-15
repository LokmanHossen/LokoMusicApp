import 'package:pulse_music/core/network/audius_client.dart';
import 'package:pulse_music/data/models/models.dart';

/// All Audius REST calls. Responses are `{ "data": ... }`; the client unwraps it.
class AudiusRepository {
  AudiusRepository(this._c);
  final AudiusClient _c;

  List<Map<String, dynamic>> _maps(dynamic d) =>
      d is List ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  List<Track> _tracks(dynamic d) => _maps(d).map(Track.fromApi).where((t) => t.streamable && t.id.isNotEmpty && !t.isTooShort).toList();

  List<Collection> _collections(dynamic d) => _maps(d).map(Collection.fromApi).where((c) => c.id.isNotEmpty).toList();

  // ---- Tracks --------------------------------------------------------------

  /// [time]: week | month | year | allTime
  Future<List<Track>> trending({String time = 'week', String? genre, int limit = 20, int offset = 0}) async =>
      _tracks(await _c.get('/tracks/trending', query: {'time': time, 'genre': genre, 'limit': limit, 'offset': offset}));

  Future<List<Track>> underground({int limit = 20, int offset = 0}) async =>
      _tracks(await _c.get('/tracks/trending/underground', query: {'limit': limit, 'offset': offset}));

  /// [sort]: relevant | popular | recent
  Future<List<Track>> searchTracks(String query, {String? genre, String sort = 'relevant', int limit = 20, int offset = 0}) async =>
      _tracks(
          await _c.get('/tracks/search', query: {'query': query, 'genre': genre, 'sort_method': sort, 'limit': limit, 'offset': offset}));

  // ---- Users ---------------------------------------------------------------

  Future<List<Artist>> searchArtists(String query, {int limit = 20, int offset = 0}) async =>
      _maps(await _c.get('/users/search', query: {'query': query, 'limit': limit, 'offset': offset}))
          .map(Artist.fromApi)
          .where((a) => a.id.isNotEmpty)
          .toList();

  Future<Artist> user(String id) async {
    final d = await _c.get('/users/$id');
    final m = d is List ? (d.isNotEmpty ? d.first : null) : d;
    return Artist.fromApi(Map<String, dynamic>.from(m as Map));
  }

  /// [sort]: date | plays
  Future<List<Track>> userTracks(String id, {String sort = 'plays', int limit = 20, int offset = 0}) async =>
      _tracks(await _c.get('/users/$id/tracks', query: {'sort': sort, 'limit': limit, 'offset': offset}));

  Future<List<Collection>> userAlbums(String id, {int limit = 20, int offset = 0}) async =>
      _collections(await _c.get('/users/$id/albums', query: {'limit': limit, 'offset': offset}));

  Future<List<Collection>> userPlaylists(String id, {int limit = 20, int offset = 0}) async =>
      _collections(await _c.get('/users/$id/playlists', query: {'limit': limit, 'offset': offset}));

  // ---- Playlists & albums --------------------------------------------------

  Future<List<Collection>> trendingCollections({String time = 'month', int limit = 20, int offset = 0}) async =>
      _collections(await _c.get('/playlists/trending', query: {'time': time, 'limit': limit, 'offset': offset}));

  Future<List<Collection>> searchCollections(String query, {int limit = 20, int offset = 0}) async =>
      _collections(await _c.get('/playlists/search', query: {'query': query, 'limit': limit, 'offset': offset}));

  Future<List<Collection>> playlists({int limit = 20, int offset = 0}) async =>
      (await trendingCollections(limit: limit, offset: offset)).where((c) => !c.isAlbum).toList();

  /// Albums are playlists flagged `is_album`. Trending first; falls back to
  /// search when the trending feed has too few albums.
  Future<List<Collection>> albums({int limit = 20, int offset = 0}) async {
    final found = <String, Collection>{};
    for (final c in await trendingCollections(limit: limit, offset: offset)) {
      if (c.isAlbum) found[c.id] = c;
    }
    if (found.length < 6) {
      for (final c in await searchCollections('album', limit: limit, offset: offset)) {
        if (c.isAlbum) found[c.id] = c;
      }
    }
    return found.values.toList();
  }

  Future<Collection> collection(String id) async {
    final d = await _c.get('/playlists/$id');
    final m = d is List ? (d.isNotEmpty ? d.first : null) : d;
    return Collection.fromApi(Map<String, dynamic>.from(m as Map));
  }

  Future<List<Track>> collectionTracks(String id) async => _tracks(await _c.get('/playlists/$id/tracks'));
}
