import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/features/languages/presentation/language_screen.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/features/artists/presentation/artist_screen.dart';
import 'package:pulse_music/features/home/presentation/home_screen.dart';
import 'package:pulse_music/features/home/presentation/shell_scaffold.dart';
import 'package:pulse_music/features/library/presentation/library_screen.dart';
import 'package:pulse_music/features/music_categories/presentation/explore_screen.dart';
import 'package:pulse_music/features/music_categories/presentation/genre_screen.dart';
import 'package:pulse_music/features/player/presentation/player_screen.dart';
import 'package:pulse_music/features/playlists/presentation/collection_screen.dart';
import 'package:pulse_music/features/playlists/presentation/local_playlist_screen.dart';
import 'package:pulse_music/features/queue/presentation/queue_screen.dart';
import 'package:pulse_music/features/search/presentation/search_screen.dart';
import 'package:pulse_music/features/settings/presentation/settings_screen.dart';
import 'package:pulse_music/features/tracks/presentation/list_screen.dart';
import 'package:pulse_music/features/videos/presentation/video_list_screen.dart';
import 'package:pulse_music/features/videos/presentation/video_player_screen.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';
import 'package:pulse_music/shared/widgets/app_backdrop.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Detail screens are mounted under every tab so the mini-player and bottom
/// bar stay visible while browsing.
List<RouteBase> _detailRoutes() => [
      GoRoute(path: 'artist/:id', builder: (c, s) => ArtistScreen(id: s.pathParameters['id']!)),
      GoRoute(
        path: 'collection/:id',
        builder: (c, s) => CollectionScreen(id: s.pathParameters['id']!, initial: s.extra is Collection ? s.extra as Collection : null),
      ),
      GoRoute(path: 'genre/:key', builder: (c, s) => GenreScreen(category: Categories.byKey(s.pathParameters['key']!))),
      GoRoute(
        path: 'language/:code',
        builder: (c, s) => LanguageScreen(language: MusicLanguage.fromCode(s.pathParameters['code']) ?? MusicLanguage.english),
      ),
      GoRoute(path: 'list', builder: (c, s) => ListScreen(args: s.extra as ListArgs)),
      GoRoute(path: 'videos', builder: (c, s) => VideoListScreen(args: s.extra as VideoListArgs)),
      GoRoute(path: 'playlist/:id', builder: (c, s) => LocalPlaylistScreen(id: s.pathParameters['id']!)),
      GoRoute(path: 'settings', builder: (c, s) => const SettingsScreen()),
    ];

CustomTransitionPage<void> _slideUp(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      // Custom transitions skip the theme's page builders, so add the shared
      // background (color + guitar watermark) here.
      child: AppBackdrop(child: child),
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen(), routes: _detailRoutes())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (c, s) => const ExploreScreen(), routes: _detailRoutes())]),
          StatefulShellBranch(routes: [GoRoute(path: '/search', builder: (c, s) => const SearchScreen(), routes: _detailRoutes())]),
          StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (c, s) => const LibraryScreen(), routes: _detailRoutes())]),
        ],
      ),
      GoRoute(path: '/player', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _slideUp(s, const PlayerScreen())),
      GoRoute(path: '/queue', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _slideUp(s, const QueueScreen())),
      // Full-screen YouTube player, above the tabs and mini player.
      GoRoute(
        path: '/video',
        parentNavigatorKey: _rootKey,
        builder: (c, s) {
          final a = s.extra as VideoPlayArgs;
          return VideoPlayerScreen(video: a.video, list: a.list);
        },
      ),
    ],
  );
});
