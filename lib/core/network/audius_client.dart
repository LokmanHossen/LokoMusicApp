import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pulse_music/core/config/app_config.dart';
import 'package:pulse_music/core/error/failure.dart';

class _CacheEntry {
  _CacheEntry(this.data) : at = DateTime.now();
  final dynamic data;
  final DateTime at;
}

/// Central HTTP client: auth params, timeouts, retry with backoff,
/// host fallback, short-lived response cache and in-flight de-duplication.
class AudiusClient {
  AudiusClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 12),
              headers: {'Accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.queryParameters.putIfAbsent('app_name', () => AppConfig.appName);
      if (AppConfig.apiKey.isNotEmpty) {
        options.queryParameters.putIfAbsent('api_key', () => AppConfig.apiKey);
      }
      handler.next(options);
    }));
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }
  }

  final Dio _dio;
  int _host = 0;
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<dynamic>> _inflight = {};

  List<String> get _hosts => AppConfig.hosts;

  /// Stream URL for a track (the API answers with a redirect to the audio).
  String streamUrl(String trackId) {
    final params = <String, String>{
      'app_name': AppConfig.appName,
      if (AppConfig.apiKey.isNotEmpty) 'api_key': AppConfig.apiKey,
    };
    return Uri.parse('${_hosts[_host % _hosts.length]}/tracks/$trackId/stream').replace(queryParameters: params).toString();
  }

  void clearCache() => _cache.clear();

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Duration ttl = const Duration(minutes: 3),
    bool force = false,
  }) {
    final q = <String, dynamic>{...?query}..removeWhere((k, v) => v == null);
    final sorted = q.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final key = '$path?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';

    if (!force) {
      final hit = _cache[key];
      if (hit != null && DateTime.now().difference(hit.at) < ttl) {
        return Future.value(hit.data);
      }
    }
    final running = _inflight[key];
    if (running != null) return running;

    final future = _fetch(path, q).then((data) {
      _cache[key] = _CacheEntry(data);
      return data;
    }).whenComplete(() {
      // Block body on purpose: `=> _inflight.remove(key)` would return this
      // very future to whenComplete, which then waits on itself forever.
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  Future<dynamic> _fetch(String path, Map<String, dynamic> query) async {
    Object? last;
    for (var h = 0; h < _hosts.length; h++) {
      final index = (_host + h) % _hosts.length;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final res = await _dio.get('${_hosts[index]}$path', queryParameters: query);
          _host = index;
          final body = res.data;
          if (body is Map && body.containsKey('data')) return body['data'];
          return body;
        } on DioException catch (e) {
          last = e;
          final code = e.response?.statusCode;
          final permanent = code != null && code >= 400 && code < 500 && code != 429 && code != 408;
          if (permanent) throw Failure.from(e);
          await Future<void>.delayed(Duration(milliseconds: 400 * (1 << attempt)));
        }
      }
    }
    throw Failure.from(last ?? const Failure('Request failed'));
  }
}
