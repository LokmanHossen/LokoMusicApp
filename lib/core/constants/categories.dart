import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A browsable category. If [genre] is set, Audius' genre filter is used.
/// Otherwise [searchQuery] runs through the search endpoint (tag-style).
class Category {
  const Category(this.key, this.label, this.icon, this.colors, {this.genre, this.searchQuery});
  final String key;
  final String label;
  final IconData icon;
  final List<Color> colors;
  final String? genre;
  final String? searchQuery;
}

class Categories {
  static const all = <Category>[
    Category('electronic', 'Electronic', Icons.graphic_eq, [Color(0xFF5B3DF5), Color(0xFF00C2FF)], genre: 'Electronic'),
    Category('hiphop', 'Hip-Hop', Icons.mic, [Color(0xFFFF6B35), Color(0xFFB5179E)], genre: 'Hip-Hop/Rap'),
    Category('pop', 'Pop', Icons.star, [Color(0xFFFF5D8F), Color(0xFFFFB86B)], genre: 'Pop'),
    Category('rock', 'Rock', CupertinoIcons.guitars, [Color(0xFFD7263D), Color(0xFF5C0A1C)], genre: 'Rock'),
    Category('dance', 'Dance', Icons.nightlife, [Color(0xFFF72585), Color(0xFF7209B7)], genre: 'Electronic', searchQuery: 'dance'),
    Category('classical', 'Classical', Icons.piano, [Color(0xFF3A506B), Color(0xFF1C2541)], genre: 'Classical'),
    Category('jazz', 'Jazz', Icons.queue_music, [Color(0xFFC9892B), Color(0xFF4A2C0F)], genre: 'Jazz'),
    Category('rnb', 'R&B', Icons.favorite, [Color(0xFF9D4EDD), Color(0xFF3C096C)], genre: 'R&B/Soul'),
    Category('ambient', 'Ambient', Icons.waves, [Color(0xFF2EC4B6), Color(0xFF0B3C49)], genre: 'Ambient'),
    Category('country', 'Country', Icons.landscape, [Color(0xFFB08968), Color(0xFF5C4033)], genre: 'Country'),
    Category('alternative', 'Alternative', Icons.bolt, [Color(0xFF06D6A0), Color(0xFF118AB2)], genre: 'Alternative'),
    Category('metal', 'Metal', Icons.whatshot, [Color(0xFF6C757D), Color(0xFF111111)], genre: 'Metal'),
    Category('folk', 'Folk', Icons.forest, [Color(0xFF8AB17D), Color(0xFF2D6A4F)], genre: 'Folk'),
    Category('instrumental', 'Instrumental', Icons.music_note, [Color(0xFF4CC9F0), Color(0xFF4361EE)], searchQuery: 'instrumental'),
    Category('podcasts', 'Podcasts', Icons.podcasts, [Color(0xFFFFB703), Color(0xFFFB5607)], genre: 'Podcasts'),
  ];

  static Category byKey(String key) => all.firstWhere((c) => c.key == key, orElse: () => all.first);
}

/// Genres offered as search filters (exact Audius genre strings).
const searchGenres = <String>[
  'Electronic',
  'Hip-Hop/Rap',
  'Pop',
  'Rock',
  'Alternative',
  'Metal',
  'Folk',
  'Jazz',
  'Classical',
  'Ambient',
  'Country',
  'R&B/Soul',
  'Podcasts',
];
