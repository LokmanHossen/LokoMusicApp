import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/core/utils/spotify_link.dart';
import 'package:pulse_music/data/models/models.dart';

void main() {
  test('Track.fromApi parses an Audius track and round-trips locally', () {
    final track = Track.fromApi({
      'id': 'D7KyD',
      'title': 'Test Song',
      'duration': 185,
      'play_count': 12345,
      'genre': 'Electronic',
      'artwork': {'150x150': 'a', '480x480': 'b', '1000x1000': 'c'},
      'user': {'id': 'u1', 'name': 'Artist', 'handle': 'artist', 'is_verified': true},
    });
    expect(track.id, 'D7KyD');
    expect(track.artist.verified, isTrue);
    expect(track.art.forSize(100), 'a');
    expect(track.art.forSize(400), 'b');
    expect(track.art.forSize(900), 'c');

    final again = Track.fromMap(track.toMap());
    expect(again.title, 'Test Song');
    expect(again.artist.name, 'Artist');
    expect(again.plays, 12345);
  });

  test('Collection flags albums', () {
    final c = Collection.fromApi({
      'id': 'p1',
      'playlist_name': 'My Album',
      'is_album': true,
      'track_count': 8,
      'user': {'id': 'u1', 'name': 'Artist'},
    });
    expect(c.isAlbum, isTrue);
    expect(c.trackCount, 8);
  });

  test('formatters', () {
    expect(fmtDuration(65), '1:05');
    expect(fmtDuration(3725), '1:02:05');
    expect(fmtCount(1500), '1.5K');
    expect(fmtTotal(7500), '2 hr 5 min');
  });

  test('Spotify link is a search URL for title and artist', () {
    const t = Track(id: '1', title: 'Test Song', artist: Artist(id: 'u', name: 'Some Artist'));
    final uri = spotifySearchUri(t);
    expect(uri.host, 'open.spotify.com');
    expect(Uri.decodeComponent(uri.path), '/search/Test Song Some Artist');
  });
}
