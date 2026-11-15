/// A YouTube music video. Kept separate from [Track] on purpose: YouTube
/// videos may only be played as video in YouTube's embedded player, never
/// through the app's audio player, queue or background playback.
class YouTubeVideo {
  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.channel,
    this.thumbnail,
    this.durationSeconds = 0,
    this.publishedAt,
  });

  final String id, title, channel;
  final String? thumbnail, publishedAt;
  final int durationSeconds;

  String get watchUrl => 'https://www.youtube.com/watch?v=$id';

  /// From a `search.list` item (snippet) plus the duration from `videos.list`.
  factory YouTubeVideo.fromSearch(Map<String, dynamic> item, {int durationSeconds = 0}) {
    final id = item['id'] is Map ? '${(item['id'] as Map)['videoId'] ?? ''}' : '${item['id'] ?? ''}';
    final s = item['snippet'] is Map ? Map<String, dynamic>.from(item['snippet'] as Map) : const <String, dynamic>{};
    final thumbs = s['thumbnails'] is Map ? s['thumbnails'] as Map : const {};
    String? thumb(String k) => thumbs[k] is Map ? (thumbs[k] as Map)['url'] as String? : null;
    return YouTubeVideo(
      id: id,
      title: unescapeHtml('${s['title'] ?? ''}'),
      channel: unescapeHtml('${s['channelTitle'] ?? ''}'),
      thumbnail: thumb('high') ?? thumb('medium') ?? thumb('default'),
      durationSeconds: durationSeconds,
      publishedAt: s['publishedAt'] as String?,
    );
  }

  factory YouTubeVideo.fromMap(Map<String, dynamic> j) => YouTubeVideo(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        channel: '${j['channel'] ?? ''}',
        thumbnail: j['thumbnail'] as String?,
        durationSeconds: j['duration'] is int ? j['duration'] as int : 0,
        publishedAt: j['publishedAt'] as String?,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'title': title, 'channel': channel, 'thumbnail': thumbnail, 'duration': durationSeconds, 'publishedAt': publishedAt};
}

/// Parses an ISO 8601 duration such as "PT3M32S" or "PT1H2M" into seconds.
int parseIsoDuration(String? iso) {
  if (iso == null) return 0;
  final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$').firstMatch(iso);
  if (m == null) return 0;
  int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return g(1) * 86400 + g(2) * 3600 + g(3) * 60 + g(4);
}

/// YouTube titles come HTML-escaped (`&amp;`, `&#39;`, `&quot;`).
String unescapeHtml(String s) =>
    s.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
