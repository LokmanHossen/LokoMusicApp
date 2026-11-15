import 'package:pulse_music/core/constants/languages.dart';

final _bengaliScript = RegExp(r'[ঀ-৿]');
final _devanagari = RegExp(r'[ऀ-ॿ]');
final _latin = RegExp(r'[A-Za-z]');
// Other scripts (Arabic/Persian/Urdu, CJK, Cyrillic, Thai, Hangul): a title in
// one of these that merely mentions "Hindi" is not a Hindi song.
final _otherScript = RegExp(r'[Ѐ-ӿ؀-ۿ฀-๿぀-ヿ一-鿿가-힯]');
// "baul" is left out on purpose: it is also Spanish ("trunk") and caused
// false matches in live results.
final _banglaWords = RegExp(r'\b(bangla|bengali|bangladesh|bangladeshi|kolkata|rabindra|nazrul|lalon|adhunik)\b');
final _hindiWords = RegExp(r'\b(hindi|bollywood|hindustani|bhajan|ghazal|filmi)\b');

/// Best-effort language of a song from its text. Audius has no language
/// field, so this looks at script first, then keywords. Returns null when
/// nothing points anywhere (e.g. an empty title).
///
/// It is a heuristic: a Bangla song with a romanized title and no keywords
/// comes back as English.
MusicLanguage? detectLanguage(Iterable<String?> texts) {
  final joined = texts.whereType<String>().join(' ');
  if (joined.trim().isEmpty) return null;
  if (_bengaliScript.hasMatch(joined)) return MusicLanguage.bangla;
  if (_devanagari.hasMatch(joined)) return MusicLanguage.hindi;
  if (_otherScript.hasMatch(joined)) return null;
  final lower = joined.toLowerCase();
  if (_banglaWords.hasMatch(lower)) return MusicLanguage.bangla;
  if (_hindiWords.hasMatch(lower)) return MusicLanguage.hindi;
  if (_latin.hasMatch(joined)) return MusicLanguage.english;
  return null;
}

/// Key used to spot the same song coming from two providers.
String songKey(String title, String artist) {
  String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');
  return '${norm(title)}|${norm(artist)}';
}
