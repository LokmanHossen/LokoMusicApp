import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/utils/language_detect.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/repositories/music_repository.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';

Track _t(String id, String title, {String artist = 'A', String provider = MusicProviders.audius}) =>
    Track(id: id, title: title, artist: Artist(id: 'u-$artist', name: artist), provider: provider);

void main() {
  group('detectLanguage', () {
    test('script wins', () {
      expect(detectLanguage(['মৃত আত্মা']), MusicLanguage.bangla);
      expect(detectLanguage(['तुम ही हो']), MusicLanguage.hindi);
    });

    test('keywords as whole words', () {
      expect(detectLanguage(['Oporadhi', 'bangla,dhaka,pop']), MusicLanguage.bangla);
      expect(detectLanguage(['Lalon Geeti remix']), MusicLanguage.bangla);
      expect(detectLanguage(['Tu Hi Re', 'bollywood,romantic']), MusicLanguage.hindi);
      // "Bangers" must not count as Bangla, nor Spanish "baul".
      expect(detectLanguage(['Yin Yang Bangers']), MusicLanguage.english);
      expect(detectLanguage(['Salsa baul 2019 dj carlos']), MusicLanguage.english);
      // A Persian title that mentions "Hindi" is not a Hindi song.
      expect(detectLanguage(['حافظ الا یا ایها الساقی — Hindi']), isNull);
    });

    test('Latin text with no signal is English; empty is unknown', () {
      expect(detectLanguage(['Murder She Wrote', null, 'house,dancehall']), MusicLanguage.english);
      expect(detectLanguage([null, '  ']), isNull);
    });
  });

  test('Audius tracks get a detected language from title, tags and description', () {
    final t = Track.fromApi({
      'id': 'x1',
      'title': 'Hastaakshar',
      'tags': 'atifaslam,bollywood,romantic',
      'user': {'id': 'u', 'name': 'Someone'},
    });
    expect(t.language, 'hi');
    expect(t.provider, MusicProviders.audius);
    expect(t.streamUrl, isNull);
    expect(t.hasDetailPages, isTrue);
  });

  test('Jamendo mapping follows the documented /tracks response', () {
    // Shape copied from https://developer.jamendo.com/v3.0/tracks
    final t = Track.fromJamendo({
      'id': '1848357',
      'name': 'mañana será tarde',
      'duration': 272,
      'artist_id': '421168',
      'artist_name': 'fankel',
      'album_name': 'mañana será tarde',
      'releasedate': '2021-04-11',
      'album_image': 'https://usercontent.jamendo.com?type=album&id=368084&width=300&trackid=1848357',
      'audio': 'https://prod-1.storage.jamendo.com/?trackid=1848357&format=mp31&from=app-devsite',
    }, language: 'en');
    expect(t.id, 'jamendo:1848357');
    expect(t.provider, MusicProviders.jamendo);
    expect(t.streamUrl, startsWith('https://prod-1.storage.jamendo.com/'));
    expect(t.isPlayable, isTrue);
    expect(t.album, 'mañana será tarde');
    expect(t.artist.id, isEmpty, reason: 'no Jamendo artist page in the app');
    expect(t.hasDetailPages, isFalse);

    final again = Track.fromMap(t.toMap());
    expect(again.provider, MusicProviders.jamendo);
    expect(again.streamUrl, t.streamUrl);
    expect(again.language, 'en');

    expect(Track.fromJamendo({'id': '1', 'name': 'No audio'}).isPlayable, isFalse);
  });

  test('Deezer results map to previews with no stored (expiring) URL', () {
    // Shape from a live https://api.deezer.com/search response.
    final t = Track.fromDeezer({
      'id': 4379989631,
      'readable': true,
      'title': 'Tu Mil Jaaye (From "KING")',
      'title_short': 'Tu Mil Jaaye (From "KING")',
      'link': 'https://www.deezer.com/track/4379989631',
      'duration': 315,
      'preview': 'https://cdnt-preview.dzcdn.net/api/1/1/x.mp3?hdnea=exp=1',
      'artist': {'id': 1452924, 'name': 'Sachin-Jigar'},
      'album': {'id': 1, 'title': 'KING', 'cover_medium': 'https://e/m.jpg', 'cover_xl': 'https://e/xl.jpg'},
    }, language: 'hi');
    expect(t.id, 'deezer:4379989631');
    expect(t.provider, MusicProviders.deezer);
    expect(t.previewOnly, isTrue);
    expect(t.streamUrl, isNull, reason: 'Deezer links expire; resolved at play time');
    expect(t.isPlayable, isTrue);
    expect(t.duration, previewSeconds);
    expect(t.externalUrl, 'https://www.deezer.com/track/4379989631');
    expect(t.language, 'hi');
    expect(t.hasDetailPages, isFalse);

    final again = Track.fromMap(t.toMap());
    expect(again.previewOnly, isTrue);
    expect(again.externalUrl, t.externalUrl);
    expect(Track.fromDeezer({'id': 1, 'title': 'x', 'readable': false, 'preview': 'p'}).isPlayable, isFalse);
  });

  test('iTunes results map to previews that link to Apple Music', () {
    // Shape from a live https://itunes.apple.com/search?country=in response.
    final t = Track.fromITunes({
      'kind': 'song',
      'trackId': 1653219849,
      'trackName': 'Apna Bana Le (From "Bhediya")',
      'artistName': 'Arijit Singh, Sachin-Jigar & Amitabh Bhattacharya',
      'collectionName': 'Apna Bana Le (From "Bhediya") - Single',
      'trackViewUrl': 'https://music.apple.com/in/album/x?i=1653219849',
      'previewUrl': 'https://audio-ssl.itunes.apple.com/x.m4a',
      'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/a/100x100bb.jpg',
      'primaryGenreName': 'Bollywood',
    });
    expect(t.id, 'itunes:1653219849');
    expect(t.previewOnly, isTrue);
    expect(t.streamUrl, 'https://audio-ssl.itunes.apple.com/x.m4a');
    expect(t.art.forSize(900), endsWith('1000x1000bb.jpg'));
    expect(t.externalUrl, startsWith('https://music.apple.com/'));
    expect(MusicProviders.label(t.provider), 'Apple Music');
  });

  test('songs of 30 seconds or less are hidden; unknown length is kept', () {
    Track d(int s) => Track(id: 'x', title: 't', artist: const Artist(id: '', name: 'a'), duration: s);
    expect(d(20).isTooShort, isTrue);
    expect(d(30).isTooShort, isTrue);
    expect(d(31).isTooShort, isFalse);
    expect(d(0).isTooShort, isFalse);
    // Every Deezer/iTunes preview is 30 s, so all of them are hidden.
    expect(Track.fromITunes({'trackId': 1, 'trackName': 'p', 'previewUrl': 'u'}).isTooShort, isTrue);
    // Audius parsing applies the rule too.
    expect(Track.fromApi({'id': 'r1', 'title': 'Ringtone', 'duration': 20}).isTooShort, isTrue);
  });

  test('tracks saved before multi-source support load as Audius', () {
    final old = Track.fromMap({
      'id': 'D7KyD',
      'title': 'Old',
      'artist': {'id': 'u', 'name': 'A'},
    });
    expect(old.provider, MusicProviders.audius);
    expect(old.streamUrl, isNull);
  });

  test('mergeTracks interleaves and drops repeats by id and by title+artist', () {
    final merged = mergeTracks([
      [_t('a1', 'Song One', artist: 'X'), _t('a2', 'Song Two')],
      [_t('jamendo:9', 'song one (Live)', artist: 'x', provider: MusicProviders.jamendo), _t('a2', 'Song Two'), _t('j3', 'Three')],
    ]);
    expect(merged.map((t) => t.id), ['a1', 'a2', 'j3']);
  });

  test('every language section is backed by queries or a trending feed', () {
    for (final entry in languageSections.entries) {
      expect(entry.value, isNotEmpty);
      for (final s in entry.value) {
        expect(s.queries.isNotEmpty || s.trendingTime != null, isTrue, reason: s.id);
      }
    }
  });

  test('paged list skips pages that filter down to nothing and de-duplicates', () async {
    final pages = <int, List<Track>>{
      0: [_t('1', 'English one')],
      2: [_t('2', 'English two')],
      4: [_t('3', 'বাংলা গান'), _t('4', 'Bangla song')],
      6: [_t('4', 'Bangla song'), _t('5', 'Lalon tune')],
    };
    final source = PagedSource<Track>(
      'test',
      (o, l) async => pages[o] ?? const [],
      pageSize: 2,
      filter: (t) => detectLanguage([t.title]) == MusicLanguage.bangla,
      idOf: (t) => t.id,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(pagedTracksProvider(source), (_, __) {});
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(container.read(pagedTracksProvider(source)).items.map((t) => t.id), ['3', '4']);

    await container.read(pagedTracksProvider(source).notifier).loadMore();
    final state = container.read(pagedTracksProvider(source));
    expect(state.items.map((t) => t.id), ['3', '4', '5']);
  });
}
