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
/// (items, empty or error).
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
  });

  final AsyncValue<FeedLoad<T>> content;
  final FeedRegionCopy copy;
  final Widget Function(List<T> items) itemsSliver;
  final Widget loadingSliver;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget? header;

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
        (content.hasError && !content.isLoading);

    final scroll = CustomScrollView(
      physics: refreshable ? const AlwaysScrollableScrollPhysics() : null,
      slivers: [
        if (header case final header?) SliverFloatingHeader(child: header),
        body,
        const SliverToBoxAdapter(child: SizedBox(height: KSpacing.lg)),
      ],
    );
    if (!refreshable) return scroll;
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
      child: scroll,
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
