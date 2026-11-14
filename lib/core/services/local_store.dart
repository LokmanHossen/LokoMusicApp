import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Thin JSON wrapper over a single Hive box. Lists are stored whole so that
/// ordering is always preserved.
class LocalStore {
  LocalStore._(this._box);
  final Box<String> _box;

  static Future<LocalStore> open() async {
    await Hive.initFlutter();
    return LocalStore._(await Hive.openBox<String>('pulse_v1'));
  }

  List<Map<String, dynamic>> maps(String key) {
    final raw = _box.get(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> putMaps(String key, List<Map<String, dynamic>> value) => _box.put(key, jsonEncode(value));

  List<String> strings(String key) {
    final raw = _box.get(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> putStrings(String key, List<String> value) => _box.put(key, jsonEncode(value));

  String? getString(String key) => _box.get(key);
  Future<void> putString(String key, String value) => _box.put(key, value);
  Future<void> remove(String key) => _box.delete(key);
}

class StoreKeys {
  static const favTracks = 'fav_tracks';
  static const favCollections = 'fav_collections';
  static const favArtists = 'fav_artists';
  static const recent = 'recent';
  static const searches = 'searches';
  static const playlists = 'playlists';
  static const queue = 'queue';
  static const queueIndex = 'queue_index';
  static const position = 'position_ms';
  static const theme = 'theme';
  static const wifiOnly = 'wifi_only';
  static const repeat = 'repeat';
  static const shuffle = 'shuffle';
}
