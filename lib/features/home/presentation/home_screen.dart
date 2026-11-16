import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pulse_music/core/constants/categories.dart';
import 'package:pulse_music/core/constants/languages.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/data/models/youtube_video.dart';
import 'package:pulse_music/features/videos/presentation/video_widgets.dart';
import 'package:pulse_music/shared/providers/youtube_providers.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(audiusClientProvider).clearCache();
    for (final p in [
      trendingProvider,
      popularProvider,
      newReleasesProvider,
      recommendedProvider,
      popularAlbumsProvider,
      popularPlaylistsProvider,
      madeForYouProvider
    ]) {
      ref.invalidate(p);
    }
    ref.invalidate(featuredArtistsProvider);
    await ref.read(trendingProvider.future).then((_) {}, onError: (_) {});
  }

  Widget _trackSection(BuildContext context, WidgetRef ref, String title,
      FutureProvider<List<Track>> provider, PagedSource<Track> viewAll) {
    final actions = ref.read(playbackActionsProvider);
    return AsyncSection<Track>(
      title: title,
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      onViewAll: () => context.openList(ListArgs.tracks(title, viewAll)),
      itemBuilder: (c, items, i) => TrackCard(
          track: items[i], onTap: () => actions.playTracks(items, index: i)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(playbackActionsProvider);
    final src = ref.read(sourcesProvider);
    final recent = ref.watch(recentProvider);
    final scheme = Theme.of(context).colorScheme;
    final genre = ref.watch(topGenreProvider);
    final youtubeEnabled = ref.read(youtubeProvider).enabled;

    // The guitar background comes from AppBackdrop, shared by every screen.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child:
              ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              // Row 1: guitar + "Loko Music" + settings. Row 2: the greeting at
              // full width, so the big guitar never squeezes it.
              child: Column(children: [
                SizedBox(
                  height: 60,
                  child: Stack(children: [
                    // Room for the guitar on the left and settings on the right.
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 60),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: _BrandTitle()),
                    ),
                    // Decorative brand image.
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Image(
                            image: AssetImage('assets/branding/guitar.png'),
                            width: 56,
                            height: 56,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 0,
                      child: IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => context.openDetail('settings')),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                  child: Text(
                    '${greeting()} · What are you in the mood for?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: () => context.go('/search'),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.search, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Songs, artists, albums, playlists',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
            const SectionHeader(title: 'Browse by language', topPadding: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: LanguageTabBrowser(showArtists: youtubeEnabled),
            ),
            if (recent.isNotEmpty) ...[
              SectionHeader(
                  title: 'Recently played',
                  onViewAll: () => context.go('/library')),
              HList(
                height: 210,
                count: recent.length.clamp(0, 12),
                builder: (c, i) => TrackCard(
                    track: recent[i],
                    onTap: () => actions.playTracks(recent, index: i)),
              ),
            ],
            // Trending YouTube music videos in Bangladesh (separate row; plays
            // only in the embedded video player).
            if (ref.read(youtubeProvider).enabled)
              AsyncSection<YouTubeVideo>(
                title: 'Trending music videos · YouTube',
                value: ref.watch(youtubePopularProvider),
                height: 222,
                skeletonWidth: 160,
                onRetry: () => ref.invalidate(youtubePopularProvider),
                onViewAll: () => context.openVideoList(
                    const VideoListArgs.popular('Trending music videos')),
                itemBuilder: (c, items, i) =>
                    VideoCard(video: items[i], list: items),
              ),
            // New Bangla and Hindi songs from YouTube (single songs, not
            // compilations). Also plays in the embedded YouTube player.
            if (ref.read(youtubeProvider).enabled)
              AsyncSection<YouTubeVideo>(
                title: 'New songs · YouTube',
                value: ref.watch(youtubeHomeSongsProvider),
                height: 222,
                skeletonWidth: 160,
                onRetry: () => ref.invalidate(youtubeHomeSongsProvider),
                onViewAll: () => context.openVideoList(const VideoListArgs(
                    'New songs', youtubeHomeSongQuery,
                    songs: true)),
                itemBuilder: (c, items, i) =>
                    VideoCard(video: items[i], list: items),
              ),
            _trackSection(context, ref, 'Trending music', trendingProvider,
                src.trending()),
            _trackSection(context, ref, 'Popular tracks', popularProvider,
                src.trending(time: 'allTime')),
            _trackSection(context, ref, 'New releases', newReleasesProvider,
                src.newReleases()),
            AsyncSection<Artist>(
              title: 'Featured artists',
              value: ref.watch(featuredArtistsProvider),
              height: 150,
              skeletonWidth: 110,
              skeletonCircle: true,
              onRetry: () => ref.invalidate(featuredArtistsProvider),
              itemBuilder: (c, items, i) => ArtistCard(artist: items[i]),
            ),
            AsyncSection<Collection>(
              title: 'Popular albums',
              value: ref.watch(popularAlbumsProvider),
              onRetry: () => ref.invalidate(popularAlbumsProvider),
              onViewAll: () => context.openList(
                  ListArgs.collections('Popular albums', src.popularAlbums())),
              itemBuilder: (c, items, i) =>
                  CollectionCard(collection: items[i], width: 140),
            ),
            _trackSection(context, ref, 'Recommended', recommendedProvider,
                src.recommended()),
            AsyncSection<Collection>(
              title: 'Popular playlists',
              value: ref.watch(popularPlaylistsProvider),
              onRetry: () => ref.invalidate(popularPlaylistsProvider),
              onViewAll: () => context.openList(ListArgs.collections(
                  'Popular playlists', src.popularPlaylists())),
              itemBuilder: (c, items, i) =>
                  CollectionCard(collection: items[i], width: 140),
            ),
            SectionHeader(
                title: 'Browse by category',
                onViewAll: () => context.go('/explore')),
            HList(
              height: 92,
              count: Categories.all.length,
              builder: (c, i) => CategoryCard(
                  category: Categories.all[i], width: 150, height: 92),
            ),
            AsyncSection<Track>(
              title: 'Made for you',
              value: ref.watch(madeForYouProvider),
              onRetry: () => ref.invalidate(madeForYouProvider),
              onViewAll: () => context.openList(ListArgs.tracks(
                  'Made for you', src.trending(time: 'month', genre: genre))),
              itemBuilder: (c, items, i) => TrackCard(
                  track: items[i],
                  onTap: () => actions.playTracks(items, index: i)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Loko Music" in a brush-script font, in the brand crimson with a soft glow.
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  /// Crimson picked from the reference "Musicvic" artwork.
  static const crimson = Color(0xFFD9364E);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'Loko Music',
      maxLines: 1,
      semanticsLabel: 'Loko Music',
      style: GoogleFonts.pacifico(
        fontSize: 32,
        height: 1.25,
        color: crimson,
        shadows: [
          Shadow(
              color: crimson.withValues(alpha: dark ? 0.45 : 0.25),
              blurRadius: 14)
        ],
      ),
    );
  }
}

class MusicArtist {
  const MusicArtist(this.name, this.origin);

  final String name;
  final String origin;
}

/// Curated bands and singers shown for the selected language.
const topMusicArtists = <MusicLanguage, List<MusicArtist>>{
  MusicLanguage.bangla: [
    MusicArtist('Warfaze', 'Bangladesh'),
    MusicArtist('Artcell', 'Bangladesh'),
    MusicArtist('LRB', 'Bangladesh'),
    MusicArtist('Nogor Baul', 'Bangladesh'),
    MusicArtist('Miles', 'Bangladesh'),
    MusicArtist('Souls', 'Bangladesh'),
    MusicArtist('Aurthohin', 'Bangladesh'),
    MusicArtist('Nemesis', 'Bangladesh'),
    MusicArtist('Chirkutt', 'Bangladesh'),
    MusicArtist('Shironamhin', 'Bangladesh'),
    MusicArtist('Meghdol', 'Bangladesh'),
    MusicArtist('Arbovirus', 'Bangladesh'),
    MusicArtist('Black', 'Bangladesh'),
    MusicArtist('Cryptic Fate', 'Bangladesh'),
    MusicArtist('Ashes', 'Bangladesh'),
    MusicArtist('Level Five', 'Bangladesh'),
    MusicArtist('Fossils', 'West Bengal'),
    MusicArtist('Moheener Ghoraguli', 'West Bengal'),
    MusicArtist('Chandrabindoo', 'West Bengal'),
    MusicArtist('Bhoomi', 'West Bengal'),
    MusicArtist('Cactuss', 'West Bengal'),
    MusicArtist('Lakkhichhara', 'West Bengal'),
    MusicArtist('Parash Pathar', 'West Bengal'),
    MusicArtist('Dohar', 'West Bengal'),
    MusicArtist('Fakira', 'West Bengal'),
    MusicArtist('Prithibi', 'West Bengal'),
  ],
  MusicLanguage.hindi: [
    MusicArtist('Arijit Singh', 'India'),
    MusicArtist('Shreya Ghoshal', 'India'),
    MusicArtist('A. R. Rahman', 'India'),
    MusicArtist('Lata Mangeshkar', 'India'),
    MusicArtist('Kishore Kumar', 'India'),
    MusicArtist('Sonu Nigam', 'India'),
    MusicArtist('Kumar Sanu', 'India'),
    MusicArtist('Sunidhi Chauhan', 'India'),
    MusicArtist('Mohit Chauhan', 'India'),
    MusicArtist('Atif Aslam', 'Pakistan'),
    MusicArtist('Neha Kakkar', 'India'),
    MusicArtist('Rahat Fateh Ali Khan', 'Pakistan'),
    MusicArtist('Jubin Nautiyal', 'India'),
    MusicArtist('KK', 'India'),
    MusicArtist('Udit Narayan', 'India'),
    MusicArtist('Indian Ocean', 'India'),
    MusicArtist('The Local Train', 'India'),
    MusicArtist('Euphoria', 'India'),
    MusicArtist('Agnee', 'India'),
    MusicArtist('Parikrama', 'India'),
    MusicArtist('Shankar Mahadevan', 'India'),
    MusicArtist('Badshah', 'India'),
    MusicArtist('Diljit Dosanjh', 'India'),
    MusicArtist('Pritam', 'India'),
  ],
  MusicLanguage.english: [
    MusicArtist('Taylor Swift', 'United States'),
    MusicArtist('The Weeknd', 'Canada'),
    MusicArtist('Ed Sheeran', 'United Kingdom'),
    MusicArtist('Adele', 'United Kingdom'),
    MusicArtist('Billie Eilish', 'United States'),
    MusicArtist('Bruno Mars', 'United States'),
    MusicArtist('Dua Lipa', 'United Kingdom'),
    MusicArtist('Beyonce', 'United States'),
    MusicArtist('Coldplay', 'United Kingdom'),
    MusicArtist('Queen', 'United Kingdom'),
    MusicArtist('The Beatles', 'United Kingdom'),
    MusicArtist('Imagine Dragons', 'United States'),
    MusicArtist('Maroon 5', 'United States'),
    MusicArtist('Linkin Park', 'United States'),
    MusicArtist('Eminem', 'United States'),
    MusicArtist('Rihanna', 'Barbados'),
    MusicArtist('Justin Bieber', 'Canada'),
    MusicArtist('Lady Gaga', 'United States'),
    MusicArtist('Michael Jackson', 'United States'),
    MusicArtist('Elton John', 'United Kingdom'),
    MusicArtist('OneRepublic', 'United States'),
    MusicArtist('The Rolling Stones', 'United Kingdom'),
    MusicArtist('Harry Styles', 'United Kingdom'),
    MusicArtist('Sia', 'Australia'),
    MusicArtist('Oasis', 'United Kingdom'),
  ],
};

String _musicArtistSectionTitle(MusicLanguage language) => switch (language) {
      MusicLanguage.bangla => 'Top Bangla Music Bands',
      MusicLanguage.hindi => 'Top Hindi Music Bands & Singers',
      MusicLanguage.english => 'Top English Music Bands & Singers',
    };

String _languageContentTypes(MusicLanguage language) => switch (language) {
      MusicLanguage.bangla => 'Music · Movies · Natok',
      MusicLanguage.hindi => 'Music · Movies · Serials',
      MusicLanguage.english => 'Music · Movies · TV Shows',
    };

/// Three rows of artist-style cards in a horizontally scrolling grid.
class MusicArtistGrid extends StatefulWidget {
  const MusicArtistGrid(
      {super.key, required this.language, required this.artists});

  final MusicLanguage language;
  final List<MusicArtist> artists;

  @override
  State<MusicArtistGrid> createState() => _MusicArtistGridState();
}

class _MusicArtistGridState extends State<MusicArtistGrid> {
  final _scrollController = ScrollController();
  int _dotCount = 1;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateIndicator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _updateIndicator();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateIndicator);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateIndicator() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.viewportDimension <= 0) return;

    final dotCount = position.maxScrollExtent <= 0
        ? 1
        : (position.maxScrollExtent / position.viewportDimension).ceil() + 1;
    final activeDot = position.maxScrollExtent <= 0
        ? 0
        : (position.pixels / position.maxScrollExtent * (dotCount - 1))
            .round()
            .clamp(0, dotCount - 1);
    if (dotCount != _dotCount || activeDot != _activeDot) {
      setState(() {
        _dotCount = dotCount;
        _activeDot = activeDot;
      });
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        child: Column(children: [
          SizedBox(
            height: 370,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _updateIndicator();
                return false;
              },
              child: GridView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 86,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 6,
                ),
                itemCount: widget.artists.length,
                itemBuilder: (context, index) => MusicArtistCard(
                    artist: widget.artists[index],
                    language: widget.language,
                    index: index),
              ),
            ),
          ),
          if (_dotCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_dotCount, (index) {
                  final active = index == _activeDot;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 25 : 12,
                    height: 10,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
            ),
        ]),
      );
}

class MusicArtistCard extends StatelessWidget {
  const MusicArtistCard(
      {super.key,
      required this.artist,
      required this.language,
      required this.index});

  final MusicArtist artist;
  final MusicLanguage language;
  final int index;

  static const _gradients = [
    [Color(0xFFEE5A6F), Color(0xFF8B3D9A)],
    [Color(0xFF3F8EFC), Color(0xFF5142B8)],
    [Color(0xFFEF9A2C), Color(0xFFD44955)],
    [Color(0xFF0FAE93), Color(0xFF2E6AB3)],
    [Color(0xFF9A5EE9), Color(0xFFCE477A)],
  ];

  String get _monogram {
    final words = artist.name.split(' ');
    return words.length == 1
        ? words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase()
        : '${words.first[0]}${words.last[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final fallback = Center(
      child: Text(_monogram,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5)),
    );
    return InkWell(
      onTap: () => context.openVideoList(
        VideoListArgs(
            '${artist.name} · YouTube', '${artist.name} official music',
            language: language),
      ),
      borderRadius: BorderRadius.circular(44),
      child: SizedBox(
        width: 86,
        child: Column(children: [
          Stack(children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: colors.last.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ],
              ),
              child: fallback,
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4)
                    ]),
                child: Icon(Icons.play_arrow_rounded,
                    size: 17, color: colors.last),
              ),
            ),
          ]),
          const SizedBox(height: 7),
          Text(artist.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(artist.origin,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// A language browser with curated artist discovery for the active tab.
class LanguageTabBrowser extends StatelessWidget {
  const LanguageTabBrowser({super.key, this.showArtists = true});

  final bool showArtists;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: MusicLanguage.values.length,
      child: Builder(builder: (context) {
        final tabController = DefaultTabController.of(context);
        return AnimatedBuilder(
          animation: tabController,
          builder: (context, _) {
            final language = MusicLanguage.values[tabController.index];
            return Column(children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  indicator: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Bangla'),
                    Tab(text: 'Hindi'),
                    Tab(text: 'English'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 74,
                child: TabBarView(
                  children: [
                    for (final language in MusicLanguage.values)
                      _LanguageTabPanel(language: language),
                  ],
                ),
              ),
              if (showArtists) ...[
                SectionHeader(title: _musicArtistSectionTitle(language)),
                MusicArtistGrid(
                    key: ValueKey(language),
                    language: language,
                    artists: topMusicArtists[language]!),
              ],
            ]);
          },
        );
      }),
    );
  }
}

class _LanguageTabPanel extends StatelessWidget {
  const _LanguageTabPanel({required this.language});
  final MusicLanguage language;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: language.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => context.openLanguage(language),
            child: Stack(children: [
              Positioned(
                right: 24,
                bottom: -16,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded,
                        color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${language.label} sounds',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 1),
                        Text(_languageContentTypes(language),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class LanguageCard extends StatelessWidget {
  const LanguageCard(
      {super.key, required this.language, this.width, this.height});
  final MusicLanguage language;
  final double? width, height;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.openLanguage(language),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: language.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(
              right: 10,
              bottom: 4,
              child: Text(language.nativeLabel,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.3))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(language.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
            ),
          ]),
        ),
      );
}

class CategoryCard extends StatelessWidget {
  const CategoryCard(
      {super.key, required this.category, this.width, this.height});
  final Category category;
  final double? width, height;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.openGenre(category),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: category.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(
                right: -10,
                bottom: -10,
                child: Icon(category.icon,
                    size: 72, color: Colors.white.withValues(alpha: 0.25))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(category.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
            ),
          ]),
        ),
      );
}
