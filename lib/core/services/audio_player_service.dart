import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pulse_music/core/services/local_store.dart';
import 'package:pulse_music/data/models/models.dart';

MediaItem trackToItem(Track t) => MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist.name,
      genre: t.genre,
      duration: t.duration > 0 ? Duration(seconds: t.duration) : null,
      artUri: t.art.best != null ? Uri.tryParse(t.art.best!) : null,
      extras: {'track': t.toMap()},
    );

Track trackFromItem(MediaItem i) => Track.fromMap(Map<String, dynamic>.from(i.extras!['track'] as Map));

/// The single, app-wide playback service. One [AudioPlayer], one queue.
/// Owns background playback, lock-screen/notification controls, interruption
/// handling (via audio_session + just_audio), queue, shuffle and repeat.
class AudioPlayerService extends BaseAudioHandler with SeekHandler {
  AudioPlayerService({required this.streamUrl, required this.store}) {
    _init();
  }

  /// Resolves a playable, full-length URL for a track of any provider.
  final String Function(Track track) streamUrl;
  final LocalStore store;
  final AudioPlayer player = AudioPlayer();

  /// Called each time a track actually starts loading for playback.
  void Function(Track track)? onTrackPlayed;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  final _rng = Random();
  bool _shuffle = false;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;
  int _index = -1;
  bool _sourceLoaded = false;
  int _loadToken = 0;
  int _consecutiveErrors = 0;
  Duration? _resumePosition;

  bool get shuffleEnabled => _shuffle;
  AudioServiceRepeatMode get repeatMode => _repeat;
  int get currentIndex => _index;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    player.playbackEventStream.listen((_) => _broadcast(), onError: (Object e, StackTrace s) => _onStreamError());
    player.playingStream.listen((playing) {
      _broadcast();
      if (!playing) _savePosition();
    });
    player.speedStream.listen((_) => _broadcast());
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _onCompleted();
    });

    _shuffle = store.getString(StoreKeys.shuffle) == '1';
    _repeat = AudioServiceRepeatMode.values.firstWhere(
      (m) => m.name == store.getString(StoreKeys.repeat),
      orElse: () => AudioServiceRepeatMode.none,
    );
    _restore();
  }

  // ---- State broadcasting --------------------------------------------------

  void _broadcast() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _index >= 0 ? _index : null,
      repeatMode: _repeat,
      shuffleMode: _shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  // ---- Persistence ---------------------------------------------------------

  void _restore() {
    final saved = store.maps(StoreKeys.queue);
    if (saved.isEmpty) return;
    try {
      final tracks = saved.map(Track.fromMap).toList();
      final idx = int.tryParse(store.getString(StoreKeys.queueIndex) ?? '') ?? 0;
      queue.add(tracks.map(trackToItem).toList());
      _index = idx.clamp(0, tracks.length - 1);
      mediaItem.add(queue.value[_index]);
      final ms = int.tryParse(store.getString(StoreKeys.position) ?? '');
      if (ms != null && ms > 0) _resumePosition = Duration(milliseconds: ms);
      _broadcast();
    } catch (_) {
      store.remove(StoreKeys.queue);
    }
  }

  void _persistQueue() {
    store.putMaps(StoreKeys.queue, queue.value.map((i) => Map<String, dynamic>.from(i.extras!['track'] as Map)).toList());
    store.putString(StoreKeys.queueIndex, '$_index');
  }

  void _savePosition() {
    if (_index >= 0) store.putString(StoreKeys.position, '${player.position.inMilliseconds}');
  }

  // ---- Loading & errors ----------------------------------------------------

  Future<void> _load(int i, {bool autoplay = true}) async {
    final items = queue.value;
    if (i < 0 || i >= items.length) return;
    final token = ++_loadToken;
    _index = i;
    final item = items[i];
    mediaItem.add(item);
    _broadcast();
    store.putString(StoreKeys.queueIndex, '$i');
    store.putString(StoreKeys.position, '0');
    try {
      // Resolved at play time, so an Audius redirect is always fresh.
      await player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl(trackFromItem(item))), tag: item));
      if (token != _loadToken) return;
      _sourceLoaded = true;
      final resume = _resumePosition;
      _resumePosition = null;
      if (resume != null) await player.seek(resume);
      _consecutiveErrors = 0;
      if (autoplay) {
        unawaited(player.play());
        onTrackPlayed?.call(trackFromItem(item));
      }
    } on PlayerInterruptedException {
      // A newer load superseded this one.
    } catch (_) {
      if (token != _loadToken) return;
      _handleUnavailable(item);
    }
  }

  void _handleUnavailable(MediaItem item) {
    _errors.add('"${item.title}" can\'t be played right now.');
    _consecutiveErrors++;
    if (_consecutiveErrors < 3 && _nextIndex(auto: false) != null) {
      skipToNext();
    } else {
      player.stop();
      _sourceLoaded = false;
    }
  }

  void _onStreamError() {
    if (_index >= 0 && _index < queue.value.length) _handleUnavailable(queue.value[_index]);
  }

  int? _nextIndex({required bool auto}) {
    final n = queue.value.length;
    if (n == 0) return null;
    if (auto && _repeat == AudioServiceRepeatMode.one) return _index;
    if (_shuffle && n > 1) {
      int r;
      do {
        r = _rng.nextInt(n);
      } while (r == _index);
      return r;
    }
    if (_index + 1 < n) return _index + 1;
    if (_repeat != AudioServiceRepeatMode.none) return 0;
    return null;
  }

  Future<void> _onCompleted() async {
    final next = _nextIndex(auto: true);
    if (next == null) {
      await player.pause();
      await player.seek(Duration.zero);
      _broadcast();
    } else if (next == _index) {
      await player.seek(Duration.zero);
      unawaited(player.play());
    } else {
      await _load(next);
    }
  }

  // ---- Standard handler API ------------------------------------------------

  @override
  Future<void> play() async {
    if (_index < 0) return;
    if (!_sourceLoaded) {
      await _load(_index);
      return;
    }
    if (player.processingState == ProcessingState.completed) await player.seek(Duration.zero);
    unawaited(player.play());
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _savePosition();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    _savePosition();
    await player.stop();
    _sourceLoaded = false;
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final n = _nextIndex(auto: false);
    if (n != null) await _load(n);
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.position > const Duration(seconds: 3) || queue.value.isEmpty) {
      await player.seek(Duration.zero);
      return;
    }
    if (_index > 0) {
      await _load(_index - 1);
    } else if (_repeat != AudioServiceRepeatMode.none) {
      await _load(queue.value.length - 1);
    } else {
      await player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => _load(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode == AudioServiceRepeatMode.group ? AudioServiceRepeatMode.all : repeatMode;
    store.putString(StoreKeys.repeat, _repeat.name);
    _broadcast();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffle = shuffleMode != AudioServiceShuffleMode.none;
    store.putString(StoreKeys.shuffle, _shuffle ? '1' : '0');
    _broadcast();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed);
    _broadcast();
  }

  Future<void> setVolume(double volume) => player.setVolume(volume);

  // ---- Queue API -----------------------------------------------------------

  /// Replaces the queue and starts playing [tracks] from [index].
  /// [shuffle] null keeps the current shuffle mode.
  Future<void> playTracks(List<Track> tracks, {int index = 0, bool? shuffle}) async {
    if (tracks.isEmpty) return;
    if (shuffle != null) await setShuffleMode(shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
    queue.add(tracks.map(trackToItem).toList());
    final start = (shuffle == true) ? _rng.nextInt(tracks.length) : index.clamp(0, tracks.length - 1);
    _consecutiveErrors = 0;
    _resumePosition = null;
    await _load(start);
    _persistQueue();
  }

  Future<void> addToQueue(Track track, {bool next = false}) => addAllToQueue([track], next: next);

  Future<void> addAllToQueue(List<Track> tracks, {bool next = false}) async {
    if (tracks.isEmpty) return;
    final items = [...queue.value];
    if (items.isEmpty) {
      await playTracks(tracks);
      return;
    }
    final newItems = tracks.map(trackToItem).toList();
    if (next) {
      items.insertAll((_index + 1).clamp(0, items.length), newItems);
    } else {
      items.addAll(newItems);
    }
    queue.add(items);
    _broadcast();
    _persistQueue();
  }

  Future<void> removeAt(int i) async {
    final items = [...queue.value];
    if (i < 0 || i >= items.length) return;
    if (items.length == 1) {
      await clearQueue();
      return;
    }
    final wasCurrent = i == _index;
    final wasPlaying = player.playing;
    items.removeAt(i);
    queue.add(items);
    if (wasCurrent) {
      _index = _index.clamp(0, items.length - 1);
      await _load(_index, autoplay: wasPlaying);
    } else if (i < _index) {
      _index--;
    }
    _broadcast();
    _persistQueue();
  }

  /// [newIndex] must already be adjusted (ReorderableListView semantics).
  void moveItem(int oldIndex, int newIndex) {
    final items = [...queue.value];
    if (oldIndex < 0 || oldIndex >= items.length || newIndex < 0 || newIndex >= items.length) return;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    if (oldIndex == _index) {
      _index = newIndex;
    } else if (oldIndex < _index && newIndex >= _index) {
      _index--;
    } else if (oldIndex > _index && newIndex <= _index) {
      _index++;
    }
    queue.add(items);
    _broadcast();
    _persistQueue();
  }

  Future<void> clearQueue() async {
    _loadToken++;
    await player.stop();
    _sourceLoaded = false;
    queue.add(const []);
    mediaItem.add(null);
    _index = -1;
    store.remove(StoreKeys.queue);
    store.remove(StoreKeys.queueIndex);
    _broadcast();
  }

  /// Shuffles upcoming order; the current track moves to the front.
  void shuffleQueue() {
    final items = [...queue.value];
    if (items.length < 2 || _index < 0) return;
    final current = items.removeAt(_index);
    items.shuffle(_rng);
    items.insert(0, current);
    _index = 0;
    queue.add(items);
    _broadcast();
    _persistQueue();
  }
}
