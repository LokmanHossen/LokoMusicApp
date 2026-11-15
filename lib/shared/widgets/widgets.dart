import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/error/failure.dart';
import 'package:pulse_music/core/router/nav.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/core/utils/external_link.dart';
import 'package:pulse_music/core/utils/format.dart';
import 'package:pulse_music/core/utils/spotify_link.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/data/models/models.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/data_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';
import 'package:shimmer/shimmer.dart';

// ---- Artwork & skeletons -------------------------------------------------------

class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.image, this.width, this.radius = 12, this.circle = false, this.icon = Icons.music_note});
  final ImageSet? image;
  final double? width;
  final double radius;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final scheme = Theme.of(context).colorScheme;
    Widget content(double w) {
      final placeholder = Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(icon, color: scheme.onSurfaceVariant, size: w * 0.4),
      );
      final url = image?.forSize(w * dpr);
      if (url == null) return placeholder;
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: (w * dpr).round(),
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => Container(color: scheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => placeholder,
      );
    }

    final borderRadius = BorderRadius.circular(circle ? 1000 : radius);
    if (width != null) {
      return SizedBox(width: width, height: width, child: ClipRRect(borderRadius: borderRadius, child: content(width!)));
    }
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: LayoutBuilder(builder: (c, b) => content(b.maxWidth.isFinite ? b.maxWidth : 300)),
      ),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = 8, this.circle = false});
  final double? width, height, radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.08), base),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: circle ? null : BorderRadius.circular(radius ?? 8),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key, this.width = 140, this.circle = false});
  final double width;
  final bool circle;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
          ShimmerBox(width: width, height: width, radius: 12, circle: circle),
          const SizedBox(height: 10),
          ShimmerBox(width: width * 0.8, height: 12),
          const SizedBox(height: 6),
          ShimmerBox(width: width * 0.5, height: 10),
        ]),
      );
}

class TileSkeleton extends StatelessWidget {
  const TileSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          ShimmerBox(width: 52, height: 52, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShimmerBox(width: 180, height: 12),
              SizedBox(height: 8),
              ShimmerBox(width: 110, height: 10),
            ]),
          ),
        ]),
      );
}

// ---- States ----------------------------------------------------------------------

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.35), AppColors.accentWarm.withValues(alpha: 0.25)]),
            ),
            child: Icon(icon, size: 38, color: scheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

/// Footer / empty / error handling for a paged sliver list.
Widget pagedFooter<T>(PagedState<T> s, VoidCallback retry,
    {String emptyTitle = 'Nothing here yet', IconData emptyIcon = Icons.library_music_outlined}) {
  if (s.items.isEmpty && s.loading) {
    return SliverList.builder(itemCount: 8, itemBuilder: (_, __) => const TileSkeleton());
  }
  if (s.items.isEmpty && s.error != null) {
    return SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: s.error!, onRetry: retry));
  }
  if (s.items.isEmpty) {
    return SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: emptyIcon, title: emptyTitle));
  }
  if (s.loading) {
    return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))));
  }
  if (s.error != null) {
    return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(12), child: ErrorState(message: s.error!, onRetry: retry)));
  }
  return const SliverToBoxAdapter(child: SizedBox(height: 24));
}

class InfiniteScroll extends StatelessWidget {
  const InfiniteScroll({super.key, required this.child, required this.onEnd});
  final Widget child;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 500) onEnd();
          return false;
        },
        child: child,
      );
}

// ---- Sections --------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onViewAll});
  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 8, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          if (onViewAll != null) TextButton(onPressed: onViewAll, child: const Text('View all')),
        ]),
      );
}

class HList extends StatelessWidget {
  const HList({super.key, required this.height, required this.count, required this.builder});
  final double height;
  final int count;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: builder,
        ),
      );
}

/// Header + horizontal list driven by an [AsyncValue]; hides itself when empty.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.title,
    required this.value,
    required this.itemBuilder,
    required this.onRetry,
    this.height = 210,
    this.skeletonWidth = 140,
    this.skeletonCircle = false,
    this.onViewAll,
  });
  final String title;
  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext, List<T>, int) itemBuilder;
  final VoidCallback onRetry;
  final VoidCallback? onViewAll;
  final double height, skeletonWidth;
  final bool skeletonCircle;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title),
        HList(height: height, count: 5, builder: (_, __) => CardSkeleton(width: skeletonWidth, circle: skeletonCircle)),
      ]),
      error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title: title),
        SizedBox(height: 120, child: ErrorState(message: Failure.from(e).message, onRetry: onRetry)),
      ]),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: title, onViewAll: onViewAll),
          HList(height: height, count: items.length, builder: (c, i) => itemBuilder(c, items, i)),
        ]);
      },
    );
  }
}

// ---- Cards -----------------------------------------------------------------------

class TrackCard extends ConsumerWidget {
  const TrackCard({super.key, required this.track, required this.onTap, this.width = 140});
  final Track track;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      onLongPress: () => showTrackMenu(context, ref, track),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Artwork(image: track.art, width: width),
          const SizedBox(height: 8),
          Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            track.previewOnly ? '${track.artist.name} · Preview' : track.artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: muted),
          ),
        ]),
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.collection, this.width});
  final Collection collection;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final card = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Artwork(image: collection.art, width: width, icon: collection.isAlbum ? Icons.album : Icons.queue_music),
      const SizedBox(height: 8),
      Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      Text('${collection.isAlbum ? 'Album' : 'Playlist'} • ${collection.owner.name}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: muted)),
    ]);
    return InkWell(
      onTap: () => context.openCollection(collection),
      borderRadius: BorderRadius.circular(12),
      child: width == null ? card : SizedBox(width: width, child: card),
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist, this.width = 110});
  final Artist artist;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.openArtist(artist.id),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(children: [
          Artwork(image: artist.avatar, width: width, circle: true, icon: Icons.person),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
                child: Text(artist.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
            if (artist.verified)
              const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.verified, size: 14, color: AppColors.accent)),
          ]),
        ]),
      ),
    );
  }
}

class ArtistTile extends StatelessWidget {
  const ArtistTile({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () => context.openArtist(artist.id),
        leading: Artwork(image: artist.avatar, width: 52, circle: true, icon: Icons.person),
        title: Row(children: [
          Flexible(child: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (artist.verified)
            const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: AppColors.accent)),
        ]),
        subtitle: Text('${fmtCount(artist.followers)} followers • ${artist.trackCount} tracks'),
      );
}

// ---- Track tile & menus ------------------------------------------------------------

class FavoriteTrackButton extends ConsumerWidget {
  const FavoriteTrackButton({super.key, required this.track, this.size = 24});
  final Track track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider.select((f) => f.hasTrack(track.id)));
    return IconButton(
      tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
      iconSize: size,
      onPressed: () => ref.read(favoritesProvider.notifier).toggleTrack(track),
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? AppColors.accentWarm : null),
    );
  }
}

class TrackTile extends ConsumerWidget {
  const TrackTile({super.key, required this.track, required this.onTap, this.index, this.onRemove});
  final Track track;
  final VoidCallback onTap;
  final int? index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(currentTrackProvider.select((t) => t?.id == track.id));
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      track.artist.name,
      if (track.duration > 0) fmtDuration(track.duration),
      if (track.plays > 0) '${fmtCount(track.plays)} plays',
      if (track.previewOnly)
        'Preview · ${MusicProviders.label(track.provider)}'
      else if (track.provider == MusicProviders.jamendo)
        'Jamendo',
    ].join(' • ');
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: Stack(alignment: Alignment.center, children: [
        Artwork(image: track.art, width: 52, radius: 8),
        if (isCurrent)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.graphic_eq, color: AppColors.accent),
          ),
      ]),
      title: Text(track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? AppColors.accent : null)),
      subtitle: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        FavoriteTrackButton(track: track, size: 22),
        IconButton(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert),
          onPressed: () => showTrackMenu(context, ref, track, onRemove: onRemove),
        ),
      ]),
    );
  }
}

SliverList trackSliver(List<Track> tracks, void Function(int index) onTap, {bool numbered = false, void Function(Track)? onRemove}) {
  return SliverList.builder(
    itemCount: tracks.length,
    itemBuilder: (c, i) => TrackTile(
      track: tracks[i],
      index: numbered ? i + 1 : null,
      onTap: () => onTap(i),
      onRemove: onRemove == null ? null : () => onRemove(tracks[i]),
    ),
  );
}

Future<void> showTrackMenu(BuildContext context, WidgetRef ref, Track track,
    {VoidCallback? onRemove, void Function(String artistId)? onOpenArtist}) {
  final actions = ref.read(playbackActionsProvider);
  final favorites = ref.read(favoritesProvider.notifier);
  final isFav = ref.read(favoritesProvider).hasTrack(track.id);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      void close() => Navigator.pop(ctx);
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Artwork(image: track.art, width: 48, radius: 8),
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track.artist.name),
          ),
          const Divider(height: 1),
          ListTile(
              leading: const Icon(Icons.skip_next_outlined),
              title: const Text('Play next'),
              onTap: () {
                close();
                actions.playNext(track);
              }),
          ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () {
                close();
                actions.addToQueue(track);
              }),
          ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () {
                close();
                showAddToPlaylistSheet(context, ref, [track]);
              }),
          ListTile(
            leading: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            title: Text(isFav ? 'Remove from favorites' : 'Add to favorites'),
            onTap: () {
              close();
              favorites.toggleTrack(track);
            },
          ),
          if (track.artist.id.isNotEmpty)
            ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Go to artist'),
                onTap: () {
                  close();
                  (onOpenArtist ?? context.openArtist)(track.artist.id);
                }),
          if (track.previewOnly && track.externalUrl != null)
            ListTile(
              leading: const Icon(Icons.library_music_outlined),
              title: Text('Play full song on ${MusicProviders.label(track.provider)}'),
              subtitle: const Text('Only a 30-second preview plays here'),
              onTap: () {
                close();
                openFullSong(track);
              },
            ),
          ListTile(
            leading: const Icon(Icons.open_in_new, color: Color(0xFF1DB954)),
            title: const Text('Open in Spotify'),
            onTap: () {
              close();
              openInSpotify(track);
            },
          ),
          if (onRemove != null)
            ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from this list'),
                onTap: () {
                  close();
                  onRemove();
                }),
        ]),
      );
    },
  );
}

Future<void> showAddToPlaylistSheet(BuildContext context, WidgetRef ref, List<Track> tracks) {
  final notifier = ref.read(localPlaylistsProvider.notifier);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final lists = ref.watch(localPlaylistsProvider);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await askText(context, title: 'New playlist', action: 'Create');
                if (name != null && name.isNotEmpty) {
                  notifier.create(name, tracks);
                  toast('Created "$name"');
                }
              },
            ),
            for (final p in lists)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                subtitle: Text('${p.tracks.length} tracks'),
                onTap: () {
                  Navigator.pop(ctx);
                  final added = notifier.addTracks(p.id, tracks);
                  toast(added == 0 ? 'Already in "${p.name}"' : 'Added to "${p.name}"');
                },
              ),
          ]),
        ),
      );
    }),
  );
}

class PlayShuffleRow extends StatelessWidget {
  const PlayShuffleRow({super.key, required this.onPlay, required this.onShuffle, this.extras = const []});
  final VoidCallback onPlay, onShuffle;
  final List<Widget> extras;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          FilledButton.icon(onPressed: onPlay, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play all')),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(onPressed: onShuffle, icon: const Icon(Icons.shuffle), label: const Text('Shuffle')),
          const Spacer(),
          ...extras,
        ]),
      );
}

class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.maxLines = 3});
  final String text;
  final int maxLines;
  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(widget.text,
              maxLines: _open ? null : widget.maxLines,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}
