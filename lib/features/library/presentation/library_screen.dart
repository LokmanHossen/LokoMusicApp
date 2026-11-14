import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:pulse_music/shared/widgets/widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your library', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.openDetail('settings'))],
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Tracks'),
            Tab(text: 'Albums'),
            Tab(text: 'Playlists'),
            Tab(text: 'Artists'),
            Tab(text: 'Recent'),
            Tab(text: 'My playlists'),
          ]),
        ),
        body: const TabBarView(children: [
          _TracksTab(),
          _CollectionsTab(albums: true),
          _CollectionsTab(albums: false),
          _ArtistsTab(),
          _RecentTab(),
          _MyPlaylistsTab(),
        ]),
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.tracks, required this.empty, this.header, this.onRemove});
  final List<Track> tracks;
  final Widget empty;
  final Widget? header;
  final void Function(Track)? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) return empty;
    final actions = ref.read(playbackActionsProvider);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: PlayShuffleRow(
          onPlay: () => actions.playTracks(tracks),
          onShuffle: () => actions.shuffle(tracks),
          extras: [if (header != null) header!],
        ),
      ),
      trackSliver(tracks, (i) => actions.playTracks(tracks, index: i), onRemove: onRemove),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

class _TracksTab extends ConsumerWidget {
  const _TracksTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _TrackList(
        tracks: ref.watch(favoritesProvider).tracks,
        empty: const EmptyState(icon: Icons.favorite_border, title: 'No favorite tracks yet', message: 'Tap the heart on any track to keep it here.'),
      );
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.albums});
  final bool albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(favoritesProvider);
    final items = albums ? f.albums : f.playlists;
    if (items.isEmpty) {
      return EmptyState(
        icon: albums ? Icons.album_outlined : Icons.queue_music,
        title: albums ? 'No favorite albums yet' : 'No favorite playlists yet',
        message: 'Open one and tap the heart to save it.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: 0.78),
      itemCount: items.length,
      itemBuilder: (c, i) => CollectionCard(collection: items[i]),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(favoritesProvider).artists;
    if (artists.isEmpty) {
      return const EmptyState(icon: Icons.person_outline, title: 'No followed artists', message: 'Follow artists from their profile page.');
    }
    return ListView.builder(itemCount: artists.length, itemBuilder: (c, i) => ArtistTile(artist: artists[i]));
  }
}

class _RecentTab extends ConsumerWidget {
  const _RecentTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _TrackList(
        tracks: ref.watch(recentProvider),
        header: TextButton(onPressed: ref.read(recentProvider.notifier).clear, child: const Text('Clear')),
        empty: const EmptyState(icon: Icons.history, title: 'Nothing played yet', message: 'Tracks you play will show up here.'),
      );
}

class _MyPlaylistsTab extends ConsumerWidget {
  const _MyPlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(localPlaylistsProvider);
    Future<void> create() async {
      final name = await askText(context, title: 'New playlist', action: 'Create');
      if (name != null && name.isNotEmpty) ref.read(localPlaylistsProvider.notifier).create(name);
    }

    if (lists.isEmpty) {
      return EmptyState(
        icon: Icons.playlist_add,
        title: 'Create your first playlist',
        message: 'Playlists are stored on this device.',
        action: FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('New playlist')),
      );
    }
    return ListView(children: [
      ListTile(leading: const CircleAvatar(child: Icon(Icons.add)), title: const Text('New playlist'), onTap: create),
      for (final p in lists)
        ListTile(
          onTap: () => context.openLocalPlaylist(p.id),
          leading: Artwork(image: p.tracks.isEmpty ? null : p.tracks.first.art, width: 52, radius: 8, icon: Icons.queue_music),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${p.tracks.length} tracks'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete "${p.name}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) ref.read(localPlaylistsProvider.notifier).delete(p.id);
            },
          ),
        ),
    ]);
  }
}
