import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/network/audius_client.dart';
import 'package:pulse_music/core/services/audio_player_service.dart';
import 'package:pulse_music/core/services/local_store.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/repositories/audius_repository.dart';

// Overridden in main() with the instances created during startup.
final audiusClientProvider = Provider<AudiusClient>((ref) => throw UnimplementedError());
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError());
final audioHandlerProvider = Provider<AudioPlayerService>((ref) => throw UnimplementedError());

final repositoryProvider = Provider<AudiusRepository>((ref) => AudiusRepository(ref.watch(audiusClientProvider)));

// ---- Connectivity ----------------------------------------------------------

final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool off(List<ConnectivityResult> r) => r.isEmpty || r.every((e) => e == ConnectivityResult.none);
  yield off(await c.checkConnectivity());
  await for (final r in c.onConnectivityChanged) {
    yield off(r);
  }
});

// ---- Settings --------------------------------------------------------------

class Settings {
  const Settings({this.themeMode = ThemeMode.dark, this.wifiOnly = false});
  final ThemeMode themeMode;
  final bool wifiOnly;
  Settings copyWith({ThemeMode? themeMode, bool? wifiOnly}) =>
      Settings(themeMode: themeMode ?? this.themeMode, wifiOnly: wifiOnly ?? this.wifiOnly);
}

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final s = ref.read(localStoreProvider);
    return Settings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == s.getString(StoreKeys.theme), orElse: () => ThemeMode.dark),
      wifiOnly: s.getString(StoreKeys.wifiOnly) == '1',
    );
  }

  void setTheme(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    ref.read(localStoreProvider).putString(StoreKeys.theme, m.name);
  }

  void setWifiOnly(bool v) {
    state = state.copyWith(wifiOnly: v);
    ref.read(localStoreProvider).putString(StoreKeys.wifiOnly, v ? '1' : '0');
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);

// ---- Playback state (separate from API data state) -------------------------

final mediaItemProvider = StreamProvider<MediaItem?>((ref) => ref.watch(audioHandlerProvider).mediaItem);
final playbackStateProvider = StreamProvider<PlaybackState>((ref) => ref.watch(audioHandlerProvider).playbackState);
final queueProvider = StreamProvider<List<MediaItem>>((ref) => ref.watch(audioHandlerProvider).queue);
final positionProvider = StreamProvider<Duration>((ref) => AudioService.position);

final currentTrackProvider = Provider<Track?>((ref) {
  final item = ref.watch(mediaItemProvider).valueOrNull;
  return item == null ? null : trackFromItem(item);
});

final isPlayingProvider = Provider<bool>((ref) => ref.watch(playbackStateProvider).valueOrNull?.playing ?? false);

final isBufferingProvider = Provider<bool>((ref) {
  final s = ref.watch(playbackStateProvider).valueOrNull?.processingState;
  return s == AudioProcessingState.loading || s == AudioProcessingState.buffering;
});

class PlaybackActions {
  PlaybackActions(this._ref);
  final Ref _ref;
  AudioPlayerService get _h => _ref.read(audioHandlerProvider);

  Future<bool> _canStream() async {
    if (!_ref.read(settingsProvider).wifiOnly) return true;
    final r = await Connectivity().checkConnectivity();
    final ok = r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
    if (!ok) toast('Wi-Fi only streaming is on. Connect to Wi-Fi or change it in Settings.');
    return ok;
  }

  Future<void> playTracks(List<Track> tracks, {int index = 0, bool? shuffle}) async {
    if (tracks.isEmpty) {
      toast('Nothing to play yet.');
      return;
    }
    if (!await _canStream()) return;
    await _h.playTracks(tracks, index: index, shuffle: shuffle);
  }

  Future<void> shuffle(List<Track> tracks) => playTracks(tracks, shuffle: true);

  Future<void> playNext(Track t) async {
    await _h.addToQueue(t, next: true);
    toast('Plays next');
  }

  Future<void> addToQueue(Track t) async {
    await _h.addToQueue(t);
    toast('Added to queue');
  }

  Future<void> addAllToQueue(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    await _h.addAllToQueue(tracks);
    toast('Added ${tracks.length} tracks to queue');
  }

  Future<void> togglePlay() async {
    if (_h.playbackState.value.playing) {
      await _h.pause();
    } else {
      if (!await _canStream()) return;
      await _h.play();
    }
  }
}

final playbackActionsProvider = Provider<PlaybackActions>((ref) => PlaybackActions(ref));
