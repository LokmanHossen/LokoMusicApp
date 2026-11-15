/// Immutable models. `fromApi` parses Audius responses, `fromJamendo` parses
/// Jamendo responses, `fromMap/toMap` is used for the local Hive database.
library;

import 'package:pulse_music/core/utils/language_detect.dart';

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _str(dynamic v, [String fallback = '']) => v is String ? v : (v == null ? fallback : '$v');

class ImageSet {
  const ImageSet({this.small, this.medium, this.large});
  final String? small, medium, large;

  factory ImageSet.fromApi(dynamic m) {
    if (m is! Map) return const ImageSet();
    String? g(String k) {
      final v = m[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    return ImageSet(small: g('150x150'), medium: g('480x480'), large: g('1000x1000'));
  }

  factory ImageSet.fromCover(dynamic m) {
    if (m is! Map) return const ImageSet();
    String? g(String k) {
      final v = m[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    return ImageSet(medium: g('640x'), large: g('2000x'));
  }

  factory ImageSet.fromMap(dynamic m) {
    if (m is! Map) return const ImageSet();
    return ImageSet(small: m['s'] as String?, medium: m['m'] as String?, large: m['l'] as String?);
  }

  Map<String, dynamic> toMap() => {'s': small, 'm': medium, 'l': large};

  bool get isEmpty => small == null && medium == null && large == null;
  String? get best => medium ?? large ?? small;

  /// Picks the smallest sensible variant for [pixels] on screen.
  String? forSize(double pixels) {
    if (pixels <= 170) return small ?? medium ?? large;
    if (pixels <= 520) return medium ?? large ?? small;
    return large ?? medium ?? small;
  }
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.handle = '',
    this.verified = false,
    this.avatar = const ImageSet(),
    this.cover = const ImageSet(),
    this.bio,
    this.followers = 0,
    this.trackCount = 0,
    this.playlistCount = 0,
  });

  final String id, name, handle;
  final bool verified;
  final ImageSet avatar, cover;
  final String? bio;
  final int followers, trackCount, playlistCount;

  factory Artist.fromApi(Map<String, dynamic> j) => Artist(
        id: _str(j['id']),
        name: _str(j['name'], 'Unknown artist'),
        handle: _str(j['handle']),
        verified: j['is_verified'] == true,
        avatar: ImageSet.fromApi(j['profile_picture']),
        cover: ImageSet.fromCover(j['cover_photo']),
        bio: j['bio'] is String && (j['bio'] as String).trim().isNotEmpty ? j['bio'] as String : null,
        followers: _int(j['follower_count']),
        trackCount: _int(j['track_count']),
        playlistCount: _int(j['playlist_count']),
      );

  factory Artist.fromMap(Map<String, dynamic> j) => Artist(
        id: _str(j['id']),
        name: _str(j['name']),
        handle: _str(j['handle']),
        verified: j['verified'] == true,
        avatar: ImageSet.fromMap(j['avatar']),
        cover: ImageSet.fromMap(j['cover']),
        bio: j['bio'] as String?,
        followers: _int(j['followers']),
        trackCount: _int(j['trackCount']),
        playlistCount: _int(j['playlistCount']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'handle': handle,
        'verified': verified,
        'avatar': avatar.toMap(),
        'cover': cover.toMap(),
        'bio': bio,
        'followers': followers,
        'trackCount': trackCount,
        'playlistCount': playlistCount,
      };
}

/// Where a track comes from. Each provider has its own id space.
abstract final class MusicProviders {
  static const audius = 'audius';
  static const jamendo = 'jamendo';

  /// Deezer and iTunes only allow 30-second previews (no full songs).
  static const deezer = 'deezer';
  static const itunes = 'itunes';

  /// Name shown to users ("Preview · Apple Music").
  static String label(String provider) => switch (provider) {
        jamendo => 'Jamendo',
        deezer => 'Deezer',
        itunes => 'Apple Music',
        _ => 'Audius',
      };
}

/// Length of a Deezer/iTunes preview clip.
const previewSeconds = 30;

String? _optStr(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

/// The app's single song model. Every provider maps into it, so the player,
/// queue, favourites and playlists work the same for all sources.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.art = const ImageSet(),
    this.duration = 0,
    this.plays = 0,
    this.favorites = 0,
    this.genre,
    this.releaseDate,
    this.streamable = true,
    this.provider = MusicProviders.audius,
    this.streamUrl,
    this.album,
    this.language,
    this.previewOnly = false,
    this.externalUrl,
  });

  final String id, title;
  final Artist artist;
  final ImageSet art;
  final int duration, plays, favorites;
  final String? genre, releaseDate;
  final bool streamable;

  /// [MusicProviders] value.
  final String provider;

  /// Direct, full-length audio URL. Null for Audius, whose stream URL is
  /// built from [id] at play time (it redirects to the audio file).
  final String? streamUrl;
  final String? album;

  /// ISO 639-1 code from [MusicLanguage] (detected or provider-supplied).
  final String? language;

  /// True when only a short preview can be played in the app (Deezer,
  /// iTunes). The full song is at [externalUrl], on the provider's own app.
  final bool previewOnly;

  /// The song's page on its provider (e.g. Apple Music, Deezer), if any.
  final String? externalUrl;

  bool get isPlayable => streamable;

  /// Songs of 30 seconds or less (previews, ringtones, clips) are not shown
  /// anywhere in the app. Unknown length (0) is kept.
  bool get isTooShort => duration > 0 && duration <= maxHiddenSeconds;

  static const maxHiddenSeconds = 30;

  /// True for tracks whose artist and album pages exist in the app (Audius).
  bool get hasDetailPages => provider == MusicProviders.audius;

  /// Maps a Deezer `/search` or `/track/{id}` result. Deezer's preview URLs
  /// expire after a few hours, so none is stored: the player asks Deezer for a
  /// fresh one at play time (see the player's stream resolver).
  factory Track.fromDeezer(Map<String, dynamic> j, {String? language}) {
    final album = j['album'] is Map ? Map<String, dynamic>.from(j['album'] as Map) : const <String, dynamic>{};
    final artist = j['artist'] is Map ? Map<String, dynamic>.from(j['artist'] as Map) : const <String, dynamic>{};
    final title = _str(j['title_short'], _str(j['title'], 'Untitled'));
    final artistName = _str(artist['name'], 'Unknown artist');
    final albumName = _optStr(album['title']);
    return Track(
      id: 'deezer:${_str(j['id'])}',
      title: title,
      artist: Artist(id: '', name: artistName),
      art: ImageSet(
          small: _optStr(album['cover_small']),
          medium: _optStr(album['cover_medium']),
          large: _optStr(album['cover_xl']) ?? _optStr(album['cover_big'])),
      duration: previewSeconds,
      album: albumName,
      provider: MusicProviders.deezer,
      streamable: j['readable'] != false && _optStr(j['preview']) != null,
      previewOnly: true,
      externalUrl: _optStr(j['link']),
      language: language ?? detectLanguage([title, artistName, albumName])?.code,
    );
  }

  /// Maps an iTunes Search API song. Preview URLs are stable, so they are
  /// stored. Apple only allows previews for promoting the song, so the app
  /// always offers "Open in Apple Music" next to them.
  factory Track.fromITunes(Map<String, dynamic> j, {String? language}) {
    final title = _str(j['trackName'], 'Untitled');
    final artistName = _str(j['artistName'], 'Unknown artist');
    final albumName = _optStr(j['collectionName']);
    final art100 = _optStr(j['artworkUrl100']);
    String? sized(int px) => art100?.replaceFirst('100x100bb', '${px}x${px}bb');
    final preview = _optStr(j['previewUrl']);
    return Track(
      id: 'itunes:${_str(j['trackId'])}',
      title: title,
      artist: Artist(id: '', name: artistName),
      art: art100 == null ? const ImageSet() : ImageSet(small: sized(150), medium: sized(480), large: sized(1000)),
      duration: previewSeconds,
      genre: _optStr(j['primaryGenreName']),
      album: albumName,
      releaseDate: _optStr(j['releaseDate']),
      provider: MusicProviders.itunes,
      streamUrl: preview,
      streamable: preview != null,
      previewOnly: true,
      externalUrl: _optStr(j['trackViewUrl']),
      language: language ?? detectLanguage([title, artistName, albumName])?.code,
    );
  }

  factory Track.fromApi(Map<String, dynamic> j) {
    final user =
        j['user'] is Map ? Artist.fromApi(Map<String, dynamic>.from(j['user'] as Map)) : const Artist(id: '', name: 'Unknown artist');
    var art = ImageSet.fromApi(j['artwork']);
    if (art.isEmpty) art = user.avatar;
    final title = _str(j['title'], 'Untitled');
    return Track(
      id: _str(j['id']),
      title: title,
      artist: user,
      art: art,
      duration: _int(j['duration']),
      plays: _int(j['play_count']),
      favorites: _int(j['favorite_count']),
      genre: _optStr(j['genre']),
      releaseDate: _optStr(j['release_date']) ?? _optStr(j['created_at']),
      streamable: j['is_streamable'] != false && j['is_delete'] != true,
      language: detectLanguage([title, _optStr(j['tags']), _optStr(j['description']), user.name])?.code,
    );
  }

  /// Maps a Jamendo v3 `/tracks` result. Ids are prefixed so they can't clash
  /// with Audius ids. Artist ids are left empty: there's no Jamendo artist page.
  factory Track.fromJamendo(Map<String, dynamic> j, {String? language}) {
    final image = _optStr(j['album_image']) ?? _optStr(j['image']);
    final audio = _optStr(j['audio']);
    return Track(
      id: 'jamendo:${_str(j['id'])}',
      title: _str(j['name'], 'Untitled'),
      artist: Artist(id: '', name: _str(j['artist_name'], 'Unknown artist')),
      art: image == null ? const ImageSet() : ImageSet(medium: image),
      duration: _int(j['duration']),
      album: _optStr(j['album_name']),
      releaseDate: _optStr(j['releasedate']),
      provider: MusicProviders.jamendo,
      streamUrl: audio,
      streamable: audio != null,
      language: language,
    );
  }

  factory Track.fromMap(Map<String, dynamic> j) => Track(
        id: _str(j['id']),
        title: _str(j['title']),
        artist: Artist.fromMap(Map<String, dynamic>.from(j['artist'] as Map)),
        art: ImageSet.fromMap(j['art']),
        duration: _int(j['duration']),
        plays: _int(j['plays']),
        favorites: _int(j['favorites']),
        genre: j['genre'] as String?,
        releaseDate: j['releaseDate'] as String?,
        streamable: j['streamable'] != false,
        // Tracks saved before multi-source support have no provider: Audius.
        provider: _optStr(j['provider']) ?? MusicProviders.audius,
        streamUrl: _optStr(j['streamUrl']),
        album: _optStr(j['album']),
        language: _optStr(j['language']),
        previewOnly: j['previewOnly'] == true,
        externalUrl: _optStr(j['externalUrl']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'previewOnly': previewOnly,
        'externalUrl': externalUrl,
        'artist': artist.toMap(),
        'art': art.toMap(),
        'duration': duration,
        'plays': plays,
        'favorites': favorites,
        'genre': genre,
        'releaseDate': releaseDate,
        'streamable': streamable,
        'provider': provider,
        'streamUrl': streamUrl,
        'album': album,
        'language': language,
      };
}

/// An Audius playlist. Albums are playlists with `is_album == true`.
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.owner,
    this.description,
    this.art = const ImageSet(),
    this.isAlbum = false,
    this.trackCount = 0,
    this.plays = 0,
    this.favorites = 0,
    this.releaseDate,
    this.language,
  });

  final String id, name;
  final Artist owner;
  final String? description, releaseDate;

  /// Detected ISO 639-1 code (see `detectLanguage`), or null.
  final String? language;
  final ImageSet art;
  final bool isAlbum;
  final int trackCount, plays, favorites;

  factory Collection.fromApi(Map<String, dynamic> j) {
    final owner =
        j['user'] is Map ? Artist.fromApi(Map<String, dynamic>.from(j['user'] as Map)) : const Artist(id: '', name: 'Unknown artist');
    var art = ImageSet.fromApi(j['artwork']);
    if (art.isEmpty) art = owner.avatar;
    final name = _str(j['playlist_name'], 'Untitled');
    final description = _optStr(j['description']);
    return Collection(
      id: _str(j['id']),
      name: name,
      owner: owner,
      description: description,
      language: detectLanguage([name, description])?.code,
      art: art,
      isAlbum: j['is_album'] == true,
      trackCount: _int(j['track_count']),
      plays: _int(j['total_play_count']),
      favorites: _int(j['favorite_count']),
      releaseDate: _optStr(j['release_date']) ?? _optStr(j['created_at']),
    );
  }

  factory Collection.fromMap(Map<String, dynamic> j) => Collection(
        id: _str(j['id']),
        name: _str(j['name']),
        owner: Artist.fromMap(Map<String, dynamic>.from(j['owner'] as Map)),
        description: j['description'] as String?,
        art: ImageSet.fromMap(j['art']),
        isAlbum: j['isAlbum'] == true,
        trackCount: _int(j['trackCount']),
        plays: _int(j['plays']),
        favorites: _int(j['favorites']),
        releaseDate: j['releaseDate'] as String?,
        language: _optStr(j['language']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'language': language,
        'owner': owner.toMap(),
        'description': description,
        'art': art.toMap(),
        'isAlbum': isAlbum,
        'trackCount': trackCount,
        'plays': plays,
        'favorites': favorites,
        'releaseDate': releaseDate,
      };
}

/// A playlist created locally by the user (stored in Hive).
class LocalPlaylist {
  const LocalPlaylist({required this.id, required this.name, this.tracks = const []});
  final String id, name;
  final List<Track> tracks;

  LocalPlaylist copyWith({String? name, List<Track>? tracks}) =>
      LocalPlaylist(id: id, name: name ?? this.name, tracks: tracks ?? this.tracks);

  int get totalSeconds => tracks.fold(0, (a, t) => a + t.duration);

  factory LocalPlaylist.fromMap(Map<String, dynamic> j) => LocalPlaylist(
        id: _str(j['id']),
        name: _str(j['name']),
        tracks: ((j['tracks'] as List?) ?? const []).whereType<Map>().map((e) => Track.fromMap(Map<String, dynamic>.from(e))).toList(),
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'tracks': tracks.map((t) => t.toMap()).toList()};
}
