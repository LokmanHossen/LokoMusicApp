import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/data/datasources/youtube_datasource.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

/// Paged list of YouTube music videos ("View all" and the search tab).
/// Each page is one `search.list` call (100 quota units), so the next page
/// loads only when the user scrolls to the end.
class VideoResults extends ConsumerStatefulWidget {
  const VideoResults(
      {super.key,
      required this.query,
      this.language,
      this.popular = false,
      this.songs = false,
      this.contentType = YouTubeContentType.music});
  final String query;
  final MusicLanguage? language;

  /// Show the trending music chart instead of searching [query].
  final bool popular;

  /// Single songs only (see isSingleSong).
  final bool songs;

  final YouTubeContentType contentType;

  @override
  ConsumerState<VideoResults> createState() => _VideoResultsState();
}

class _VideoResultsState extends ConsumerState<VideoResults> {
  final _videos = <YouTubeVideo>[];
  final _seen = <String>{};
  String? _next;
  bool _loading = false, _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query ||
        old.language != widget.language ||
        old.popular != widget.popular ||
        old.songs != widget.songs ||
        old.contentType != widget.contentType) {
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _videos.clear();
      _seen.clear();
      _next = null;
      _done = false;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final yt = ref.read(youtubeProvider);
      final page = widget.popular
          ? await yt.popularMusicPage(maxResults: 25, pageToken: _next)
          : await yt.searchVideos(
              widget.query,
              language: widget.language,
              pageToken: _next,
              songsOnly: widget.songs,
              contentType: widget.contentType,
            );
      if (!mounted) return;
      setState(() {
        _videos.addAll(page.videos.where((v) => _seen.add(v.id)));
        _next = page.nextPageToken;
        _done = _next == null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_videos.isEmpty && _error != null) {
      return ErrorState(message: _error!, onRetry: _reset);
    }
    if (_videos.isEmpty && _done) {
      return const EmptyState(
          icon: Icons.smart_display_outlined, title: 'No music videos found');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) {
          _load();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _videos.length + 1,
        itemBuilder: (c, i) {
          if (i < _videos.length) {
            return VideoTile(video: _videos[i], list: _videos);
          }
          if (_loading) {
            return const Padding(
                padding: EdgeInsets.all(20),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
          }
          if (_error != null) {
            return Padding(
                padding: const EdgeInsets.all(12),
                child: ErrorState(message: _error!, onRetry: _load));
          }
          return const SizedBox(height: 24);
        },
      ),
    );
  }
}

class VideoListScreen extends StatelessWidget {
  const VideoListScreen({super.key, required this.args});
  final VideoListArgs args;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(args.title)),
        body: VideoResults(
          query: args.query,
          language: args.language,
          popular: args.popular,
          songs: args.songs,
          contentType: args.contentType,
        ),
      );
}
