import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Plays YouTube music videos in YouTube's official embedded player, with the
/// rest of the list they were opened from shown below as "More videos".
///
/// YouTube's terms allow video playback in the foreground only: no
/// audio-only mode, no background or lock-screen playback, no downloads. So
/// videos never go through the app's audio player or queue, and the app's
/// own music is paused while a video is open.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.video, this.list = const []});
  final YouTubeVideo video;

  /// The list the video was opened from (YouTube's API has no "related
  /// videos" any more, so this is what "More videos" shows).
  final List<YouTubeVideo> list;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  late final List<YouTubeVideo> _list = widget.list.isEmpty ? [widget.video] : widget.list;
  late int _index = _list.indexWhere((v) => v.id == widget.video.id).clamp(0, _list.length - 1);
  late final YoutubePlayerController _controller = YoutubePlayerController.fromVideoId(
    videoId: _list[_index].id,
    autoPlay: true,
    params: const YoutubePlayerParams(showControls: true, showFullscreenButton: true, strictRelatedVideos: true),
  );
  StreamSubscription<YoutubePlayerValue>? _sub;
  PlayerState _lastState = PlayerState.unknown;

  YouTubeVideo get _current => _list[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Never play the app's music and a video at the same time.
    final audio = ref.read(audioHandlerProvider);
    if (audio.playbackState.value.playing) audio.pause();
    // Auto-play the next video in the list when one ends.
    _sub = _controller.stream.listen((value) {
      final state = value.playerState;
      if (state == PlayerState.ended && _lastState != PlayerState.ended && _index + 1 < _list.length) _play(_index + 1);
      _lastState = state;
    });
  }

  void _play(int i) {
    if (i < 0 || i >= _list.length) return;
    setState(() => _index = i);
    _controller.loadVideoById(videoId: _list[i].id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foreground-only playback, as YouTube's policies require.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _controller.pauseVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _controller.close();
    super.dispose();
  }

  Future<void> _openInYouTube() async {
    final ok = await launchUrl(Uri.parse(_current.watchUrl), mode: LaunchMode.externalApplication);
    if (!ok) toast("Couldn't open YouTube.");
  }

  @override
  Widget build(BuildContext context) {
    final v = _current;
    final scheme = Theme.of(context).colorScheme;
    final more = _list.length > 1;
    return Scaffold(
      appBar: AppBar(title: const YouTubeTag()),
      body: Column(children: [
        // The player stays fixed at the top while the list scrolls below.
        YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(v.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(v.channel, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (more)
                  IconButton.filledTonal(
                    tooltip: 'Previous',
                    onPressed: _index > 0 ? () => _play(_index - 1) : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                if (more)
                  IconButton.filledTonal(
                    tooltip: 'Next',
                    onPressed: _index + 1 < _list.length ? () => _play(_index + 1) : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                FilledButton.tonalIcon(onPressed: _openInYouTube, icon: const Icon(Icons.open_in_new), label: const Text('Open in YouTube')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'YouTube videos play here only while the app is open. Your Loko Music song was paused; resume it from the mini player.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            if (more) ...[
              const SectionHeader(title: 'More videos'),
              for (var i = 0; i < _list.length; i++)
                VideoTile(video: _list[i], selected: i == _index, onTap: () => _play(i)),
            ],
          ]),
        ),
      ]),
    );
  }
}
