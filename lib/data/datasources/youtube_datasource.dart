import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pulse_music/core/config/app_config.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/core/services/local_store.dart';
import 'package:pulse_music/data/models/models.dart' show Track;
import 'package:pulse_music/data/models/youtube_video.dart';

/// One page of YouTube results plus the token for the next page.
typedef YouTubePage = ({List<YouTubeVideo> videos, String? nextPageToken});

/// YouTube Data API v3 (https://developers.google.com/youtube/v3).
///
/// Quota: the free tier is 10,000 units/day for the whole app. `search.list`
/// costs 100 units (so about 100 searches a day) and `videos.list` costs 1.
/// Results are therefore cached on the device for [_ttl], and screens only
/// search when the user opens them.
class YouTubeDataSource {
  YouTubeDataSource({required this.store, Dio? dio, String apiKey = AppConfig.youtubeApiKey})
      : _key = apiKey,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://www.googleapis.com/youtube/v3',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;
  final String _key;
  final LocalStore store;
  static const _ttl = Duration(hours: 6);

  bool get enabled => _key.isNotEmpty;

  /// Music videos (category 10) for [query], embeddable only, and longer than
  /// 30 seconds (the app hides anything 30 s or shorter).
  Future<YouTubePage> searchVideos(String query, {MusicLanguage? language, String? pageToken, int maxResults = 20}) async {
    if (!enabled) return (videos: const <YouTubeVideo>[], nextPageToken: null);
    final cacheKey = 'yt:${language?.code}:$query:${pageToken ?? ''}:$maxResults';
    final cached = _readCache(cacheKey);
    if (cached != null) return cached;

    final search = await _get('/search', {
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'videoCategoryId': '10',
      'videoEmbeddable': 'true',
      'regionCode': 'BD',
      if (language != null) 'relevanceLanguage': language.code,
      'maxResults': maxResults,
      if (pageToken != null) 'pageToken': pageToken,
    });
    final items = (search['items'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final ids = [
      for (final i in items)
        if (i['id'] is Map && (i['id'] as Map)['videoId'] != null) '${(i['id'] as Map)['videoId']}'
    ];

    // One cheap call for length and embeddability of the whole page.
    final details = <String, ({int seconds, bool embeddable})>{};
    if (ids.isNotEmpty) {
      final res = await _get('/videos', {'part': 'contentDetails,status', 'id': ids.join(','), 'maxResults': ids.length});
      for (final v in (res['items'] as List? ?? const []).whereType<Map>()) {
        final cd = v['contentDetails'] is Map ? v['contentDetails'] as Map : const {};
        final st = v['status'] is Map ? v['status'] as Map : const {};
        details['${v['id']}'] = (seconds: parseIsoDuration(cd['duration'] as String?), embeddable: st['embeddable'] != false);
      }
    }

    final videos = [
      for (final i in items)
        if (details[(i['id'] as Map?)?['videoId']] case final d?)
          if (d.embeddable && d.seconds > Track.maxHiddenSeconds) YouTubeVideo.fromSearch(i, durationSeconds: d.seconds),
    ];
    final page = (videos: videos, nextPageToken: search['nextPageToken'] as String?);
    _writeCache(cacheKey, page);
    return page;
  }

  /// YouTube's most popular music videos in [regionCode] (the "Trending"
  /// music chart). Costs 1 quota unit instead of 100 for a search, so it is
  /// used on Home. Embeddable and longer-than-30 s videos only.
  Future<List<YouTubeVideo>> popularMusic({String regionCode = 'BD', int maxResults = 20}) async {
    if (!enabled) return const [];
    final cacheKey = 'yt:popular:$regionCode:$maxResults';
    final cached = _readCache(cacheKey);
    if (cached != null) return cached.videos;

    final res = await _get('/videos', {
      'part': 'snippet,contentDetails,status',
      'chart': 'mostPopular',
      'videoCategoryId': '10',
      'regionCode': regionCode,
      'maxResults': maxResults,
    });
    final videos = [
      for (final v in (res['items'] as List? ?? const []).whereType<Map>())
        if (v['status'] is! Map || (v['status'] as Map)['embeddable'] != false)
          YouTubeVideo.fromSearch(
            Map<String, dynamic>.from(v),
            durationSeconds: parseIsoDuration(v['contentDetails'] is Map ? (v['contentDetails'] as Map)['duration'] as String? : null),
          ),
    ].where((v) => v.durationSeconds > Track.maxHiddenSeconds).toList();
    _writeCache(cacheKey, (videos: videos, nextPageToken: null));
    return videos;
  }

  YouTubePage? _readCache(String key) {
    final raw = store.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse('${j['at']}');
      if (at == null || DateTime.now().difference(at) > _ttl) return null;
      return (
        videos: (j['videos'] as List).whereType<Map>().map((m) => YouTubeVideo.fromMap(Map<String, dynamic>.from(m))).toList(),
        nextPageToken: j['next'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void _writeCache(String key, YouTubePage page) {
    store.putString(
      key,
      jsonEncode(
          {'at': DateTime.now().toIso8601String(), 'next': page.nextPageToken, 'videos': page.videos.map((v) => v.toMap()).toList()}),
    );
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: {...query, 'key': _key});
      final body = res.data;
      if (body is! Map) throw const Failure('YouTube returned an unexpected response.');
      return Map<String, dynamic>.from(body);
    } on DioException catch (e) {
      final err = e.response?.data;
      final reason = err is Map && err['error'] is Map ? '${((err['error'] as Map)['errors'] as List?)?.firstOrNull?['reason'] ?? ''}' : '';
      if (reason == 'quotaExceeded' || reason == 'dailyLimitExceeded') {
        throw const Failure('YouTube daily limit reached. Videos will be back tomorrow.', code: 403);
      }
      if (e.response?.statusCode == 400 || e.response?.statusCode == 403) {
        throw Failure('YouTube rejected the request${reason.isEmpty ? '' : ' ($reason)'}. Check the API key.',
            code: e.response?.statusCode);
      }
      throw Failure.from(e);
    }
  }
}
