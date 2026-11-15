import 'package:dio/dio.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/data/models/models.dart';

/// Deezer public API (https://developers.deezer.com/api). No key needed.
///
/// Only 30-second previews are playable. Preview URLs are signed and expire
/// after a few hours, so tracks keep only their Deezer id and [previewUrl]
/// fetches a fresh one when the song is about to play.
class DeezerDataSource {
  DeezerDataSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.deezer.com',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;
  final Map<String, ({DateTime at, List<Track> tracks})> _cache = {};

  /// Track search. [index] is Deezer's offset parameter.
  Future<List<Track>> searchTracks(String query, {MusicLanguage? language, int limit = 20, int index = 0}) async {
    final key = '$query|${language?.code}|$limit|$index';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 5)) return hit.tracks;

    final body = await _get('/search', {'q': query, 'limit': limit, 'index': index});
    final data = body['data'];
    final tracks = data is List
        ? data
            .whereType<Map>()
            .map((m) => Track.fromDeezer(Map<String, dynamic>.from(m), language: language?.code))
            .where((t) => t.isPlayable && !t.isTooShort)
            .toList()
        : const <Track>[];
    _cache[key] = (at: DateTime.now(), tracks: tracks);
    return tracks;
  }

  /// A fresh, signed preview URL for a track id ("deezer:123" or "123").
  Future<String> previewUrl(String trackId) async {
    final id = trackId.startsWith('deezer:') ? trackId.substring(7) : trackId;
    final body = await _get('/track/$id', const {});
    final preview = body['preview'];
    if (preview is String && preview.isNotEmpty) return preview;
    throw const Failure('This Deezer preview is not available.');
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      final body = res.data;
      if (body is! Map) throw const Failure('Deezer returned an unexpected response.');
      // Deezer reports errors inside a 200 response: {"error": {...}}.
      final error = body['error'];
      if (error is Map) {
        final msg = '${error['message'] ?? ''}'.trim();
        throw Failure(msg.isEmpty ? 'Deezer request failed.' : 'Deezer: $msg');
      }
      return Map<String, dynamic>.from(body);
    } on DioException catch (e) {
      throw Failure.from(e);
    }
  }
}
