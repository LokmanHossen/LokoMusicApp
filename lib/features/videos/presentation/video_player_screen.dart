import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Plays a YouTube music video in YouTube's official embedded player.
///
/// YouTube's terms allow video playback in the foreground only: no
/// audio-only mode, no background or lock-screen playback, no downloads. So
/// videos never go through the app's audio player or queue, and the app's
/// own music is paused while a video is open.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.video});
  final YouTubeVideo video;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with WidgetsBindingObserver {
  late final YoutubePlayerController _controller = YoutubePlayerController.fromVideoId(
    videoId: widget.video.id,
    autoPlay: true,
    params: const YoutubePlayerParams(showControls: true, showFullscreenButton: true, strictRelatedVideos: true),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Never play the app's music and a video at the same time.
    final audio = ref.read(audioHandlerProvider);
    if (audio.playbackState.value.playing) audio.pause();
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
    _controller.close();
    super.dispose();
  }

  Future<void> _openInYouTube() async {
    final ok = await launchUrl(Uri.parse(widget.video.watchUrl), mode: LaunchMode.externalApplication);
    if (!ok) toast("Couldn't open YouTube.");
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const YouTubeTag()),
      body: ListView(children: [
        YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(v.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(v.channel, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            FilledButton.tonalIcon(onPressed: _openInYouTube, icon: const Icon(Icons.open_in_new), label: const Text('Open in YouTube')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'YouTube videos play here only while the app is open. Your Loko Music song was paused and you can resume it from the mini player.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}
