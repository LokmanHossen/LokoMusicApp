import 'package:dio/dio.dart';
import 'package:pulse_music/core/config/app_config.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/data/models/models.dart';

/// Jamendo API v3 (https://developer.jamendo.com/v3.0/tracks).
///
/// Creative Commons music with full-length streams in the `audio` field.
/// Needs a free client id (`--dart-define=JAMENDO_CLIENT_ID=...`); without one
/// [enabled] is false and every call returns an empty list.
class JamendoDataSource {
  JamendoDataSource({Dio? dio, String clientId = AppConfig.jamendoClientId})
      : _clientId = clientId,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.jamendo.com/v3.0',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;
  final String _clientId;
  final Map<String, ({DateTime at, List<Track> tracks})> _cache = {};

  bool get enabled => _clientId.isNotEmpty;

  /// [query] is a free-text search over track, album, artist and tags.
  /// [language] uses Jamendo's `lang` filter (lyrics language).
  /// [order] is a Jamendo order such as `popularity_total` or `releasedate_desc`.
  Future<List<Track>> searchTracks({
    String? query,
    MusicLanguage? language,
    String? order,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!enabled) return const [];
    final params = <String, dynamic>{
      'client_id': _clientId,
      'format': 'json',
      'limit': limit.clamp(1, 200),
      'offset': offset,
      'audioformat': 'mp32',
      'imagesize': 300,
      if (query != null && query.isNotEmpty) 'search': query,
      if (language != null) 'lang': language.code,
      if (order != null) 'order': order,
    };
    final key = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 5)) return hit.tracks;

    try {
      final res = await _dio.get<dynamic>('/tracks/', queryParameters: params);
      final body = res.data;
      if (body is! Map) throw const Failure('Jamendo returned an unexpected response.');
      // Jamendo reports errors inside a 200 response.
      final headers = body['headers'];
      if (headers is Map && headers['status'] != 'success') {
        final msg = '${headers['error_message'] ?? ''}'.trim();
        throw Failure(msg.isEmpty ? 'Jamendo request failed.' : 'Jamendo: $msg', code: headers['code'] is int ? headers['code'] as int : null);
      }
      final results = body['results'];
      final tracks = results is List
          ? results
              .whereType<Map>()
              .map((m) => Track.fromJamendo(Map<String, dynamic>.from(m), language: language?.code))
              .where((t) => t.isPlayable)
              .toList()
          : const <Track>[];
      _cache[key] = (at: DateTime.now(), tracks: tracks);
      return tracks;
    } on DioException catch (e) {
      throw Failure.from(e);
    }
  }
}
