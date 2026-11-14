import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/services/local_store.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';

// ---- Favorites ---------------------------------------------------------------

class FavoritesState {
  const FavoritesState({this.tracks = const [], this.collections = const [], this.artists = const []});
  final List<Track> tracks;
  final List<Collection> collections;
  final List<Artist> artists;

  bool hasTrack(String id) => tracks.any((t) => t.id == id);
  bool hasCollection(String id) => collections.any((c) => c.id == id);
  bool hasArtist(String id) => artists.any((a) => a.id == id);
  List<Collection> get albums => collections.where((c) => c.isAlbum).toList();
  List<Collection> get playlists => collections.where((c) => !c.isAlbum).toList();

  FavoritesState copyWith({List<Track>? tracks, List<Collection>? collections, List<Artist>? artists}) =>
      FavoritesState(
        tracks: tracks ?? this.tracks,
        collections: collections ?? this.collections,
        artists: artists ?? this.artists,
      );
}

class FavoritesController extends Notifier<FavoritesState> {
  LocalStore get _s => ref.read(localStoreProvider);

  @override
  FavoritesState build() {
    final s = ref.read(localStoreProvider);
    List<T> load<T>(String key, T Function(Map<String, dynamic>) f) {
      try {
        return s.maps(key).map(f).toList();
      } catch (_) {
        return [];
      }
    }

    return FavoritesState(
      tracks: load(StoreKeys.favTracks, Track.fromMap),
      collections: load(StoreKeys.favCollections, Collection.fromMap),
      artists: load(StoreKeys.favArtists, Artist.fromMap),
    );
  }

  void toggleTrack(Track t) {
    final list = state.hasTrack(t.id) ? state.tracks.where((x) => x.id != t.id).toList() : [t, ...state.tracks];
    state = state.copyWith(tracks: list);
    _s.putMaps(StoreKeys.favTracks, list.map((e) => e.toMap()).toList());
  }

  void toggleCollection(Collection c) {
    final list =
        state.hasCollection(c.id) ? state.collections.where((x) => x.id != c.id).toList() : [c, ...state.collections];
    state = state.copyWith(collections: list);
    _s.putMaps(StoreKeys.favCollections, list.map((e) => e.toMap()).toList());
  }

  void toggleArtist(Artist a) {
    final list = state.hasArtist(a.id) ? state.artists.where((x) => x.id != a.id).toList() : [a, ...state.artists];
    state = state.copyWith(artists: list);
    _s.putMaps(StoreKeys.favArtists, list.map((e) => e.toMap()).toList());
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>(FavoritesController.new);

// ---- Recently played ---------------------------------------------------------

class RecentlyPlayedController extends Notifier<List<Track>> {
  @override
  List<Track> build() {
    try {
      return ref.read(localStoreProvider).maps(StoreKeys.recent).map(Track.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  void add(Track t) {
    final list = [t, ...state.where((x) => x.id != t.id)].take(50).toList();
    state = list;
    ref.read(localStoreProvider).putMaps(StoreKeys.recent, list.map((e) => e.toMap()).toList());
  }

  void clear() {
    state = [];
    ref.read(localStoreProvider).remove(StoreKeys.recent);
  }
}

final recentProvider = NotifierProvider<RecentlyPlayedController, List<Track>>(RecentlyPlayedController.new);

// ---- Local playlists ---------------------------------------------------------

class LocalPlaylistsController extends Notifier<List<LocalPlaylist>> {
  @override
  List<LocalPlaylist> build() {
    try {
      return ref.read(localStoreProvider).maps(StoreKeys.playlists).map(LocalPlaylist.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<LocalPlaylist> list) {
    state = list;
    ref.read(localStoreProvider).putMaps(StoreKeys.playlists, list.map((e) => e.toMap()).toList());
  }

  String create(String name, [List<Track> tracks = const []]) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _save([...state, LocalPlaylist(id: id, name: name.isEmpty ? 'My playlist' : name, tracks: tracks)]);
    return id;
  }

  void rename(String id, String name) =>
      _save([for (final p in state) p.id == id ? p.copyWith(name: name) : p]);

  void delete(String id) => _save(state.where((p) => p.id != id).toList());

  /// Returns how many tracks were actually added (duplicates are skipped).
  int addTracks(String id, List<Track> tracks) {
    var added = 0;
    final updated = <LocalPlaylist>[];
    for (final p in state) {
      if (p.id != id) {
        updated.add(p);
        continue;
      }
      final merged = [...p.tracks];
      for (final t in tracks) {
        if (!merged.any((x) => x.id == t.id)) {
          merged.add(t);
          added++;
        }
      }
      updated.add(p.copyWith(tracks: merged));
    }
    _save(updated);
    return added;
  }

  void removeTrack(String id, String trackId) => _save([
        for (final p in state)
          if (p.id == id) p.copyWith(tracks: p.tracks.where((t) => t.id != trackId).toList()) else p
      ]);
}

final localPlaylistsProvider =
    NotifierProvider<LocalPlaylistsController, List<LocalPlaylist>>(LocalPlaylistsController.new);

// ---- Search history ----------------------------------------------------------

class SearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(localStoreProvider).strings(StoreKeys.searches);

  void add(String q) {
    final t = q.trim();
    if (t.length < 2) return;
    final list = [t, ...state.where((x) => x.toLowerCase() != t.toLowerCase())].take(15).toList();
    state = list;
    ref.read(localStoreProvider).putStrings(StoreKeys.searches, list);
  }

  void remove(String q) {
    state = state.where((x) => x != q).toList();
    ref.read(localStoreProvider).putStrings(StoreKeys.searches, state);
  }

  void clear() {
    state = [];
    ref.read(localStoreProvider).remove(StoreKeys.searches);
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistoryController, List<String>>(SearchHistoryController.new);

/// Wires playback events to history and surfaces playback errors.
final playbackRecorderProvider = Provider<void>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  handler.onTrackPlayed = (t) => ref.read(recentProvider.notifier).add(t);
  ref.onDispose(() => handler.onTrackPlayed = null);
});
