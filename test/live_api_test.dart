// Live checks against the real Audius API. Skipped by default; run with:
//   flutter test test/live_api_test.dart --dart-define=LIVE=true
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/network/audius_client.dart';
import 'package:pulse_music/data/datasources/jamendo_datasource.dart';
import 'package:pulse_music/data/repositories/audius_repository.dart';
import 'package:pulse_music/data/repositories/music_repository.dart';

const _live = bool.fromEnvironment('LIVE');

void main() {
  if (!_live) {
    test('live API checks (pass --dart-define=LIVE=true to run)', () {}, skip: true);
    return;
  }

  late AudiusClient client;
  late MusicRepository music;

  setUpAll(() {
    client = AudiusClient();
    music = MusicRepository(AudiusRepository(client), JamendoDataSource());
  });

  for (final lang in MusicLanguage.values) {
    test('${lang.label}: every section returns language-matched, playable songs', () async {
      for (final s in languageSections[lang]!) {
        if (s.kind == SectionKind.playlists) {
          final lists = await music.sectionPlaylists(s, limit: 30);
          final matched = lists.where((c) => collectionMatchesLanguage(c, lang)).toList();
          // ignore: avoid_print
          print('${s.id}: ${lists.length} playlists, ${matched.length} in ${lang.label}');
          expect(matched, isNotEmpty, reason: s.id);
        } else {
          final tracks = await music.sectionTracks(s, limit: 30);
          final matched = tracks.where((t) => matchesLanguage(t, lang)).toList();
          // ignore: avoid_print
          print('${s.id}: ${tracks.length} tracks, ${matched.length} in ${lang.label}; e.g. ${matched.take(2).map((t) => t.title).join(' | ')}');
          expect(matched, isNotEmpty, reason: s.id);
          expect(matched.every((t) => t.isPlayable && t.id.isNotEmpty), isTrue);
        }
      }
    });

    test('${lang.label}: search with language filter', () async {
      final q = {MusicLanguage.bangla: 'gaan', MusicLanguage.hindi: 'pyaar', MusicLanguage.english: 'love'}[lang]!;
      final tracks = await music.searchTracks(q, language: lang, limit: 40);
      final matched = tracks.where((t) => matchesLanguage(t, lang)).length;
      // ignore: avoid_print
      print('search "$q" (${lang.code}): ${tracks.length} results, $matched in ${lang.label}');
      expect(tracks, isNotEmpty);
    });
  }

  test('Audius stream URL serves full-length audio', () async {
    final s = languageSections[MusicLanguage.bangla]!.first;
    final track = (await music.sectionTracks(s, limit: 10)).firstWhere((t) => matchesLanguage(t, MusicLanguage.bangla));
    final http = HttpClient();
    addTearDown(http.close);
    final req = await http.getUrl(Uri.parse(client.streamUrl(track.id)));
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
    final res = await req.close();
    await res.drain<void>();
    // ignore: avoid_print
    print('stream "${track.title}" (${track.duration}s): ${res.statusCode} ${res.headers.contentType}');
    expect(res.statusCode, anyOf(200, 206));
    expect(res.headers.contentType?.mimeType, startsWith('audio/'));
    expect(track.duration, greaterThan(30), reason: 'full song, not a preview');
  });
}
