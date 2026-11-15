import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_music/data/models/youtube_video.dart';

void main() {
  test('ISO 8601 durations from videos.list', () {
    expect(parseIsoDuration('PT3M32S'), 212);
    expect(parseIsoDuration('PT22M3S'), 1323);
    expect(parseIsoDuration('PT1H2M'), 3720);
    expect(parseIsoDuration('PT45S'), 45);
    expect(parseIsoDuration('P1DT1S'), 86401);
    expect(parseIsoDuration('P0D'), 0);
    expect(parseIsoDuration(null), 0);
    expect(parseIsoDuration('garbage'), 0);
  });

  test('search.list item maps to a video with unescaped title', () {
    // Shape from a live search.list response.
    final v = YouTubeVideo.fromSearch({
      'id': {'kind': 'youtube#video', 'videoId': 'Pu--qQBsnOg'},
      'snippet': {
        'title': 'Tumi &amp; Ami | Rock&#39;n Roll &quot;Live&quot;',
        'channelTitle': 'Music &amp; More',
        'publishedAt': '2026-11-13T04:00:22Z',
        'thumbnails': {
          'default': {'url': 'https://i.ytimg.com/vi/Pu--qQBsnOg/default.jpg'},
          'high': {'url': 'https://i.ytimg.com/vi/Pu--qQBsnOg/hqdefault.jpg'},
        },
      },
    }, durationSeconds: 212);
    expect(v.id, 'Pu--qQBsnOg');
    expect(v.title, 'Tumi & Ami | Rock\'n Roll "Live"');
    expect(v.channel, 'Music & More');
    expect(v.thumbnail, endsWith('hqdefault.jpg'));
    expect(v.durationSeconds, 212);
    expect(v.watchUrl, 'https://www.youtube.com/watch?v=Pu--qQBsnOg');

    final again = YouTubeVideo.fromMap(v.toMap());
    expect(again.title, v.title);
    expect(again.durationSeconds, 212);
  });
}
