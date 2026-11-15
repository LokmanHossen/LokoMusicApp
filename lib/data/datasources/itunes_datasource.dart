import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/data/models/models.dart';

/// Apple iTunes Search API
/// (https://performance-partners.apple.com/search-api). No key needed.
///
/// Only 30-second previews are playable, and Apple allows them only to
/// promote the music, so the UI always links to the song on Apple Music.
///
/// Uses the India store: Apple has no Bangladesh music store (`country=bd`
/// returns no songs), while India carries Bengali and Hindi releases.
class ITunesDataSource {
  ITunesDataSource({Dio? dio, this.country = 'in'})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://itunes.apple.com',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;
  final String country;
  final Map<String, ({DateTime at, List<Track> tracks})> _cache = {};

  /// The API has no documented offset, so pages are taken from one larger
  /// result list (Apple's maximum is 200 results).
  static const _maxResults = 200;

  Future<List<Track>> searchSongs(String term, {MusicLanguage? language, int limit = 20, int offset = 0}) async {
    if (offset >= _maxResults) return const [];
    final want = (offset + limit).clamp(1, _maxResults);
    final key = '$term|${language?.code}|$want';
    var all = _cache[key];
    if (all == null || DateTime.now().difference(all.at) > const Duration(minutes: 5)) {
      try {
        final res = await _dio.get<dynamic>('/search', queryParameters: {
          'term': term,
          'media': 'music',
          'entity': 'song',
          'country': country,
          'limit': want,
        });
        // iTunes may answer with text/javascript; Dio then leaves a String.
        final body = res.data is String ? _decode(res.data as String) : res.data;
        final results = body is Map ? body['results'] : null;
        final tracks = results is List
            ? results
                .whereType<Map>()
                .where((m) => m['kind'] == 'song')
                .map((m) => Track.fromITunes(Map<String, dynamic>.from(m), language: language?.code))
                .where((t) => t.isPlayable && !t.isTooShort)
                .toList()
            : const <Track>[];
        all = (at: DateTime.now(), tracks: tracks);
        _cache[key] = all;
      } on DioException catch (e) {
        throw Failure.from(e);
      }
    }
    final list = all.tracks;
    if (offset >= list.length) return const [];
    return list.sublist(offset, (offset + limit).clamp(0, list.length));
  }

  static Object? _decode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
