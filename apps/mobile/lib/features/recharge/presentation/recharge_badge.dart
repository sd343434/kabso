import 'dart:async';

import 'package:clock/clock.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The daily recharge badges «شارات الشحن اليومي» (v1.56-social, D187,
/// CONVENTIONS §10.50): the owner's five pieces of art in
/// `assets/recharge_badges/` (PROVENANCE.md), one per tier.
abstract final class RechargeBadgeArt {
  /// The art of [tier] (1–5; anything else is clamped).
  static String asset(int tier) =>
      'assets/recharge_badges/tier_${tier.clamp(1, 5)}.webp';
}

/// The daily recharge badge next to a name, like the level badge: in live
/// rooms (chat, the join line, viewers, seats, the host pill, the person
/// card), on the profile and the Me hub card. It draws nothing once
/// [badge]'s `until` has passed — and removes itself at that moment
/// without a refresh. Square art; [height] is its side. Announced as
/// «شارة الشحن اليومي، المستوى N».
class RechargeTierBadge extends StatefulWidget {
  const new({required this.badge, super.key, this.height = 18, this.gap = 0});

  final RechargeBadge? badge;
  final double height;

  /// Space before the badge (start side) when it shows.
  final double gap;

  static const badgeKey = Key('recharge.tierBadge');

  @override
  State<RechargeTierBadge> createState() => _RechargeTierBadgeState();
}

class _RechargeTierBadgeState extends State<RechargeTierBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(RechargeTierBadge old) {
    super.didUpdateWidget(old);
    if (old.badge != widget.badge) _schedule();
  }

  /// One timer to the badge's end: a rebuild then hides it.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final badge = widget.badge;
    if (badge == null) return;
    final left = badge.until.difference(clock.now());
    if (left <= Duration.zero) return;
    _timer = Timer(left, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    if (badge == null || !badge.isActiveAt(clock.now())) {
      return const SizedBox.shrink();
    }
    final h = widget.height;
    final art = Semantics(
      label: context.l10n.rechargeBadgeLabel(badge.tier),
      excludeSemantics: true,
      child: Image.asset(
        RechargeBadgeArt.asset(badge.tier),
        key: RechargeTierBadge.badgeKey,
        height: h,
        width: h,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
    if (widget.gap <= 0) return art;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: widget.gap),
      child: art,
    );
  }
}

/// Whether [badge] shows now (for rows that add spacing only when it does).
bool rechargeBadgeShows(RechargeBadge? badge) =>
    badge != null && badge.isActiveAt(clock.now());
