import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';

/// Arguments for the reusable "view all" list screen. Exactly one source is set.
class ListArgs {
  const ListArgs.tracks(this.title, PagedSource<Track> source)
      : tracks = source,
        collections = null,
        artists = null;
  const ListArgs.collections(this.title, PagedSource<Collection> source)
      : collections = source,
        tracks = null,
        artists = null;
  const ListArgs.artists(this.title, PagedSource<Artist> source)
      : artists = source,
        tracks = null,
        collections = null;

  final String title;
  final PagedSource<Track>? tracks;
  final PagedSource<Collection>? collections;
  final PagedSource<Artist>? artists;
}

const _tabs = ['home', 'explore', 'search', 'library'];

/// Detail screens are registered under every tab, so the mini-player and
/// bottom navigation stay visible while browsing.
extension DetailNav on BuildContext {
  void openDetail(String sub, {Object? extra}) {
    final segs = GoRouter.of(this).routeInformationProvider.value.uri.pathSegments;
    final base = segs.isNotEmpty && _tabs.contains(segs.first) ? segs.first : 'home';
    push('/$base/$sub', extra: extra);
  }

  void openArtist(String id) => openDetail('artist/$id');
  void openCollection(Collection c) => openDetail('collection/${c.id}', extra: c);
  void openGenre(Category c) => openDetail('genre/${c.key}');
  void openList(ListArgs args) => openDetail('list', extra: args);
  void openLanguage(MusicLanguage l) => openDetail('language/${l.code}');
  void openVideoList(VideoListArgs args) => openDetail('videos', extra: args);
  void openLocalPlaylist(String id) => openDetail('playlist/$id');
}
