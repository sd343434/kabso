import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the full-screen live hub (D50).
abstract final class KLiveFull {
  static const double inset = 16;
  static const double bottom = 24;
  static const double hostAvatar = 44;

  /// The cover fallback: the host's large avatar a little above centre.
  static const double fallbackAvatar = 128;

  /// When this many pages or fewer remain, the next page is requested.
  static const int prefetchPages = 2;
}

/// The live hub as one stream per screen (D50): a vertical pager; swipe up
/// for the next stream. Pages are full-bleed under the floating tabs header;
/// [topInset] keeps the badges and [overlay] (the category chips) below it.
///
/// When [KLiveFull.prefetchPages] or fewer pages remain, [onLoadMore] asks
/// for the next page (the source ignores calls it cannot serve). The last
/// page shows a progress line while more load, or a retry when loading more
/// failed.
class LiveHubPager extends StatefulWidget {
  const new({
    required this.rooms,
    required this.storageKey,
    super.key,
    this.topInset = 0,
    this.overlay,
    this.onRefresh,
    this.onOpenRoom,
    this.onLoadMore,
    this.onRetryLoadMore,
    this.loadingMore = false,
    this.loadMoreFailed,
  });

  final List<LiveRoomCardData> rooms;

  /// Keeps each tab's page (one pager per tab).
  final PageStorageKey<String> storageKey;
  final double topInset;
  final Widget? overlay;

  /// Pull down on the first stream to reload the tab (the pager takes the
  /// vertical drag, so it hosts its own refresh indicator).
  final Future<void> Function()? onRefresh;
  final ValueChanged<LiveRoomCardData>? onOpenRoom;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;
  final bool loadingMore;

  /// The inline "Couldn't load more" message; `null` when nothing failed.
  final String? loadMoreFailed;

  static const loadingMoreKey = Key('liveHub.loadingMore');
  static const loadMoreErrorKey = Key('liveHub.loadMoreError');

  @override
  State<LiveHubPager> createState() => _LiveHubPagerState();
}

class _LiveHubPagerState extends State<LiveHubPager> {
  Widget _refreshable(BuildContext context, Widget pager) {
    final refresh = widget.onRefresh;
    if (refresh == null) return pager;
    return RefreshIndicator(
      color: context.palette.primaryText,
      edgeOffset: widget.topInset,
      onRefresh: () async {
        try {
          await refresh();
        } on Object catch (e) {
          if (context.mounted) {
            KSnack.error(
              context,
              failureMessage(context.l10n, toAppFailure(e)),
            );
          }
        }
      },
      child: pager,
    );
  }

  // Keeps its page across rebuilds; with the [PageStorageKey] it is also
  // restored when the tab's subtree is rebuilt.
  final PageController _controller = PageController();

  int get _page => _controller.hasClients
      ? (_controller.page ?? _controller.initialPage.toDouble()).round()
      : _controller.initialPage;

  void _maybeLoadMore(int page) {
    // Never retry on its own after a failure: the user taps Retry.
    if (widget.loadMoreFailed != null || widget.loadingMore) return;
    if (widget.rooms.length - 1 - page <= KLiveFull.prefetchPages) {
      widget.onLoadMore?.call();
    }
  }

  /// After a build with new content (first page, a page appended, a load
  /// finished), check again whether the visible stream is near the end; a
  /// short page then fetches the next one by itself.
  void _checkAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _maybeLoadMore(_page);
  });

  @override
  void initState() {
    super.initState();
    _checkAfterFrame();
  }

  @override
  void didUpdateWidget(LiveHubPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rooms.length != widget.rooms.length ||
        oldWidget.loadingMore != widget.loadingMore) {
      _checkAfterFrame();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.rooms;
    final open = widget.onOpenRoom;
    final failed = widget.loadMoreFailed;
    return Stack(
      fit: StackFit.expand,
      children: [
        _refreshable(
          context,
          PageView.builder(
            key: widget.storageKey,
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: rooms.length,
            onPageChanged: _maybeLoadMore,
            itemBuilder: (_, i) {
              final last = i == rooms.length - 1;
              return KLiveFullPage(
                room: rooms[i],
                topInset: widget.topInset,
                onOpen: open == null ? null : () => open(rooms[i]),
                footer: !last
                    ? null
                    : failed != null
                    ? _LoadMoreError(
                        key: LiveHubPager.loadMoreErrorKey,
                        message: failed,
                        onRetry: widget.onRetryLoadMore,
                      )
                    : widget.loadingMore
                    ? Semantics(
                        key: LiveHubPager.loadingMoreKey,
                        label: context.l10n.liveHubLoadingMore,
                        child: LinearProgressIndicator(
                          minHeight: KMetrics.stroke,
                          color: context.palette.primary,
                          backgroundColor: const Color(0x00000000),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        if (widget.overlay case final overlay?)
          Positioned(top: widget.topInset, left: 0, right: 0, child: overlay),
      ],
    );
  }
}

/// One live stream filling the screen: the cover (or the host's large
/// avatar), the LIVE badge and viewer count at the top, the host, title
/// and category at the bottom start, and "Join live". The whole page opens
/// the room too. There is no media playback yet (B1), so the page never
/// claims a running video: it shows the cover frame.
class KLiveFullPage extends StatelessWidget {
  const new({
    required this.room,
    super.key,
    this.onOpen,
    this.topInset = 0,
    this.footer,
  });

  final LiveRoomCardData room;
  final VoidCallback? onOpen;
  final double topInset;

  /// Shown under the bottom block (load-more progress or retry).
  final Widget? footer;

  static const joinKey = Key('liveFull.join');
  static const badgesKey = Key('liveFull.badges');
  static const infoKey = Key('liveFull.info');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    const shadows = [
      Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2)),
    ];
    final isNew = room.viewerCount < 1;
    final guests = room.guestCount;
    final mode = room.inPk
        ? l10n.pkBadge
        : guests == null
        ? null
        : l10n.liveMultiGuest(guests);
    final base = l10n.liveCardSemantics(
      room.hostName,
      isNew
          ? l10n.liveCardNew
          : l10n.liveViewers(
              room.viewerCount,
              KFormat.grouped(room.viewerCount),
            ),
      room.title,
    );
    final withMode = mode == null
        ? base
        : l10n.liveCardSemanticsMode(base, mode);
    final category = room.categoryName;
    final hasCategory = category != null && category.isNotEmpty;
    final semantics = hasCategory
        ? l10n.liveCardSemanticsCategory(withMode, category)
        : withMode;
    final fallback = _Fallback(room: room);
    final cover = room.cover;
    final footer = this.footer;

    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          button: onOpen != null,
          label: semantics,
          container: true,
          excludeSemantics: true,
          onTap: onOpen,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: cover == null
                ? fallback
                : Image(
                    image: cover,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.22, 0.55, 1],
                colors: [
                  Color(0x80000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: topInset + KSpacing.sm,
          start: KLiveFull.inset,
          end: KLiveFull.inset,
          child: ExcludeSemantics(
            child: Row(
              key: badgesKey,
              children: [
                const KBadge.live(),
                const SizedBox(width: KSpacing.xs),
                if (isNew)
                  const KBadge.newRoom()
                else
                  KViewerCountChip(count: room.viewerCount),
                if (room.inPk) ...[
                  const SizedBox(width: KSpacing.xs),
                  const KBadge.pk(),
                ] else if (guests != null) ...[
                  const SizedBox(width: KSpacing.xs),
                  KBadge.multiGuest(count: guests),
                ],
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: KLiveFull.inset,
          end: KLiveFull.inset,
          bottom: KLiveFull.bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Row(
                  key: infoKey,
                  children: [
                    KAvatar(
                      name: room.hostName,
                      image: room.hostAvatar,
                      size: KLiveFull.hostAvatar,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            room.hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.title.copyWith(
                              color: white,
                              shadows: shadows,
                            ),
                          ),
                          Text(
                            room.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(
                              color: white,
                              shadows: shadows,
                            ),
                          ),
                          if (hasCategory)
                            Row(
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: KMetrics.iconXs,
                                  color: white,
                                ),
                                const SizedBox(width: KSpacing.xxs),
                                Flexible(
                                  child: Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: white,
                                      shadows: shadows,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(height: KSpacing.md),
                KButton(
                  key: joinKey,
                  label: l10n.liveHubJoin,
                  icon: Icons.sensors_rounded,
                  onPressed: onOpen,
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: KSpacing.sm),
                footer,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const new({required this.room});

  final LiveRoomCardData room;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KPalette.dark.surfaceRaised, KPalette.dark.background],
      ),
    ),
    child: Align(
      alignment: const AlignmentDirectional(0, -0.25),
      child: KAvatar(
        name: room.hostName,
        image: room.hostAvatar,
        size: KLiveFull.fallbackAvatar,
      ),
    ),
  );
}

class _LoadMoreError extends StatelessWidget {
  const new({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(color: white),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
      ],
    );
  }
}
