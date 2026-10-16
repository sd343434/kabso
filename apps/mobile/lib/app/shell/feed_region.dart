import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Copy and icons for one tab's non-content states (HL-H6). Every tab has
/// its own unavailable copy.
@immutable
class FeedRegionCopy {
  const new({
    required this.unavailableIcon,
    required this.unavailableTitle,
    required this.unavailableBody,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.errorTitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.loadMoreFailed,
    this.endOfList,
  });

  final IconData unavailableIcon;
  final String unavailableTitle;
  final String unavailableBody;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final String errorTitle;

  /// Optional real action on the empty state (e.g. "See popular").
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Paginated lists (HL-H5): the inline footer error text ("Couldn't load
  /// more") and the end-of-list caption. `null` for unpaginated content.
  final String? loadMoreFailed;
  final String? endOfList;
}

/// The content region under a `FeedTabsScaffold` header: an optional
/// floating [header] (e.g. the category chips, which scroll away and come
/// back on a reverse scroll) above the tab's content or its state:
///
/// | content | shows |
/// | ------- | ----- |
/// | loading | [loadingSliver], revealed after 300 ms (no flash) |
/// | [FeedUnavailable] | compact unavailable state; no pull-to-refresh |
/// | empty [FeedItems] | compact empty state (+ optional action) |
/// | error | compact error state with Try again + Error ID |
/// | [FeedItems] | [itemsSliver] |
///
/// Pull-to-refresh calls [onRefresh] only where a data source exists
/// (items, empty or error; also unavailable with [refreshWhenUnavailable],
/// when the unavailable state comes from a server switch that can change).
///
/// Paginated [FeedItems] (HL-H5): [onLoadMore] is called whenever 2 viewport
/// heights or less remain below the visible area (the source ignores calls
/// it cannot serve), and the footer shows [footerLoadingSliver] while the
/// next page loads, an inline error with Retry ([onRetryLoadMore]) when it
/// failed, or the end-of-list caption once there is nothing more.
class FeedRegion<T> extends StatelessWidget {
  const new({
    required this.content,
    required this.copy,
    required this.itemsSliver,
    required this.loadingSliver,
    required this.onRefresh,
    required this.onRetry,
    super.key,
    this.header,
    this.onLoadMore,
    this.onRetryLoadMore,
    this.footerLoadingSliver,
    this.refreshWhenUnavailable = false,
  });

  static const loadMoreErrorKey = Key('feed.loadMoreError');
  static const endOfListKey = Key('feed.endOfList');

  final AsyncValue<FeedLoad<T>> content;
  final FeedRegionCopy copy;
  final Widget Function(List<T> items) itemsSliver;
  final Widget loadingSliver;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget? header;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;
  final Widget? footerLoadingSliver;
  final bool refreshWhenUnavailable;

  /// HL-H5: prefetch when ≤ 2 viewport heights remain.
  static const prefetchViewports = 2.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = switch (content) {
      AsyncValue(value: FeedItems<T>(:final items)) when items.isNotEmpty =>
        itemsSliver(items),
      AsyncValue(value: FeedItems<T>()) => _box(
        KEmptyState(
          compact: true,
          icon: copy.emptyIcon,
          title: copy.emptyTitle,
          message: copy.emptyBody,
          actionLabel: copy.emptyActionLabel,
          onAction: copy.onEmptyAction,
        ),
      ),
      AsyncValue(value: FeedUnavailable<T>()) => _box(
        KEmptyState(
          key: const Key('feed.unavailable'),
          compact: true,
          icon: copy.unavailableIcon,
          title: copy.unavailableTitle,
          message: copy.unavailableBody,
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => _box(
        FailureErrorState(
          compact: true,
          title: copy.errorTitle,
          failure: toAppFailure(error),
          onRetry: onRetry,
        ),
      ),
      _ => _DelayedSliver(child: loadingSliver),
    };
    final refreshable =
        content.value is FeedItems<T> ||
        (refreshWhenUnavailable && content.value is FeedUnavailable<T>) ||
        (content.hasError && !content.isLoading);
    final footer = switch (content) {
      AsyncValue(value: FeedItems<T>(:final items, :final loadingMore))
          when items.isNotEmpty && loadingMore =>
        footerLoadingSliver,
      AsyncValue(value: FeedItems<T>(:final items, :final loadMoreError?))
          when items.isNotEmpty =>
        _box(
          _LoadMoreError(
            message:
                copy.loadMoreFailed ??
                failureMessage(l10n, toAppFailure(loadMoreError)),
            onRetry: onRetryLoadMore,
          ),
        ),
      AsyncValue(value: FeedItems<T>(:final items, hasMore: false))
          when items.isNotEmpty && copy.endOfList != null =>
        _box(_EndOfList(caption: copy.endOfList!)),
      _ => null,
    };

    final scroll = CustomScrollView(
      physics: refreshable ? const AlwaysScrollableScrollPhysics() : null,
      slivers: [
        if (header case final header?) SliverFloatingHeader(child: header),
        body,
        ?footer,
        const SliverToBoxAdapter(child: SizedBox(height: KSpacing.lg)),
      ],
    );
    final region = switch (onLoadMore) {
      null => scroll,
      final load => _Prefetch(
        content: content,
        onLoadMore: load,
        child: scroll,
      ),
    };
    if (!refreshable) return region;
    return RefreshIndicator(
      color: context.palette.primaryText,
      onRefresh: () async {
        try {
          await onRefresh();
        } on Object catch (e) {
          if (context.mounted) {
            KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
          }
        }
      },
      child: region,
    );
  }

  static Widget _box(Widget child) => SliverToBoxAdapter(child: child);
}

/// Shows [child] (a sliver) only after `KMetrics.loadingRevealDelay`, so
/// fast loads don't flash skeletons.
class _DelayedSliver extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_DelayedSliver> createState() => _DelayedSliverState();
}

class _DelayedSliverState extends State<_DelayedSliver> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(KMetrics.loadingRevealDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SliverToBoxAdapter();
}

/// Calls [onLoadMore] when the list's own (vertical, depth 0) scroll
/// metrics show ≤ `FeedRegion.prefetchViewports` viewport heights below the
/// visible area — on scroll and when the content size changes (a short first
/// page prefetches by itself).
///
/// Fires at most once per [content]: until the new content is laid out the
/// metrics are stale and would request the same page again.
class _Prefetch extends StatefulWidget {
  const new({
    required this.content,
    required this.onLoadMore,
    required this.child,
  });

  final Object content;
  final VoidCallback onLoadMore;
  final Widget child;

  @override
  State<_Prefetch> createState() => _PrefetchState();
}

class _PrefetchState extends State<_Prefetch> {
  bool _armed = true;

  @override
  void didUpdateWidget(_Prefetch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _armed = true;
  }

  bool _onNotification(Notification notification) {
    if (!_armed) return false;
    final metrics = switch (notification) {
      ScrollNotification(:final metrics, depth: 0) => metrics,
      ScrollMetricsNotification(:final metrics, depth: 0) => metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.vertical) return false;
    final threshold = FeedRegion.prefetchViewports * metrics.viewportDimension;
    if (metrics.extentAfter <= threshold) {
      _armed = false;
      // Not during layout: the source updates its state synchronously.
      scheduleMicrotask(widget.onLoadMore);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: _onNotification,
    child: widget.child,
  );
}

/// HL-H5 footer error: "Couldn't load more · Retry"; the list stays usable.
class _LoadMoreError extends StatelessWidget {
  const new({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      key: FeedRegion.loadMoreErrorKey,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.lg,
        vertical: KSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              message,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: p.primaryText,
              minimumSize: const Size(
                KSizes.minTouchTarget,
                KSizes.minTouchTarget,
              ),
            ),
            child: Text(context.l10n.actionRetry),
          ),
        ],
      ),
    );
  }
}

/// HL-H5 end of a live list: there is no "all caught up", only a hint that
/// pulling down shows new rooms.
class _EndOfList extends StatelessWidget {
  const new({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
    key: FeedRegion.endOfListKey,
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: KSpacing.lg,
      vertical: KSpacing.md,
    ),
    child: Text(
      caption,
      textAlign: TextAlign.center,
      style: context.textStyles.caption.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}
