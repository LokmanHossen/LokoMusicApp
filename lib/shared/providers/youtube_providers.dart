import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/data/datasources/youtube_datasource.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';

final youtubeProvider = Provider<YouTubeDataSource>((ref) => YouTubeDataSource(store: ref.watch(localStoreProvider)));

/// Search term used for each language's "Music videos" row.
const youtubeLanguageQuery = {
  MusicLanguage.bangla: 'bangla song',
  MusicLanguage.hindi: 'hindi song',
  MusicLanguage.english: 'english song',
};

/// First page of music videos for a language page (cached 6 h on device).
final youtubeLanguageVideosProvider = FutureProvider.autoDispose.family<List<YouTubeVideo>, MusicLanguage>((ref, lang) async {
  final page = await ref.watch(youtubeProvider).searchVideos(youtubeLanguageQuery[lang]!, language: lang, maxResults: 20);
  return page.videos;
});

/// Search terms for the "Songs · YouTube" rows (single songs, not videos
/// compilations; see [isSingleSong]).
const youtubeSongQuery = {
  MusicLanguage.bangla: 'bangla song',
  MusicLanguage.hindi: 'new hindi song',
  MusicLanguage.english: 'english song',
};

/// Home's songs row: new Bangla and Hindi songs (YouTube's "|" means OR).
const youtubeHomeSongQuery = 'new bangla song | new hindi song';

final youtubeLanguageSongsProvider = FutureProvider.autoDispose.family<List<YouTubeVideo>, MusicLanguage>((ref, lang) async {
  final page = await ref.watch(youtubeProvider).searchVideos(youtubeSongQuery[lang]!, language: lang, songsOnly: true);
  return page.videos;
});

final youtubeHomeSongsProvider = FutureProvider.autoDispose<List<YouTubeVideo>>((ref) async {
  final page = await ref.watch(youtubeProvider).searchVideos(youtubeHomeSongQuery, songsOnly: true);
  return page.videos;
});

/// Trending music videos in Bangladesh, for Home (cached 6 h, 1 quota unit).
final youtubePopularProvider = FutureProvider.autoDispose<List<YouTubeVideo>>((ref) => ref.watch(youtubeProvider).popularMusic());

/// Arguments for the paged videos list.
class VideoListArgs {
  const VideoListArgs(this.title, this.query, {this.language, this.songs = false}) : popular = false;

  /// The trending music chart (Bangladesh) instead of a search.
  const VideoListArgs.popular(this.title)
      : query = '',
        language = null,
        songs = false,
        popular = true;

  final String title, query;
  final MusicLanguage? language;
  final bool popular;

  /// Single songs only (no compilations), as in the "Songs" rows.
  final bool songs;
}
