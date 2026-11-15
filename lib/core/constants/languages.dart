import 'package:flutter/material.dart';

/// Languages Pulse can browse and filter by. [code] is ISO 639-1, which is
/// also what Jamendo's `lang` filter expects.
enum MusicLanguage {
  bangla('bn', 'Bangla', 'বাংলা', Icons.library_music, [Color(0xFF00A86B), Color(0xFFD7263D)]),
  hindi('hi', 'Hindi', 'हिन्दी', Icons.music_video, [Color(0xFFFF9933), Color(0xFF138808)]),
  english('en', 'English', 'English', Icons.headphones, [Color(0xFF3A86FF), Color(0xFF8338EC)]);

  const MusicLanguage(this.code, this.label, this.nativeLabel, this.icon, this.colors);
  final String code, label, nativeLabel;
  final IconData icon;
  final List<Color> colors;

  static MusicLanguage? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// What a language section lists.
/// [previews] lists 30-second clips from Deezer and iTunes (mainstream songs
/// that no free API streams in full).
enum SectionKind { tracks, artists, playlists, previews }

/// One discovery section on a language page. Audius has no language filter,
/// so each section runs one or more searches and keeps only the results
/// whose detected language matches. Section queries were checked against the
/// live API (see docs/MUSIC_APIS.md).
class LanguageSection {
  const LanguageSection(this.id, this.title, this.kind, {this.queries = const [], this.sort = 'popular', this.trendingTime});
  final String id;
  final String title;
  final SectionKind kind;

  /// Audius search terms. Results from several terms are merged and de-duplicated.
  final List<String> queries;

  /// Audius `sort_method`: relevant | popular | recent.
  final String sort;

  /// When set, the section uses the trending feed (week | month | allTime)
  /// instead of search, filtered to the language.
  final String? trendingTime;
}

/// Sections per language. Album sections are left out on purpose: Audius
/// search returns no albums for any of these languages.
const languageSections = <MusicLanguage, List<LanguageSection>>{
  MusicLanguage.bangla: [
    LanguageSection('bn-latest', 'Latest Bangla songs', SectionKind.tracks, queries: ['bangla', 'bengali'], sort: 'recent'),
    LanguageSection('bn-classic', 'Classic Bangla songs', SectionKind.tracks,
        queries: ['lalon', 'baul', 'nazrul', 'rabindra sangeet', 'bangla old']),
    LanguageSection('bn-popular', 'Popular Bangla songs', SectionKind.tracks, queries: ['bangla', 'bengali']),
  ],
  MusicLanguage.hindi: [
    LanguageSection('hi-latest', 'Latest Hindi songs', SectionKind.tracks, queries: ['hindi'], sort: 'recent'),
    LanguageSection('hi-bollywood', 'Bollywood songs', SectionKind.tracks, queries: ['bollywood']),
    LanguageSection('hi-romantic', 'Romantic Hindi songs', SectionKind.tracks, queries: ['romantic hindi', 'bollywood romantic']),
    LanguageSection('hi-sad', 'Sad Hindi songs', SectionKind.tracks, queries: ['sad hindi', 'bollywood sad']),
    LanguageSection('hi-artists', 'Hindi artists', SectionKind.artists, queries: ['hindi', 'bollywood']),
    LanguageSection('hi-playlists', 'Hindi playlists', SectionKind.playlists, queries: ['hindi', 'bollywood']),
  ],
  MusicLanguage.english: [
    LanguageSection('en-trending', 'Trending songs', SectionKind.tracks, trendingTime: 'week'),
    LanguageSection('en-popular', 'Popular English songs', SectionKind.tracks, trendingTime: 'allTime'),
    LanguageSection('en-latest', 'Latest English songs', SectionKind.tracks, queries: ['english songs', 'english'], sort: 'recent'),
    LanguageSection('en-artists', 'English artists', SectionKind.artists, trendingTime: 'month'),
    LanguageSection('en-playlists', 'English playlists', SectionKind.playlists, queries: ['english']),
  ],
};
