import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/family_widgets.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families/:familyId` (CP-018; redesigned for CP-022, D116, after the
/// owner's style board): the hero (cover, back, share, ⋯, level and the
/// family number), the emblem over its edge with the name, tagline and
/// members, the level progress, the tools (manage and join requests for the
/// leader and deputies; competitions, shop and tasks shown as "Soon"), and
/// the tabs Members (by points, with presence) · Events ("Soon") ·
/// Contributions (this month) · Ranking (the family on both boards). The
/// bottom bar: Message the family and Invite members for members; Ask to
/// join / Cancel for others.
class FamilyScreen extends ConsumerWidget {
  const new({required this.familyId, super.key});

  final String familyId;

  static const joinKey = Key('family.join');
  static const cancelKey = Key('family.cancelRequest');
  static const leaveKey = Key('family.leave');
  static const manageKey = Key('family.manage');
  static const disbandKey = Key('family.disband');
  static const changeEmblemKey = Key('family.changeEmblem');
  static const removeEmblemKey = Key('family.removeEmblem');
  static const changeCoverKey = Key('family.changeCover');
  static const removeCoverKey = Key('family.removeCover');
  static const taglineKey = Key('family.tagline');
  static const notFoundKey = Key('family.notFound');
  static const requestsKey = Key('family.requests');
  static const requestsToolKey = Key('family.tool.requests');
  static const manageToolKey = Key('family.tool.manage');
  static const chatKey = Key('family.chat');
  static const inviteKey = Key('family.invite');
  static const shareKey = Key('family.share');
  static const numberKey = Key('family.number');
  static const membersCountKey = Key('family.membersCount');
  static const memberSearchKey = Key('family.memberSearch');
  static const standingKey = Key('family.standing');

  static Key memberKey(String username) => Key('family.member.$username');
  static Key memberMenuKey(String username) =>
      Key('family.member.$username.menu');
  static Key contributionKey(String username) =>
      Key('family.contribution.$username');
  static Key acceptKey(String requestId) => Key('family.request.$requestId.ok');
  static Key declineKey(String requestId) =>
      Key('family.request.$requestId.no');
  static Key tabKey(int index) => Key('family.tab.$index');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(familyProvider(familyId));
    final family = load.value;
    return Scaffold(
      backgroundColor: p.background,
      appBar: family == null
          ? AppBar(
              backgroundColor: p.background,
              centerTitle: true,
              title: Text(l10n.familyPageTitle),
            )
          : null,
      body: switch (load) {
        AsyncValue(:final value?) => _FamilyBody(family: value),
        AsyncValue(:final error?, isLoading: false)
            when isErrorCode(error, ErrorCode.notFound) =>
          Center(
            key: notFoundKey,
            child: KEmptyState(
              icon: Icons.groups_2_outlined,
              title: l10n.familyNotFoundTitle,
              message: l10n.familyNotFoundBody,
            ),
          ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.familyLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(familyProvider(familyId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: family == null ? null : _BottomBar(family: family),
    );
  }
}

/// Copies the invite (name and number) — there is no public link yet (B7),
/// as the live's share does.
Future<void> _copyInvite(BuildContext context, Family family) async {
  final l10n = context.l10n;
  await Clipboard.setData(
    ClipboardData(text: l10n.familyInviteText(family.name, '${family.number}')),
  );
  if (context.mounted) KSnack.success(context, l10n.familyInviteCopied);
}

Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    }
  }
}

enum _Menu {
  changeEmblem,
  removeEmblem,
  changeCover,
  removeCover,
  tagline,
  disband,
  copyNumber,
  leave,
}

/// The hero's ⋯: the leader's tools (emblem, cover, tagline, disband),
/// Leave for members, and copy the number.
class _FamilyMenu extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  Future<(Uint8List, String)?> _pick(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (!context.mounted || picked.isEmpty) return null;
    final bytes = picked.first;
    final type = sniffImageType(bytes);
    if (type == null) {
      KSnack.error(context, l10n.createPhotoUnsupported);
      return null;
    }
    if (bytes.length > maxPhotoBytes) {
      KSnack.error(context, l10n.createPhotoTooLarge);
      return null;
    }
    return (bytes, type);
  }

  Future<void> _changeEmblem(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final photo = await _pick(context, ref);
    if (photo == null || !context.mounted) return;
    await _guard(context, () async {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadFamilyEmblem(photo.$1, photo.$2);
      await ref.read(familiesRepositoryProvider).setEmblem(family.id, asset.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyEmblemUpdated);
    });
  }

  Future<void> _changeCover(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final photo = await _pick(context, ref);
    if (photo == null || !context.mounted) return;
    await _guard(context, () async {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadFamilyCover(photo.$1, photo.$2);
      await ref
          .read(familiesRepositoryProvider)
          .updateLook(family.id, coverMediaId: asset.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyCoverUpdated);
    });
  }

  Future<void> _editTagline(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TaglineDialog(initial: family.tagline ?? ''),
    );
    if (text == null || !context.mounted) return;
    await _guard(context, () async {
      await ref
          .read(familiesRepositoryProvider)
          .updateLook(family.id, tagline: text.trim());
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familySaved);
    });
  }

  Future<void> _disband(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.familyDisbandTitle(family.name),
      body: l10n.familyDisbandBody,
      confirm: l10n.familyDisband,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _guard(context, () async {
      await ref.read(familiesRepositoryProvider).disband(family.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyDisbanded);
      if (context.canPop()) context.pop();
    });
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.familyLeaveTitle(family.name),
      body: l10n.familyLeaveBody,
      confirm: l10n.familyLeave,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _guard(context, () async {
      await ref.read(familiesRepositoryProvider).leave(family.id);
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyLeft);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final leader = family.myRole == FamilyRole.leader;
    final member = family.myRole != null;
    final alone = family.memberCount <= 1;
    return PopupMenuButton<_Menu>(
      key: FamilyScreen.manageKey,
      tooltip: l10n.familyManage,
      icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFFFFFFFF)),
      onSelected: (action) => unawaited(switch (action) {
        _Menu.changeEmblem => _changeEmblem(context, ref),
        _Menu.removeEmblem => _guard(context, () async {
          await ref.read(familiesRepositoryProvider).setEmblem(family.id, null);
          if (!context.mounted) return;
          refreshFamilies(ref, familyId: family.id);
          KSnack.success(context, l10n.familyEmblemRemoved);
        }),
        _Menu.changeCover => _changeCover(context, ref),
        _Menu.removeCover => _guard(context, () async {
          await ref
              .read(familiesRepositoryProvider)
              .updateLook(family.id, removeCover: true);
          if (!context.mounted) return;
          refreshFamilies(ref, familyId: family.id);
          KSnack.success(context, l10n.familyCoverRemoved);
        }),
        _Menu.tagline => _editTagline(context, ref),
        _Menu.disband => _disband(context, ref),
        _Menu.copyNumber => _copyNumber(context, family),
        _Menu.leave => _leave(context, ref),
      }),
      itemBuilder: (_) => [
        if (leader) ...[
          PopupMenuItem(
            key: FamilyScreen.changeEmblemKey,
            value: _Menu.changeEmblem,
            child: Text(l10n.familyChangeEmblem),
          ),
          if (family.emblemUrl != null)
            PopupMenuItem(
              key: FamilyScreen.removeEmblemKey,
              value: _Menu.removeEmblem,
              child: Text(l10n.familyRemoveEmblem),
            ),
          PopupMenuItem(
            key: FamilyScreen.changeCoverKey,
            value: _Menu.changeCover,
            child: Text(l10n.familyChangeCover),
          ),
          if (family.coverUrl != null)
            PopupMenuItem(
              key: FamilyScreen.removeCoverKey,
              value: _Menu.removeCover,
              child: Text(l10n.familyRemoveCover),
            ),
          PopupMenuItem(
            value: _Menu.tagline,
            child: Text(l10n.familyTaglineTitle),
          ),
        ],
        PopupMenuItem(
          value: _Menu.copyNumber,
          child: Text(l10n.familyCopyNumber),
        ),
        if (member && !leader)
          PopupMenuItem(
            key: FamilyScreen.leaveKey,
            value: _Menu.leave,
            child: Text(
              l10n.familyLeave,
              style: TextStyle(color: context.palette.error),
            ),
          ),
        if (leader)
          PopupMenuItem(
            key: FamilyScreen.disbandKey,
            value: _Menu.disband,
            enabled: alone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.familyDisband),
                if (!alone)
                  Text(
                    l10n.familyDisbandOnlyAlone,
                    style: context.textStyles.caption,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _copyNumber(BuildContext context, Family family) async {
  await Clipboard.setData(ClipboardData(text: '${family.number}'));
  if (context.mounted) KSnack.info(context, context.l10n.profileCopied);
}

class _FamilyBody extends ConsumerStatefulWidget {
  const new({required this.family});

  final Family family;

  @override
  ConsumerState<_FamilyBody> createState() => _FamilyBodyState();
}

class _FamilyBodyState extends ConsumerState<_FamilyBody> {
  int _tab = 0;
  String _query = '';
  Timer? _debounce;
  final _search = TextEditingController();

  Family get family => widget.family;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersKey = familyMembersKey(family.id, _query);
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _Hero(family: family)),
      SliverToBoxAdapter(
        child: _Identity(
          family: family,
          onMembers: () => setState(() => _tab = 0),
        ),
      ),
      SliverToBoxAdapter(child: _LevelRow(family: family)),
      SliverToBoxAdapter(child: _Tools(family: family)),
      SliverPersistentHeader(
        pinned: true,
        delegate: _TabsHeader(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
          labels: [
            context.l10n.familyTabMembers,
            context.l10n.familyTabEvents,
            context.l10n.familyTabContributions,
            context.l10n.familyTabRanking,
          ],
          background: context.palette.background,
          border: context.palette.border,
          scale: MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
      ...switch (_tab) {
        2 => _contributionSlivers(context),
        3 => [SliverToBoxAdapter(child: _Standing(family: family))],
        _ => _memberSlivers(context, membersKey),
      },
      const SliverToBoxAdapter(child: SizedBox(height: KSpacing.xl)),
    ];
    return RefreshIndicator(
      onRefresh: () async {
        refreshFamilies(ref, familyId: family.id);
        await ref.read(familyProvider(family.id).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  List<Widget> _memberSlivers(BuildContext context, String key) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final members = ref.watch(familyMembersProvider(key));
    final notifier = ref.read(familyMembersProvider(key).notifier);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        KSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                key: FamilyScreen.memberSearchKey,
                controller: _search,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                style: t.body.copyWith(color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.familyMembersSearchHint,
                  hintStyle: t.body.copyWith(color: p.textTertiary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: p.textSecondary,
                    size: 20,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: p.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              l10n.familyMembersShort(familyCount(context, family.memberCount)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
    return [
      SliverToBoxAdapter(child: header),
      ...switch (members) {
        AsyncValue(:final value?) when value.items.isEmpty => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Text(
                l10n.familyMembersNoMatch,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.textSecondary),
              ),
            ),
          ),
        ],
        AsyncValue(:final value?) => [
          SliverList.builder(
            itemCount: value.items.length + (value.hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < value.items.length) {
                return _MemberTile(family: family, member: value.items[i]);
              }
              return value.loadMoreError == null
                  ? PostGridLoadMore(
                      key: ValueKey(value.items.length),
                      onVisible: () => unawaited(notifier.loadMore()),
                    )
                  : Center(
                      child: TextButton(
                        onPressed: () => unawaited(notifier.loadMore()),
                        child: Text(l10n.actionRetry),
                      ),
                    );
            },
          ),
        ],
        AsyncValue(:final error?, isLoading: false) => [
          SliverToBoxAdapter(
            child: FailureErrorState(
              title: l10n.familyLoadError,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(familyMembersProvider(key)),
              compact: true,
            ),
          ),
        ],
        _ => [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      },
    ];
  }

  List<Widget> _contributionSlivers(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(familyContributionsProvider(family.id));
    final notifier = ref.read(familyContributionsProvider(family.id).notifier);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.md,
            KSpacing.lg,
            KSpacing.xs,
          ),
          child: Text(
            l10n.familyContributionsThisMonth,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ),
      ),
      ...switch (load) {
        AsyncValue(:final value?) when value.items.isEmpty => [
          SliverToBoxAdapter(
            child: KEmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: l10n.familyContributionsEmpty,
              message: l10n.familyContributionsEmptyBody,
              compact: true,
            ),
          ),
        ],
        AsyncValue(:final value?) => [
          SliverList.builder(
            itemCount: value.items.length + (value.hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < value.items.length) {
                final c = value.items[i];
                return _PersonRow(
                  key: FamilyScreen.contributionKey(c.user.username),
                  rank: c.rank,
                  user: c.user,
                  role: c.role,
                  line: l10n.familyPoints(formatBondPoints(c.points)),
                );
              }
              return value.loadMoreError == null
                  ? PostGridLoadMore(
                      key: ValueKey(value.items.length),
                      onVisible: () => unawaited(notifier.loadMore()),
                    )
                  : Center(
                      child: TextButton(
                        onPressed: () => unawaited(notifier.loadMore()),
                        child: Text(l10n.actionRetry),
                      ),
                    );
            },
          ),
        ],
        AsyncValue(:final error?, isLoading: false) => [
          SliverToBoxAdapter(
            child: FailureErrorState(
              title: l10n.familyLoadError,
              failure: toAppFailure(error),
              onRetry: () =>
                  ref.invalidate(familyContributionsProvider(family.id)),
              compact: true,
            ),
          ),
        ],
        _ => [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      },
    ];
  }
}

/// The hero: the cover (or the slot for the owner's art, or a gradient
/// with the emblem in its winged frame), the top bar, the level chip and
/// the family number.
class _Hero extends StatelessWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final top = MediaQuery.paddingOf(context).top;
    final cover = family.coverUrl;
    final art = FamilyArt.heroBackground;
    final height = top + 196;
    final Widget background;
    if (cover != null) {
      background = Image.network(
        cover,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const DecoratedBox(
          decoration: BoxDecoration(gradient: FamilyColors.heroGradient),
        ),
      );
    } else if (art != null) {
      background = Image.asset(art, fit: BoxFit.cover);
    } else {
      background = DecoratedBox(
        decoration: const BoxDecoration(gradient: FamilyColors.heroGradient),
        child: Align(
          alignment: const Alignment(0, 0.35),
          child: SizedBox(
            width: 150,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: FamilyEmblem(url: family.emblemUrl, size: 74),
                ),
                Image.asset(
                  FamilyArt.podiumFrame(1),
                  width: 150,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ],
            ),
          ),
        ),
      );
    }
    Widget round(Widget child) => Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x40000000),
      ),
      child: child,
    );
    // Over a picture: text scaling is capped like other overlays.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.overlayMaxTextScale,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0x00000000),
                    Color(0x33000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              top: top + KSpacing.xs,
              left: KSpacing.sm,
              right: KSpacing.sm,
              child: Row(
                children: [
                  round(
                    BackButton(
                      color: white,
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.familyPageTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: t.title.copyWith(
                          color: white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  round(
                    IconButton(
                      key: FamilyScreen.shareKey,
                      tooltip: l10n.familyShare,
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.share_rounded,
                        color: white,
                        size: 20,
                      ),
                      onPressed: () => unawaited(_copyInvite(context, family)),
                    ),
                  ),
                  const SizedBox(width: KSpacing.xs),
                  round(_FamilyMenu(family: family)),
                ],
              ),
            ),
            PositionedDirectional(
              top: top + 64,
              start: KSpacing.lg,
              end: KSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: FamilyLevelCrownChip(level: family.level)),
                  const SizedBox(width: KSpacing.sm),
                  Semantics(
                    button: true,
                    label: l10n.familyNumberCopy('${family.number}'),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: FamilyScreen.numberKey,
                      onTap: () => unawaited(_copyNumber(context, family)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.md,
                          vertical: KSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x59000000),
                          border: Border.all(color: const Color(0x66FFFFFF)),
                          borderRadius: BorderRadius.circular(KRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.familyNumberLabel,
                              style: t.caption.copyWith(color: white),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${family.number}',
                                  textDirection: TextDirection.ltr,
                                  style: t.bodyStrong.copyWith(color: white),
                                ),
                                const SizedBox(width: KSpacing.xs),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: white,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The panel's rounded lip over the hero's bottom edge.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KRadius.xl),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The emblem over the hero's edge, the name (and edit for the leader), the
/// tagline and the members.
class _Identity extends ConsumerWidget {
  const new({required this.family, required this.onMembers});

  final Family family;
  final VoidCallback onMembers;

  static const double _emblem = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final tagline = family.tagline;
    final members = Semantics(
      button: true,
      child: InkWell(
        key: FamilyScreen.membersCountKey,
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: onMembers,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded, size: 20, color: p.textPrimary),
                  const SizedBox(width: KSpacing.xs),
                  Flexible(
                    child: Text(
                      familyCount(context, family.memberCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.familyMemberWord,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 16,
                    color: p.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFFF26FA8),
                    Color(0xFFF8CB6A),
                    Color(0xFFE4A23C),
                    Color(0xFFF26FA8),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.background,
                ),
                child: FamilyEmblem(url: family.emblemUrl, size: _emblem),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text(
                              family.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.title.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        if (family.myRole == FamilyRole.leader)
                          IconButton(
                            tooltip: l10n.familyTaglineTitle,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: p.textSecondary,
                            ),
                            onPressed: () => unawaited(
                              _FamilyMenu(family: family)
                                  ._editTagline(context, ref),
                            ),
                          ),
                      ],
                    ),
                    if (tagline != null)
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 124),
              child: members,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Level N", the progress bar and "points / next · to reach level N+1".
class _LevelRow extends StatelessWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final next = family.nextLevelPoints;
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: Text(
                l10n.familyLevelLong(family.level),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KRadius.pill),
                child: LinearProgressIndicator(
                  value: next == null || next <= 0
                      ? 1
                      : (family.points / next).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: p.surfaceRaised,
                  color: FamilyColors.gold,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Flexible(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    next == null
                        ? formatBondPoints(family.points)
                        : '${formatBondPoints(family.points)} / '
                              '${formatBondPoints(next)}',
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    next == null
                        ? l10n.familyTopLevel
                        : l10n.familyToReach(family.level + 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The five tools: manage (leader), join requests (leader and deputies,
/// with the count), and competitions, shop and tasks — not built, "Soon".
class _Tools extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = family.myRole;
    final tiles = <Widget>[
      if (role == FamilyRole.leader)
        _ToolTile(
          key: FamilyScreen.manageToolKey,
          icon: Icons.settings_rounded,
          art: FamilyArt.toolIcons[0],
          color: FamilyColors.goldDeep,
          label: l10n.familyToolManage,
          onTap: () => unawaited(_showManageSheet(context, family)),
        ),
      if (role != null && role.answersRequests)
        _ToolTile(
          key: FamilyScreen.requestsToolKey,
          icon: Icons.group_add_rounded,
          art: FamilyArt.toolIcons[1],
          color: FamilyColors.goldDeep,
          label: l10n.familyRequestsTitle,
          badge: family.pendingRequestCount,
          onTap: () => unawaited(_showRequests(context, family)),
        ),
      _ToolTile(
        icon: Icons.emoji_events_rounded,
        art: FamilyArt.toolIcons[2],
        color: FamilyColors.goldDeep,
        label: l10n.familyToolCompetitions,
      ),
      _ToolTile(
        icon: Icons.shopping_bag_rounded,
        art: FamilyArt.toolIcons[3],
        color: FamilyColors.goldDeep,
        label: l10n.familyToolShop,
      ),
      _ToolTile(
        icon: Icons.task_alt_rounded,
        art: FamilyArt.toolIcons[4],
        color: FamilyColors.goldDeep,
        label: l10n.familyToolTasks,
      ),
    ];
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, tile) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: KSpacing.sm),
              Expanded(child: tile),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.color,
    required this.label,
    super.key,
    this.art,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String? art;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final soon = onTap == null;
    final art = this.art;
    final badge = this.badge;
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.xxs,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: soon ? 0.45 : 1,
                child: art == null
                    ? Icon(icon, size: 28, color: color)
                    : Image.asset(art, width: 30, height: 30),
              ),
              if (badge != null && badge > 0)
                PositionedDirectional(
                  top: -6,
                  end: -12,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: p.error,
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      border: Border.all(color: p.surface, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: t.caption.copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(
              color: soon ? p.textTertiary : p.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (soon) ...[const SizedBox(height: 2), const FamilySoonBadge()],
        ],
      ),
    );
    if (soon) {
      return Semantics(
        label: context.l10n.familiesSoonLabel(label),
        excludeSemantics: true,
        child: tile,
      );
    }
    return Semantics(
      button: true,
      label: badge != null && badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

/// The pinned tabs: Members · Events ("Soon") · Contributions · Ranking.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const new({
    required this.selected,
    required this.onSelect,
    required this.labels,
    required this.background,
    required this.border,
    required this.scale,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final List<String> labels;
  final Color background;
  final Color border;
  final double scale;

  double get _height => 48 * scale.clamp(1, 1.6);

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: i == 1
                  ? Semantics(
                      label: context.l10n.familiesSoonLabel(label),
                      excludeSemantics: true,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.body.copyWith(color: p.textTertiary),
                            ),
                            const FamilySoonBadge(),
                          ],
                        ),
                      ),
                    )
                  : Semantics(
                      button: true,
                      selected: i == selected,
                      child: InkWell(
                        key: FamilyScreen.tabKey(i),
                        onTap: () => onSelect(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.label.copyWith(
                                color: i == selected
                                    ? p.textPrimary
                                    : p.textSecondary,
                                fontWeight: i == selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: i == selected
                                    ? FamilyColors.goldGradient
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  KRadius.pill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader old) =>
      old.selected != selected ||
      old.labels != labels ||
      old.background != background ||
      old.scale != scale;
}

/// A person in a list: place medal, avatar, name with role, [line] and
/// optional presence and menu.
class _PersonRow extends StatelessWidget {
  const new({
    required this.rank,
    required this.user,
    required this.role,
    required this.line,
    super.key,
    this.presence,
    this.trailing,
  });

  final int? rank;
  final UserSummary user;
  final FamilyRole role;
  final String line;
  final Widget? presence;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    final rank = this.rank;
    return InkWell(
      onTap: () => context.push(AppRoutes.userProfile(user.username)),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.xs,
          KSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            if (rank != null) ...[
              FamilyRankMedal(rank: rank, size: 28),
              const SizedBox(width: KSpacing.sm),
            ],
            KAvatar(name: name, imageUrl: user.avatarUrl, size: 44),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Flexible(child: FamilyRoleChip(role: role)),
                    ],
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            if (presence case final presence?) ...[
              const SizedBox(width: KSpacing.xs),
              Flexible(flex: 4, child: presence),
            ],
            ?trailing,
          ],
        ),
      ),
    );
  }
}

enum _MemberAction { deputy, member, transfer, remove, mute, unmute, profile }

class _MemberTile extends ConsumerWidget {
  const new({required this.family, required this.member});

  final Family family;
  final FamilyMember member;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _MemberAction action,
  ) async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    final user = member.user;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    try {
      switch (action) {
        case _MemberAction.profile:
          unawaited(context.push(AppRoutes.userProfile(user.username)));
          return;
        case _MemberAction.deputy || _MemberAction.member:
          await repo.setRole(
            family.id,
            user.username,
            action == _MemberAction.deputy
                ? FamilyRole.deputy
                : FamilyRole.member,
          );
          if (context.mounted) {
            KSnack.success(context, l10n.familyRoleChanged(name));
          }
        case _MemberAction.transfer:
          final ok = await confirmBond(
            context,
            title: l10n.familyTransferTitle(name),
            body: l10n.familyTransferBody(name),
            confirm: l10n.familyTransfer,
          );
          if (!ok) return;
          await repo.transfer(family.id, user.username);
          if (context.mounted) {
            KSnack.success(context, l10n.familyTransferred(name));
          }
        case _MemberAction.remove:
          final ok = await confirmBond(
            context,
            title: l10n.familyRemoveTitle(name),
            confirm: l10n.familyRemove,
            destructive: true,
          );
          if (!ok) return;
          await repo.removeMember(family.id, user.username);
          if (context.mounted) {
            KSnack.success(context, l10n.familyRemoved(name));
          }
        case _MemberAction.mute || _MemberAction.unmute:
          final mute = action == _MemberAction.mute;
          await repo.setChatMuted(family.id, user.username, muted: mute);
          if (context.mounted) {
            KSnack.success(
              context,
              mute
                  ? l10n.familyChatMutedName(name)
                  : l10n.familyChatUnmutedName(name),
            );
          }
      }
      if (context.mounted) refreshFamilies(ref, familyId: family.id);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final user = member.user;
    final leader = family.myRole == FamilyRole.leader;
    final deputy = family.myRole == FamilyRole.deputy;
    final manage = leader && member.role != FamilyRole.leader;
    final canMute =
        (leader && member.role != FamilyRole.leader) ||
        (deputy && member.role == FamilyRole.member);
    final muted = member.chatMuted ?? false;
    return _PersonRow(
      key: FamilyScreen.memberKey(user.username),
      rank: member.rank,
      user: user,
      role: member.role,
      line: l10n.familyPoints(formatBondPoints(member.points)),
      presence: FamilyPresenceLabel(presence: member.presence),
      trailing: PopupMenuButton<_MemberAction>(
        key: FamilyScreen.memberMenuKey(user.username),
        tooltip: l10n.familyMemberActions,
        icon: Icon(Icons.more_vert_rounded, color: p.textSecondary),
        onSelected: (a) => unawaited(_act(context, ref, a)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _MemberAction.profile,
            child: Text(l10n.familyViewProfile),
          ),
          if (manage) ...[
            if (member.role == FamilyRole.member)
              PopupMenuItem(
                value: _MemberAction.deputy,
                child: Text(l10n.familyMakeDeputy),
              )
            else
              PopupMenuItem(
                value: _MemberAction.member,
                child: Text(l10n.familyMakeMember),
              ),
            PopupMenuItem(
              value: _MemberAction.transfer,
              child: Text(l10n.familyTransfer),
            ),
          ],
          if (canMute)
            PopupMenuItem(
              value: muted ? _MemberAction.unmute : _MemberAction.mute,
              child: Text(muted ? l10n.familyChatUnmute : l10n.familyChatMute),
            ),
          if (manage)
            PopupMenuItem(
              value: _MemberAction.remove,
              child: Text(l10n.familyRemove, style: TextStyle(color: p.error)),
            ),
        ],
      ),
    );
  }
}

/// The Ranking tab: the family's place on both boards.
class _Standing extends ConsumerWidget {
  const new({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(familyStandingProvider(family.id));
    Widget card(
      String title,
      IconData icon,
      FamilyBoardStanding s,
      String score,
    ) => Container(
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: FamilyColors.goldGradient,
            ),
            child: Icon(icon, color: const Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong.copyWith(color: p.textPrimary)),
                Text(score, style: t.caption.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
          Text(
            s.rank == null ? l10n.familyRankNone : '#${s.rank}',
            style: t.title.copyWith(
              color: s.rank == null ? p.textTertiary : FamilyColors.goldDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Padding(
      key: FamilyScreen.standingKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        0,
      ),
      child: switch (load) {
        AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card(
              l10n.familiesTabPrestige,
              Icons.workspace_premium_rounded,
              value.prestige,
              l10n.familiesScoreMonth(
                familyCount(context, value.prestige.score),
              ),
            ),
            card(
              l10n.familiesTabActive,
              Icons.bar_chart_rounded,
              value.active,
              l10n.familiesScoreActive(
                familyCount(context, value.active.score),
              ),
            ),
            Text(
              l10n.familyRankingNote,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.familyLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(familyStandingProvider(family.id)),
          compact: true,
        ),
        _ => const Padding(
          padding: EdgeInsets.all(KSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }
}

/// The leader's manage sheet: emblem, cover, tagline (the ⋯ has them too).
Future<void> _showManageSheet(BuildContext context, Family family) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final l10n = sheet.l10n;
          final menu = _FamilyMenu(family: family);
          void run(Future<void> Function() f) {
            Navigator.of(sheet).pop();
            unawaited(f());
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l10n.familyChangeEmblem),
                  onTap: () => run(() => menu._changeEmblem(context, ref)),
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(l10n.familyChangeCover),
                  onTap: () => run(() => menu._changeCover(context, ref)),
                ),
                ListTile(
                  leading: const Icon(Icons.short_text_rounded),
                  title: Text(l10n.familyTaglineTitle),
                  onTap: () => run(() => menu._editTagline(context, ref)),
                ),
              ],
            ),
          );
        },
      ),
    );

/// Pending join requests (leader and deputies) in a sheet.
Future<void> _showRequests(BuildContext context, Family family) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: _Requests(key: FamilyScreen.requestsKey, family: family),
        ),
      ),
    );

/// Pending join requests, with Accept and Decline.
class _Requests extends ConsumerWidget {
  const new({required this.family, super.key});

  final Family family;

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    FamilyJoinRequest request, {
    required bool accept,
  }) async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    final name = request.user.displayName.isEmpty
        ? request.user.username
        : request.user.displayName;
    try {
      if (accept) {
        await repo.acceptRequest(family.id, request.id);
      } else {
        await repo.declineRequest(family.id, request.id);
      }
      if (!context.mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(
        context,
        accept ? l10n.familyAccepted(name) : l10n.familyDeclined,
      );
    } on Object catch (e) {
      if (!context.mounted) return;
      // Already answered, expired, or they joined elsewhere: the list
      // shows what is left.
      if (isErrorCode(e, ErrorCode.familyRequestNotPending) ||
          isErrorCode(e, ErrorCode.alreadyInFamily)) {
        ref
            .read(familyJoinRequestsProvider(family.id).notifier)
            .remove(request.id);
      }
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(familyJoinRequestsProvider(family.id));
    final items = switch (load) {
      AsyncValue(value: FeedItems(:final items)) => items,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BondSectionTitle(l10n.familyRequestsTitle),
        if (items == null && load.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: KInlineMessage(
              message: failureMessage(l10n, toAppFailure(load.error!)),
            ),
          )
        else if (items == null)
          const Padding(
            padding: EdgeInsets.all(KSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Text(
              l10n.familyRequestsEmpty,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          )
        else
          for (final r in items)
            ListTile(
              leading: KAvatar(
                name: r.user.displayName.isEmpty
                    ? r.user.username
                    : r.user.displayName,
                imageUrl: r.user.avatarUrl,
                size: 40,
              ),
              title: Text(
                r.user.displayName.isEmpty
                    ? r.user.username
                    : r.user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.profileUsername(r.user.username),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: FamilyScreen.declineKey(r.id),
                    tooltip: l10n.familyDecline,
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    onPressed: () =>
                        unawaited(_answer(context, ref, r, accept: false)),
                  ),
                  IconButton(
                    key: FamilyScreen.acceptKey(r.id),
                    tooltip: l10n.familyAccept,
                    icon: Icon(Icons.check_circle_rounded, color: p.success),
                    onPressed: () =>
                        unawaited(_answer(context, ref, r, accept: true)),
                  ),
                ],
              ),
            ),
        const SizedBox(height: KSpacing.lg),
      ],
    );
  }
}

/// The bottom bar: Message the family + Invite members (members), or Ask to
/// join / Cancel (others).
class _BottomBar extends ConsumerStatefulWidget {
  const new({required this.family});

  final Family family;

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  bool _busy = false;

  Family get family => widget.family;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final repo = ref.read(familiesRepositoryProvider);
    void joined() {
      if (!mounted) return;
      refreshFamilies(ref, familyId: family.id);
      KSnack.success(context, l10n.familyJoinSent);
    }

    var pendingElsewhere = false;
    await _run(() async {
      try {
        await repo.requestToJoin(family.id);
      } on Object catch (e) {
        if (!isErrorCode(e, ErrorCode.familyRequestPending)) rethrow;
        pendingElsewhere = true;
        return;
      }
      joined();
    });
    if (!pendingElsewhere || !mounted) return;
    // One pending request at a time: offer to cancel the other one.
    final cancel = await confirmBond(
      context,
      title: l10n.errorFamilyRequestPending,
      confirm: l10n.familyCancelRequest,
    );
    if (!cancel || !mounted) return;
    await _run(() async {
      await repo.cancelMyRequest();
      await repo.requestToJoin(family.id);
      joined();
    });
  }

  Future<void> _cancel() => _run(() async {
    await ref.read(familiesRepositoryProvider).cancelMyRequest();
    if (!mounted) return;
    refreshFamilies(ref, familyId: family.id);
    KSnack.success(context, context.l10n.familyRequestCancelled);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final role = family.myRole;
    final mine = ref.watch(myFamilyProvider).value;
    final Widget child;
    if (role != null) {
      child = Row(
        children: [
          Expanded(
            flex: 11,
            child: OutlinedButton.icon(
              key: FamilyScreen.chatKey,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: p.textPrimary,
                side: BorderSide(color: p.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadius.lg),
                ),
              ),
              onPressed: () => context.push(AppRoutes.familyChat(family.id)),
              icon: const Icon(Icons.chat_bubble_rounded, size: 20),
              label: Text(
                l10n.familyChatOpen,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            flex: 12,
            child: FamilyGoldButton(
              key: FamilyScreen.inviteKey,
              label: l10n.familyInvite,
              icon: Icons.person_add_alt_1_rounded,
              height: 48,
              expand: true,
              onPressed: () => unawaited(_copyInvite(context, family)),
            ),
          ),
        ],
      );
    } else if (family.myRequestId != null) {
      child = Row(
        children: [
          Expanded(
            child: Text(
              l10n.familyRequested,
              style: t.body.copyWith(color: p.textSecondary),
            ),
          ),
          KButton(
            key: FamilyScreen.cancelKey,
            label: l10n.familyCancelRequest,
            variant: KButtonVariant.secondary,
            expand: false,
            loading: _busy,
            onPressed: _cancel,
          ),
        ],
      );
    } else if (mine != null) {
      child = KInlineMessage(message: l10n.familyInOther, isError: false);
    } else {
      child = FamilyGoldButton(
        key: FamilyScreen.joinKey,
        label: family.isFull ? l10n.familyFullLabel : l10n.familyJoin,
        icon: family.isFull ? null : Icons.add_rounded,
        height: 48,
        expand: true,
        busy: _busy,
        onPressed: family.isFull ? null : _join,
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.lg,
          KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: p.background,
          border: Border(top: BorderSide(color: p.border, width: 0.5)),
        ),
        child: child,
      ),
    );
  }
}

/// Edits the tagline (1–60 characters; empty removes it).
class _TaglineDialog extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_TaglineDialog> createState() => _TaglineDialogState();
}

class _TaglineDialogState extends State<_TaglineDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.familyTaglineTitle),
      content: TextField(
        key: FamilyScreen.taglineKey,
        controller: _controller,
        maxLength: 60,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.familyTaglineHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bondsCancel),
        ),
        TextButton(
          key: bondConfirmKey,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.familySave),
        ),
      ],
    );
  }
}
