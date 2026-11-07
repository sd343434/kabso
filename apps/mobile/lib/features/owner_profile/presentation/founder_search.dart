import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.9; owner: «في البحث تظهر صفحة مؤسس البرنامج
/// دائماً»): the founder always in search — from `GET /search/featured`
/// (never a hard-coded account; nothing when there is none or a block).
/// [compact]: the pinned row above the results while typing; otherwise the
/// card before anything is typed (photo, name and seal, «مؤسس Kabso Live»,
/// Follow).
class FounderSearchEntry extends ConsumerStatefulWidget {
  const new({super.key, this.compact = false});

  final bool compact;

  static const cardKey = Key('search.founder.card');
  static const rowKey = Key('search.founder.row');
  static const followKey = Key('search.founder.follow');

  @override
  ConsumerState<FounderSearchEntry> createState() => _FounderSearchEntryState();
}

class _FounderSearchEntryState extends ConsumerState<FounderSearchEntry> {
  bool? _following;
  bool _busy = false;

  Future<void> _toggle(FeaturedFounder f) async {
    if (_busy) return;
    final follow = !(_following ?? f.isFollowing);
    setState(() {
      _busy = true;
      _following = follow;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      await (follow
          ? repo.follow(f.user.username)
          : repo.unfollow(f.user.username));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _following = !follow);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(searchFeaturedProvider).value;
    if (f == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final u = f.user;
    final name = u.displayName.isEmpty ? u.username : u.displayName;
    final following = _following ?? f.isFollowing;
    void open() =>
        unawaited(context.push<void>(AppRoutes.userProfile(u.username)));
    final nameLine = NameWithSeal(
      badge: u.verification,
      fontSize: widget.compact ? 15 : 17,
      name: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.bodyStrong.copyWith(
          fontSize: widget.compact ? 15 : 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final role = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          size: 14,
          color: KBrandColors.gold,
        ),
        const SizedBox(width: KSpacing.xxs),
        Flexible(
          child: Text(
            l10n.ownerSearchRole,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
    final followButton = f.isSelf
        ? null
        : SizedBox(
            height: 34,
            child: following
                ? OutlinedButton(
                    key: FounderSearchEntry.followKey,
                    onPressed: _busy ? null : () => unawaited(_toggle(f)),
                    child: Text(l10n.ownerSearchFollowing),
                  )
                : FilledButton(
                    key: FounderSearchEntry.followKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: KBrandColors.red500,
                      foregroundColor: const Color(0xFFFFFFFF),
                    ),
                    onPressed: _busy ? null : () => unawaited(_toggle(f)),
                    child: Text(l10n.ownerSearchFollow),
                  ),
          );
    if (widget.compact) {
      return Material(
        color: KBrandColors.gold.withValues(alpha: 0.08),
        child: ListTile(
          key: FounderSearchEntry.rowKey,
          dense: true,
          onTap: open,
          leading: KAvatar(name: name, imageUrl: u.avatarUrl, size: 40),
          title: Align(
            alignment: AlignmentDirectional.centerStart,
            child: nameLine,
          ),
          subtitle: role,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.push_pin_rounded, size: 16, color: p.textTertiary),
              if (followButton != null) ...[
                const SizedBox(width: KSpacing.sm),
                followButton,
              ],
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: FounderSearchEntry.cardKey,
          borderRadius: BorderRadius.circular(KRadius.lg),
          onTap: open,
          child: Ink(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.lg),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  KBrandColors.red500.withValues(alpha: 0.10),
                  KBrandColors.gold.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: KBrandColors.gold.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [KBrandColors.red400, KBrandColors.gold],
                    ),
                  ),
                  child: KAvatar(name: name, imageUrl: u.avatarUrl, size: 56),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      nameLine,
                      const SizedBox(height: KSpacing.xxs),
                      role,
                      Text(
                        KHandle.isolated(u.username, staffId: u.staffId),
                        maxLines: 1,
                        style: t.caption.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                ),
                ?followButton,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
