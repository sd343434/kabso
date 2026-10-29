import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shared parts of the pages the Me hub opens (D164): the wallet, the
/// earnings and the creator center.

/// A page under the hub: centred title on the page background, pull to
/// refresh, a padded list.
class MePage extends StatelessWidget {
  const new({
    required this.title,
    required this.onRefresh,
    required this.children,
    super.key,
  });

  final String title;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(title),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xl,
          ),
          children: children,
        ),
      ),
    );
  }
}

/// A section heading in a [MePage], with an optional hint under it.
class MeSectionTitle extends StatelessWidget {
  const new(this.title, {super.key, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.lg, bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: t.bodyStrong.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: KSpacing.xxs),
            Text(hint, style: t.caption.copyWith(color: p.textTertiary)),
          ],
        ],
      ),
    );
  }
}

/// A money action that is not available yet (recharge, withdraw): a
/// disabled button with the "Soon" tag and the honest reason under it.
class MeSoonAction extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.reason,
    super.key,
  });

  final String label;
  final IconData icon;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: l10n.meHubSoonItem(label),
      hint: reason,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Opacity(
                opacity: KMeHub.soonOpacity,
                child: KButton(label: label, icon: icon, onPressed: null),
              ),
              const PositionedDirectional(
                top: KSpacing.xs,
                end: KSpacing.xs,
                child: MeHubSoonTag(),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: context.textStyles.caption.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// A grid of labelled numbers, [columns] per row, equal heights per row
/// (a large text size grows the row, never clips).
class MeStatGrid extends StatelessWidget {
  const new({required this.stats, super.key, this.columns = 3});

  /// `(key, label, value)`.
  final List<(Key, String, String)> stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <List<(Key, String, String)>>[
      for (var i = 0; i < stats.length; i += columns)
        stats.sublist(i, (i + columns).clamp(0, stats.length)),
    ];
    return Column(
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: KSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: c < row.length
                        ? _StatTile(stat: row[c])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const new({required this.stat});

  final (Key, String, String) stat;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final (key, label, value) = stat;
    return Semantics(
      key: key,
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.xs,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(KRadius.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: t.bodyStrong.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The footer of a paged list: loads the next page when it scrolls into
/// view, or offers a retry after a failure.
class MeLoadMore extends StatelessWidget {
  const new({
    required this.failed,
    required this.onLoad,
    required this.itemCount,
    super.key,
  });

  final bool failed;
  final Future<void> Function() onLoad;
  final int itemCount;

  @override
  Widget build(BuildContext context) => failed
      ? Center(
          child: TextButton(
            onPressed: () => unawaited(onLoad()),
            child: Text(context.l10n.actionRetry),
          ),
        )
      : PostGridLoadMore(
          key: ValueKey(itemCount),
          onVisible: () => unawaited(onLoad()),
        );
}
