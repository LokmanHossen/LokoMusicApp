import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/services/audio_player_service.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/core/utils/external_link.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final handler = ref.read(audioHandlerProvider);
    final st = ref.watch(playbackStateProvider).valueOrNull;
    final buffering = ref.watch(isBufferingProvider);
    final playing = st?.playing ?? false;
    final shuffle = st?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = st?.repeatMode ?? AudioServiceRepeatMode.none;
    final speed = st?.speed ?? 1.0;
    final scheme = Theme.of(context).colorScheme;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => context.pop())),
        body: const EmptyState(icon: Icons.music_note, title: 'Nothing is playing', message: 'Pick a track to start listening.'),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accent.withValues(alpha: 0.38), Theme.of(context).scaffoldBackgroundColor],
            stops: const [0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Row(children: [
                IconButton(tooltip: 'Close', iconSize: 32, icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => context.pop()),
                const Expanded(child: Center(child: Text('Now playing', style: TextStyle(fontWeight: FontWeight.w600)))),
                IconButton(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    final router = GoRouter.of(context);
                    showTrackMenu(
                      context,
                      ref,
                      track,
                      // The full player sits above the tabs: close it, then open the artist.
                      onOpenArtist: (id) {
                        router.pop();
                        router.push('/home/artist/$id');
                      },
                    );
                  },
                ),
              ]),
              Expanded(
                child: Center(
                  child: LayoutBuilder(builder: (c, box) {
                    final side = math.min(box.maxWidth, box.maxHeight);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child)),
                      child: DecoratedBox(
                        key: ValueKey(track.id),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 18))
                          ],
                        ),
                        child: Artwork(image: track.art, width: side, radius: 22),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(track.artist.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
                  ]),
                ),
                FavoriteTrackButton(track: track, size: 28),
              ]),
              // Deezer/iTunes tracks: make clear this is a short preview and
              // link to the full song (Apple requires previews to promote it).
              if (track.previewOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.timer_outlined, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('30-second preview from ${MusicProviders.label(track.provider)}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ),
                    if (track.externalUrl != null) TextButton(onPressed: () => openFullSong(track), child: const Text('Full song')),
                  ]),
                ),
              const SizedBox(height: 4),
              _SeekBar(fallbackSeconds: track.duration),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
                  icon: Icon(Icons.shuffle, color: shuffle ? AppColors.accent : null),
                  onPressed: () => handler.setShuffleMode(shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
                ),
                IconButton(
                    tooltip: 'Previous', iconSize: 40, icon: const Icon(Icons.skip_previous_rounded), onPressed: handler.skipToPrevious),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: () => ref.read(playbackActionsProvider).togglePlay(),
                    child: buffering
                        ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42),
                  ),
                ),
                IconButton(tooltip: 'Next', iconSize: 40, icon: const Icon(Icons.skip_next_rounded), onPressed: handler.skipToNext),
                IconButton(
                  tooltip: switch (repeat) {
                    AudioServiceRepeatMode.one => 'Repeat one',
                    AudioServiceRepeatMode.none => 'Repeat off',
                    _ => 'Repeat all',
                  },
                  icon: Icon(repeat == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                      color: repeat == AudioServiceRepeatMode.none ? null : AppColors.accent),
                  onPressed: () => handler.setRepeatMode(switch (repeat) {
                    AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
                    AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
                    _ => AudioServiceRepeatMode.none,
                  }),
                ),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: speed,
                  onSelected: handler.setSpeed,
                  itemBuilder: (_) => [for (final s in _speeds) PopupMenuItem(value: s, child: Text('${s}x'))],
                  child: Padding(
                      padding: const EdgeInsets.all(12), child: Text('${speed}x', style: const TextStyle(fontWeight: FontWeight.w700))),
                ),
                IconButton(tooltip: 'Volume', icon: const Icon(Icons.volume_up_outlined), onPressed: () => _showVolume(context, handler)),
                IconButton(tooltip: 'Queue', icon: const Icon(Icons.queue_music), onPressed: () => context.push('/queue')),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  void _showVolume(BuildContext context, AudioPlayerService handler) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: StreamBuilder<double>(
            stream: handler.player.volumeStream,
            initialData: handler.player.volume,
            builder: (c, snap) => Row(children: [
              const Icon(Icons.volume_mute),
              Expanded(child: Slider(value: (snap.data ?? 1.0).clamp(0.0, 1.0), onChanged: (v) => handler.setVolume(v))),
              const Icon(Icons.volume_up),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar({required this.fallbackSeconds});
  final int fallbackSeconds;
  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final total = ref.watch(mediaItemProvider).valueOrNull?.duration ?? Duration(seconds: widget.fallbackSeconds);
    final max = math.max(total.inMilliseconds.toDouble(), 1.0);
    final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(children: [
      Slider(
        value: value,
        max: max,
        onChanged: (v) => setState(() => _drag = v),
        onChangeEnd: (v) {
          ref.read(audioHandlerProvider).seek(Duration(milliseconds: v.round()));
          setState(() => _drag = null);
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(fmtClock(Duration(milliseconds: value.round())), style: TextStyle(color: muted, fontSize: 12)),
          Text(fmtClock(total), style: TextStyle(color: muted, fontSize: 12)),
        ]),
      ),
    ]);
  }
}
