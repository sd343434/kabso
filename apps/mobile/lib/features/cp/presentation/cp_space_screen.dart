import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/application/cp_providers.dart';
import 'package:kabso_live/features/cp/application/cp_space_providers.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_art.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// The CP space (CP-021, CONVENTIONS §10.24, D112): your couple's page —
// both pictures in the winged heart with the days together, the CP level
// and its progress, today's tasks (claimed once a day), the five
// privileges, the named couple gifts and their wall, the confession wall
// and the couples ranking — and the same page read-only for anyone else's
// couple. Everything comes from the server; nothing is invented.

/// Left-to-right isolate (U+2066); the text ends with the paragraph.
const _ltr = '\u2066';

String _nameOf(UserSummary u) =>
    u.displayName.isEmpty ? u.username : u.displayName;

/// One partner as the hero shows them.
typedef _Person = ({String name, String? avatarUrl, String? username});

/// What the page shows of a couple, from `GET /cp/me` (yours) or
/// `GET /cp/couples/{id}` (anyone's).
@immutable
class _Couple {
  const new({
    required this.id,
    required this.first,
    required this.second,
    required this.days,
    required this.points,
    required this.level,
    required this.levelName,
    required this.nextLevelName,
    required this.pointsToNext,
    required this.own,
    this.privileges = const {},
  });

  /// Your couple: you first, your partner second.
  factory own(CpCouple cp, User? me) => _Couple(
    id: cp.id,
    first: (
      name: me == null
          ? ''
          : me.displayName.isEmpty
          ? me.username
          : me.displayName,
      avatarUrl: me?.avatarUrl,
      username: me?.username,
    ),
    second: (
      name: _nameOf(cp.partner),
      avatarUrl: cp.partner.avatarUrl,
      username: cp.partner.username,
    ),
    days: cp.days,
    points: cp.points,
    level: cp.level,
    levelName: cp.levelName,
    nextLevelName: cp.nextLevelName,
    pointsToNext: cp.pointsToNext,
    own: true,
  );

  /// Someone else's couple, read-only.
  factory public(CpCouplePublic c) {
    _Person person(UserSummary u) =>
        (name: _nameOf(u), avatarUrl: u.avatarUrl, username: u.username);
    return _Couple(
      id: c.id,
      first: person(c.partners.first),
      second: person(c.partners.last),
      days: c.days,
      points: c.points,
      level: c.level,
      levelName: c.levelName,
      nextLevelName: c.nextLevelName,
      pointsToNext: c.pointsToNext,
      own: false,
      privileges: c.privileges,
    );
  }

  final String id;
  final _Person first;
  final _Person second;
  final int days;
  final int points;
  final int level;
  final String levelName;
  final String? nextLevelName;
  final int? pointsToNext;

  /// The caller's own couple: tasks, sending, writing and deleting.
  final bool own;

  /// Someone else's couple: the privileges it unlocked.
  final Set<CpPrivilegeCode> privileges;
}

/// `/cp/space`: the caller's couple's CP space. Not paired: says so and
/// offers the CP page (requests). Opening it checks in for today.
class CpSpaceScreen extends ConsumerWidget {
  const new({super.key});

  static const viewKey = Key('cpSpace.view');
  static const noneKey = Key('cpSpace.none');
  static const goneKey = Key('cpSpace.gone');
  static const helpKey = Key('cpSpace.help');
  static const levelKey = Key('cpSpace.level');
  static const tasksKey = Key('cpSpace.tasks');
  static const privilegesKey = Key('cpSpace.privileges');
  static const giftsKey = Key('cpSpace.gifts');
  static const confessionsKey = Key('cpSpace.confessions');
  static const giftWallKey = Key('cpSpace.giftWall');
  static const confessionFieldKey = Key('cpSpace.confession.field');
  static const confessionSendKey = Key('cpSpace.confession.send');
  static const rankingWeekKey = Key('cpSpace.ranking.week');
  static const rankingAllKey = Key('cpSpace.ranking.all');
  static const rankingMeKey = Key('cpSpace.ranking.me');
  static const tiersKey = Key('cpSpace.tiers');

  static Key actionKey(String name) => Key('cpSpace.action.$name');
  static Key claimKey(String code) => Key('cpSpace.task.$code.claim');
  static Key taskKey(String code) => Key('cpSpace.task.$code');
  static Key privilegeKey(CpPrivilegeCode code) =>
      Key('cpSpace.privilege.${code.wire}');
  static Key giftKey(int amount) => Key('cpSpace.gift.$amount');
  static Key confessionKey(String id) => Key('cpSpace.confession.$id');
  static Key confessionMenuKey(String id) => Key('cpSpace.confession.$id.menu');
  static Key rankingKey(String coupleId) => Key('cpSpace.ranking.$coupleId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(currentUserProvider);
    return switch (ref.watch(myCpProvider)) {
      AsyncValue(value: final CpCouple cp) => _CpSpaceView(
        key: viewKey,
        couple: _Couple.own(cp, me),
      ),
      AsyncValue(hasValue: true) => _Frame(
        child: KEmptyState(
          key: noneKey,
          icon: Icons.favorite_border_rounded,
          iconColor: CpSpaceColors.accent,
          title: l10n.cpNoneTitle,
          message: l10n.cpNoneBody,
          actionLabel: l10n.cpRequestsTitle,
          onAction: () => context.pushReplacement(AppRoutes.cp),
          compact: true,
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => _Frame(
        child: FailureErrorState(
          title: l10n.cpSpaceLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myCpProvider),
          compact: true,
        ),
      ),
      _ => const _Frame(child: CircularProgressIndicator()),
    };
  }
}

/// `/cp/couples/{coupleId}`: a couple's CP space, read-only (your own
/// opens in full). 404: the couple ended or cannot be shown to you.
class CpCoupleScreen extends ConsumerWidget {
  const new({required this.coupleId, super.key});

  final String coupleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(cpCoupleProvider(coupleId))) {
      AsyncValue(value: final CpCouplePublic c) when c.mine =>
        const CpSpaceScreen(),
      AsyncValue(value: final CpCouplePublic c) => _CpSpaceView(
        key: CpSpaceScreen.viewKey,
        couple: _Couple.public(c),
      ),
      AsyncValue(:final error?, isLoading: false)
          when isErrorCode(error, ErrorCode.notFound) =>
        _Frame(
          child: KEmptyState(
            key: CpSpaceScreen.goneKey,
            icon: Icons.heart_broken_outlined,
            iconColor: CpSpaceColors.accent,
            title: l10n.cpSpaceGoneTitle,
            message: l10n.cpSpaceGoneBody,
            compact: true,
          ),
        ),
      AsyncValue(:final error?, isLoading: false) => _Frame(
        child: FailureErrorState(
          title: l10n.cpSpaceLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(cpCoupleProvider(coupleId)),
          compact: true,
        ),
      ),
      _ => const _Frame(child: CircularProgressIndicator()),
    };
  }
}

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// The page's background: the owner's palace art at the top fading into
/// the page pink.
class _Backdrop extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxWidth * 1672 / 941;
      return Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: CpSpaceColors.page)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h,
            child: Image.asset(
              CpSpaceAssets.background,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            top: h * 0.45,
            left: 0,
            right: 0,
            height: h * 0.55 + 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FAD3E4), CpSpaceColors.page],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The top bar on the art: back, title and (on the full page) help.
class _TopBar extends StatelessWidget {
  const new({this.onHelp});

  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const shadow = [Shadow(color: CpSpaceColors.artShadow, blurRadius: 6)];
    return SizedBox(
      height: KSizes.minTouchTarget + KSpacing.xs,
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: CpSpaceColors.onArt,
              shadows: shadow,
            ),
            onPressed: () => _back(context),
          ),
          Expanded(
            child: Text(
              l10n.cpSpaceTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
              style: context.textStyles.headline.copyWith(
                color: CpSpaceColors.onArt,
                fontWeight: FontWeight.w800,
                shadows: cpArtTextShadow,
              ),
            ),
          ),
          if (onHelp != null)
            IconButton(
              key: CpSpaceScreen.helpKey,
              tooltip: l10n.cpSpaceHelpTitle,
              icon: const Icon(
                Icons.help_outline_rounded,
                color: CpSpaceColors.onArt,
                shadows: shadow,
              ),
              onPressed: onHelp,
            )
          else
            const SizedBox(width: KSizes.minTouchTarget),
        ],
      ),
    );
  }
}

/// Loading, empty and error states on the page's art.
class _Frame extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CpSpaceColors.page,
    body: Stack(
      children: [
        const Positioned.fill(child: _Backdrop()),
        KTopSafeArea(
          bottom: true,
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.lg),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CpSpaceColors.card,
                        borderRadius: BorderRadius.circular(KRadius.xl),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: _LightTheme(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A bottom sheet in the page's light theme (sheets open on the root
/// navigator, outside the page's theme).
Future<void> _modal({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: backgroundColor,
  isScrollControlled: isScrollControlled,
  builder: (_) => _LightTheme(child: Builder(builder: builder)),
);

/// The app's light theme with the page's pink accent: the page is always
/// light pink art, so its states, fields, dialogs and sheets read light.
class _LightTheme extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = buildAppTheme(
      brightness: Brightness.light,
      locale: Localizations.localeOf(context),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: CpSpaceColors.accent),
      ),
      child: child,
    );
  }
}

class _CpSpaceView extends ConsumerStatefulWidget {
  const new({required this.couple, super.key});

  final _Couple couple;

  @override
  ConsumerState<_CpSpaceView> createState() => _CpSpaceViewState();
}

class _CpSpaceViewState extends ConsumerState<_CpSpaceView> {
  final GlobalKey _tasks = GlobalKey();
  final GlobalKey _privileges = GlobalKey();
  final GlobalKey _gifts = GlobalKey();

  _Couple get couple => widget.couple;

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : KMotion.slow,
      curve: KMotion.standard,
    );
  }

  Future<void> _refresh() async {
    if (couple.own) {
      refreshCp(ref);
      ref
        ..invalidate(cpTasksProvider)
        ..invalidate(cpPrivilegesProvider)
        ..invalidate(cpConfessionsProvider(null))
        ..invalidate(cpGiftWallProvider(couple.id));
      await ref.read(myCpProvider.future);
    } else {
      ref
        ..invalidate(cpCoupleProvider(couple.id))
        ..invalidate(cpConfessionsProvider(couple.id))
        ..invalidate(cpGiftWallProvider(couple.id));
      await ref.read(cpCoupleProvider(couple.id).future);
    }
  }

  void _help() {
    final l10n = context.l10n;
    final zone = ref.read(cpTasksProvider).value?.timeZone ?? 'UTC';
    unawaited(
      _modal(
        context: context,
        backgroundColor: CpSpaceColors.page,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.cpSpaceHelpTitle,
                  style: sheet.textStyles.title.copyWith(
                    color: CpSpaceColors.accentDeep,
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.cpSpaceHelpBody(zone),
                  style: sheet.textStyles.body.copyWith(
                    color: CpSpaceColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile(String? username) {
    if (username == null || username.isEmpty) return;
    unawaited(context.push(AppRoutes.userProfile(username)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final heroWidth = math.min<double>(media.size.width, 520);
    final actions = <(String, String, String, VoidCallback)>[
      if (couple.own)
        (
          'tasks',
          CpSpaceAssets.taskDaily,
          l10n.cpSpaceActionTasks,
          () => unawaited(_scrollTo(_tasks)),
        ),
      (
        'privileges',
        CpSpaceAssets.privilege,
        l10n.cpSpaceActionPrivileges,
        () => unawaited(_scrollTo(_privileges)),
      ),
      (
        'gifts',
        CpSpaceAssets.gift,
        l10n.cpSpaceActionGifts,
        () => unawaited(_scrollTo(_gifts)),
      ),
      (
        'ranking',
        CpSpaceAssets.ranking,
        l10n.cpSpaceActionRanking,
        () => unawaited(showCpRanking(context)),
      ),
    ];
    const gap = SizedBox(height: KSpacing.lg);
    return Scaffold(
      backgroundColor: CpSpaceColors.page,
      body: _LightTheme(
        child: Stack(
          children: [
            const Positioned.fill(child: _Backdrop()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: KTopInset.of(context) + 56 + CpHero.heightFor(heroWidth),
              child: const CpRisingHearts(),
            ),
            RefreshIndicator(
              color: CpSpaceColors.accent,
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.only(bottom: media.padding.bottom + 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: KTopInset.of(context)),
                  _TopBar(onHelp: couple.own ? _help : null),
                  Center(
                    child: CpHero(
                      width: heroWidth,
                      start: (
                        name: couple.first.name,
                        avatarUrl: couple.first.avatarUrl,
                      ),
                      end: (
                        name: couple.second.name,
                        avatarUrl: couple.second.avatarUrl,
                      ),
                      days: l10n.cpSpaceDays(couple.days),
                      onStart: () => _openProfile(couple.first.username),
                      onEnd: () => _openProfile(couple.second.username),
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                  _QuickActions(actions: actions),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: KSpacing.sm),
                        _LevelCard(couple: couple),
                        if (couple.own) ...[gap, _TasksCard(key: _tasks)],
                        gap,
                        _PrivilegesCard(key: _privileges, couple: couple),
                        gap,
                        _GiftsCard(key: _gifts, couple: couple),
                        gap,
                        _ConfessionsCard(couple: couple),
                      ],
                    ),
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

class _QuickActions extends StatelessWidget {
  const new({required this.actions});

  final List<(String, String, String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, icon, label, onTap) in actions)
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  key: CpSpaceScreen.actionKey(name),
                  borderRadius: BorderRadius.circular(KRadius.lg),
                  onTap: onTap,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x55FFFFFF), Color(0x33FF8DBE)],
                      ),
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      border: Border.all(color: const Color(0x99FFFFFF)),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          icon,
                          width: 52,
                          height: 52,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.xxs,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: 1.3),
                              style: t.label.copyWith(
                                color: CpSpaceColors.onArt,
                                fontWeight: FontWeight.w700,
                                shadows: cpArtTextShadow,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded pink gradient bar of [value] (0–1).
class _Progress extends StatelessWidget {
  const new({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(KRadius.pill),
    child: SizedBox(
      height: 10,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: CpSpaceColors.progressTrack),
          ),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CpSpaceColors.progressStart,
                    CpSpaceColors.progressEnd,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The CP level ("intimacy" = CP points): the level, its name, the
/// progress to the next tier from the server's ladder, and the ladder.
class _LevelCard extends ConsumerWidget {
  const new({required this.couple});

  final _Couple couple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final tiers = ref.watch(cpConfigProvider).value?.tiers ?? const [];
    final current = tiers.where((x) => x.level == couple.level).firstOrNull;
    final toNext = couple.pointsToNext;
    final nextAt = toNext == null ? null : couple.points + toNext;
    final from = current?.minPoints ?? 0;
    final progress = nextAt == null
        ? 1.0
        : (couple.points - from) / math.max(1, nextAt - from);
    final points = formatBondPoints(couple.points);
    return CpSectionCard(
      key: CpSpaceScreen.levelKey,
      title: l10n.cpSpaceLevelTitle,
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.lg),
        onTap: tiers.isEmpty
            ? null
            : () => unawaited(_showTiers(context, tiers, couple.level)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [CpSpaceColors.accent, CpSpaceColors.progressEnd],
                    ).createShader(r),
                    child: Text(
                      l10n.cpSpaceLevel(couple.level),
                      style: t.display.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    couple.levelName,
                    style: t.bodyStrong.copyWith(
                      color: CpSpaceColors.accentDeep,
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                  _Progress(value: progress),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    nextAt == null
                        ? l10n.cpSpaceIntimacy(points)
                        // Numbers left to right in Arabic too.
                        : _ltr +
                              l10n.cpSpaceProgress(
                                points,
                                formatBondPoints(nextAt),
                              ),
                    style: t.label.copyWith(color: CpSpaceColors.ink),
                  ),
                  Text(switch ((toNext, couple.nextLevelName)) {
                    (final int left, final String next) => l10n.cpSpaceToNext(
                      formatBondPoints(left),
                      KFormat.bidiIsolate(next),
                    ),
                    _ => l10n.cpTopTier,
                  }, style: t.caption.copyWith(color: CpSpaceColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Image.asset(
              CpSpaceAssets.heart,
              width: 64,
              height: 64,
              excludeFromSemantics: true,
            ),
            if (tiers.isNotEmpty)
              const Icon(
                // Mirrors itself in Arabic.
                Icons.chevron_right_rounded,
                color: CpSpaceColors.accent,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTiers(BuildContext context, List<CpTier> tiers, int level) {
    final l10n = context.l10n;
    return _modal(
      context: context,
      backgroundColor: CpSpaceColors.page,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
          ),
          child: ListView(
            key: CpSpaceScreen.tiersKey,
            shrinkWrap: true,
            padding: const EdgeInsets.all(KSpacing.lg),
            children: [
              Text(
                l10n.cpSpaceLevelTitle,
                style: sheet.textStyles.title.copyWith(
                  color: CpSpaceColors.accentDeep,
                ),
              ),
              for (final tier in tiers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    l10n.cpSpaceLevel(tier.level),
                    style: sheet.textStyles.bodyStrong.copyWith(
                      color: CpSpaceColors.accent,
                    ),
                  ),
                  title: Text(
                    tier.name,
                    style: const TextStyle(color: CpSpaceColors.ink),
                  ),
                  subtitle: Text(
                    l10n.cpSpaceIntimacy(formatBondPoints(tier.minPoints)),
                    style: const TextStyle(color: CpSpaceColors.inkSoft),
                  ),
                  trailing: tier.level == level
                      ? const Icon(
                          Icons.favorite_rounded,
                          color: CpSpaceColors.accent,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's tasks of your couple; a done task's reward is claimed once a
/// day (either partner).
class _TasksCard extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tasks = ref.watch(cpTasksProvider);
    return CpSectionCard(
      key: CpSpaceScreen.tasksKey,
      title: l10n.cpSpaceActionTasks,
      child: switch (tasks) {
        AsyncValue(value: final CpTasks day) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cpSpaceTasksResets(
                KFormat.time(day.resetsAt.toLocal(), locale),
              ),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
            ),
            for (final task in day.tasks) _TaskRow(task: task),
          ],
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.cpSpaceTasksError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(cpTasksProvider),
          embedded: true,
        ),
        _ => const Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }
}

class _TaskRow extends ConsumerStatefulWidget {
  const new({required this.task});

  final CpTask task;

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool _busy = false;

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final result = await ref
          .read(cpTasksProvider.notifier)
          .claim(widget.task.code);
      if (!mounted) return;
      refreshCp(ref);
      ref.invalidate(cpPrivilegesProvider);
      if (result.added) {
        KSnack.success(
          context,
          l10n.cpSpaceClaimedToast(formatBondPoints(result.task.reward)),
        );
      } else {
        KSnack.info(context, l10n.cpSpaceClaimedBefore);
      }
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      if (failure.code == ErrorCode.cpNotPaired) refreshCp(ref);
      KSnack.error(context, failureMessage(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final task = widget.task;
    final Widget trailing;
    if (_busy) {
      trailing = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (task.claimed) {
      trailing = _Pill(
        label: l10n.cpSpaceClaimed,
        icon: Icons.check_rounded,
        muted: true,
      );
    } else if (task.completed) {
      trailing = FilledButton(
        key: CpSpaceScreen.claimKey(task.code),
        style: FilledButton.styleFrom(
          backgroundColor: CpSpaceColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(72, 36),
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
        ),
        onPressed: () => unawaited(_claim()),
        child: Text(l10n.cpSpaceClaim),
      );
    } else {
      trailing = _Pill(
        label: l10n.cpSpaceTaskProgress(task.progress, task.target),
        muted: true,
      );
    }
    return Padding(
      key: CpSpaceScreen.taskKey(task.code),
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          color: CpSpaceColors.chip.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: _TaskLayout(
          icon: Image.asset(
            CpSpaceAssets.taskDaily,
            width: 40,
            height: 40,
            excludeFromSemantics: true,
          ),
          trailing: trailing,
          info: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.name,
                style: t.bodyStrong.copyWith(color: CpSpaceColors.ink),
              ),
              Text(
                task.description,
                style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
              ),
              const SizedBox(height: KSpacing.xxs),
              Row(
                children: [
                  Image.asset(
                    CpSpaceAssets.heart,
                    width: 16,
                    height: 16,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: KSpacing.xxs),
                  Flexible(
                    child: Text(
                      l10n.cpSpaceTaskReward(formatBondPoints(task.reward)),
                      style: t.label.copyWith(color: CpSpaceColors.accent),
                    ),
                  ),
                  if (!task.completed && !task.claimed) ...[
                    const SizedBox(width: KSpacing.sm),
                    Flexible(
                      child: Text(
                        l10n.cpSpaceNotDone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A task: icon, text and the action side by side; at large text sizes the
/// action goes under the text so nothing is squeezed.
class _TaskLayout extends StatelessWidget {
  const new({required this.icon, required this.info, required this.trailing});

  final Widget icon;
  final Widget info;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final top = Row(
      children: [
        icon,
        const SizedBox(width: KSpacing.sm),
        Expanded(child: info),
        if (!large) ...[const SizedBox(width: KSpacing.sm), trailing],
      ],
    );
    if (!large) return top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: KSpacing.xs),
        Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.label, this.icon, this.muted = false});

  final String label;
  final IconData? icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? CpSpaceColors.inkSoft : CpSpaceColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: CpSpaceColors.progressTrack),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: KSpacing.xxs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.label.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String _privilegeName(AppLocalizations l10n, CpPrivilegeCode code) =>
    switch (code) {
      CpPrivilegeCode.specialFrame => l10n.cpPrivSpecialFrame,
      CpPrivilegeCode.chatBubble => l10n.cpPrivChatBubble,
      CpPrivilegeCode.micEffect => l10n.cpPrivMicEffect,
      CpPrivilegeCode.entranceEffect => l10n.cpPrivEntranceEffect,
      CpPrivilegeCode.giftWall => l10n.cpPrivGiftWall,
    };

String _status(AppLocalizations l10n, bool unlocked, int level) =>
    unlocked ? l10n.cpSpaceUnlocked : l10n.cpSpaceUnlocksAt(level);

String _privilegeAbout(AppLocalizations l10n, CpPrivilegeCode code) =>
    switch (code) {
      CpPrivilegeCode.specialFrame => l10n.cpPrivSpecialFrameAbout,
      CpPrivilegeCode.chatBubble => l10n.cpPrivChatBubbleAbout,
      CpPrivilegeCode.micEffect => l10n.cpPrivMicEffectAbout,
      CpPrivilegeCode.entranceEffect => l10n.cpPrivEntranceEffectAbout,
      CpPrivilegeCode.giftWall => l10n.cpPrivGiftWallAbout,
    };

/// The five privileges: yours from `GET /cp/me/privileges`, another
/// couple's from its page; locked ones say the level that unlocks them.
class _PrivilegesCard extends ConsumerWidget {
  const new({required this.couple, super.key});

  final _Couple couple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Widget body;
    if (couple.own) {
      body = switch (ref.watch(cpPrivilegesProvider)) {
        AsyncValue(value: final CpPrivileges p) => _privilegeRow(context, [
          for (final x in p.privileges)
            (code: x.code, unlocked: x.unlocked, level: x.unlockLevel),
        ]),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.cpSpaceLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(cpPrivilegesProvider),
          embedded: true,
        ),
        _ => const Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      };
    } else {
      body = _privilegeRow(context, [
        for (final code in CpPrivilegeCode.values)
          (
            code: code,
            unlocked: couple.privileges.contains(code),
            level: code.unlockLevel,
          ),
      ]);
    }
    return CpSectionCard(
      key: CpSpaceScreen.privilegesKey,
      title: l10n.cpSpaceActionPrivileges,
      child: body,
    );
  }

  Widget _privilegeRow(
    BuildContext context,
    List<({CpPrivilegeCode code, bool unlocked, int level})> items,
  ) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in items)
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${_privilegeName(l10n, p.code)}, '
                  '${_status(l10n, p.unlocked, p.level)}',
              excludeSemantics: true,
              child: InkWell(
                key: CpSpaceScreen.privilegeKey(p.code),
                borderRadius: BorderRadius.circular(KRadius.md),
                onTap: () => unawaited(
                  _showPrivilege(context, p.code, p.unlocked, p.level),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.xxs,
                    vertical: KSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [Colors.white, CpSpaceColors.chip],
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: p.unlocked ? 1 : 0.45,
                            child: Image.asset(
                              CpSpaceAssets.privilegeIcon(p.code),
                              width: 50,
                              height: 50,
                              excludeFromSemantics: true,
                            ),
                          ),
                          if (!p.unlocked)
                            PositionedDirectional(
                              bottom: -4,
                              end: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: CpSpaceColors.locked,
                                  borderRadius: BorderRadius.circular(
                                    KRadius.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lock_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      l10n.cpSpaceLevel(p.level),
                                      textScaler: TextScaler.noScaling,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        _privilegeName(l10n, p.code),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: p.unlocked
                              ? CpSpaceColors.ink
                              : CpSpaceColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showPrivilege(
    BuildContext context,
    CpPrivilegeCode code,
    bool unlocked,
    int level,
  ) {
    final l10n = context.l10n;
    final who = couple.first;
    return _modal(
      context: context,
      backgroundColor: CpSpaceColors.page,
      isScrollControlled: true,
      builder: (sheet) {
        final t = sheet.textStyles;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (code == CpPrivilegeCode.specialFrame)
                  CpFramedAvatar(
                    size: 200,
                    child: _Fill(name: who.name, url: who.avatarUrl),
                  )
                else
                  Image.asset(
                    CpSpaceAssets.privilegeIcon(code),
                    width: 140,
                    height: 140,
                    excludeFromSemantics: true,
                  ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  _privilegeName(l10n, code),
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(color: CpSpaceColors.accentDeep),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  _privilegeAbout(l10n, code),
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: CpSpaceColors.ink),
                ),
                const SizedBox(height: KSpacing.md),
                _Pill(
                  label: unlocked
                      ? l10n.cpSpaceUnlocked
                      : l10n.cpSpaceUnlocksAt(level),
                  icon: unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  muted: !unlocked,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A picture filling its box (cover), or the initials when there is none.
class _Fill extends StatelessWidget {
  const new({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final side = math.max(box.maxWidth, box.maxHeight) * 1.1;
      return OverflowBox(
        maxWidth: side,
        maxHeight: side,
        child: KAvatar(name: name, imageUrl: url, size: side),
      );
    },
  );
}

/// The named couple gifts (`CpConfig.gifts`, or the bare amounts from an
/// older server): your couple sends them; anyone sees the cards. Then the
/// gift wall.
class _GiftsCard extends ConsumerStatefulWidget {
  const new({required this.couple, super.key});

  final _Couple couple;

  @override
  ConsumerState<_GiftsCard> createState() => _GiftsCardState();
}

class _GiftsCardState extends ConsumerState<_GiftsCard> {
  int? _sending;
  final Map<int, String> _clientIds = {};

  Future<void> _send(int amount, String name) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.cpSpaceGiftConfirm(name, l10n.bondsCoins(amount)),
      body: l10n.cpGiftBody,
      confirm: l10n.cpGiftTitle,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = amount);
    final clientId = _clientIds.putIfAbsent(amount, newClientId);
    try {
      final result = await ref
          .read(cpRepositoryProvider)
          .sendGift(amount: amount, clientId: clientId);
      _clientIds.remove(amount);
      if (!mounted) return;
      showCoins(ref, result.coins);
      refreshCp(ref);
      ref
        ..invalidate(cpTasksProvider)
        ..invalidate(cpPrivilegesProvider)
        ..invalidate(cpGiftWallProvider(widget.couple.id));
      KSnack.success(
        context,
        l10n.cpGiftSent(formatBondPoints(result.gift.amount)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      // Only a lost answer is retried with the same id.
      if (failure is ServerFailure) _clientIds.remove(amount);
      if (failure.code == ErrorCode.insufficientCoins) {
        reloadCoins(ref);
        KSnack.error(context, l10n.cpGiftNotEnough);
      } else {
        if (failure.code == ErrorCode.cpNotPaired) refreshCp(ref);
        KSnack.error(context, failureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final own = widget.couple.own;
    final config = ref.watch(cpConfigProvider);
    final coins = own ? ref.watch(liveCoinsProvider).value : null;
    final cards = switch (config) {
      AsyncValue(value: final CpConfig c) => SizedBox(
        height: 132 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.4),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (code, amount, name) in [
              if (c.gifts.isNotEmpty)
                for (final g in c.gifts) (g.code, g.amount, g.name)
              else
                for (final a in c.giftAmounts) (null, a, l10n.bondsCoins(a)),
            ])
              _GiftCard(
                key: CpSpaceScreen.giftKey(amount),
                art: CpSpaceAssets.giftArt(code),
                name: name,
                amount: amount,
                sending: _sending == amount,
                onTap: !own || _sending != null
                    ? null
                    : () => unawaited(_send(amount, name)),
              ),
          ],
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.cpSpaceLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(cpConfigProvider),
        embedded: true,
      ),
      _ => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    return CpSectionCard(
      key: CpSpaceScreen.giftsKey,
      title: l10n.cpSpaceActionGifts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cards,
          const SizedBox(height: KSpacing.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (coins != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      CpSpaceAssets.coin,
                      width: 18,
                      height: 18,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: KSpacing.xxs),
                    Flexible(
                      child: Text(
                        l10n.bondsBalance(l10n.bondsCoins(coins)),
                        style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              TextButton.icon(
                key: CpSpaceScreen.giftWallKey,
                style: TextButton.styleFrom(
                  foregroundColor: CpSpaceColors.accent,
                ),
                onPressed: () => unawaited(
                  showCpGiftWall(context, widget.couple.id, own: own),
                ),
                icon: Image.asset(
                  CpSpaceAssets.privilegeIcon(CpPrivilegeCode.giftWall),
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                ),
                label: Text(l10n.cpSpaceGiftWall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const new({
    required this.art,
    required this.name,
    required this.amount,
    required this.sending,
    required this.onTap,
    super.key,
  });

  final String art;
  final String name;
  final int amount;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
      child: Semantics(
        button: onTap != null,
        label: '$name, ${context.l10n.bondsCoins(amount)}',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(KRadius.lg),
            onTap: onTap,
            child: Ink(
              width: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, CpSpaceColors.chip],
                ),
                borderRadius: BorderRadius.circular(KRadius.lg),
                border: Border.all(color: CpSpaceColors.progressTrack),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xs),
                child: Column(
                  children: [
                    Expanded(
                      child: sending
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Image.asset(art, excludeFromSemantics: true),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(
                          color: CpSpaceColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          CpSpaceAssets.coin,
                          width: 12,
                          height: 12,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          KFormat.grouped(amount),
                          style: t.caption.copyWith(
                            color: CpSpaceColors.inkSoft,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A draggable sheet on the page pink with [title].
Future<void> _sheet(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, ScrollController) body,
}) => _modal(
  context: context,
  isScrollControlled: true,
  backgroundColor: CpSpaceColors.page,
  builder: (sheet) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (context, scroll) => SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.sm,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.title.copyWith(
                color: CpSpaceColors.accentDeep,
              ),
            ),
          ),
          Expanded(child: body(context, scroll)),
        ],
      ),
    ),
  ),
);

/// The couple's gift wall (newest first, with totals). Another couple's
/// wall before it unlocked `GIFT_WALL` says so (403 `CP_PRIVILEGE_LOCKED`).
Future<void> showCpGiftWall(
  BuildContext context,
  String coupleId, {
  required bool own,
}) => _sheet(
  context,
  title: context.l10n.cpSpaceGiftWall,
  body: (context, scroll) => Consumer(
    builder: (context, ref, _) {
      final l10n = context.l10n;
      final t = context.textStyles;
      final locale = Localizations.localeOf(context).toLanguageTag();
      final provider = cpGiftWallProvider(coupleId);
      final notifier = ref.read(provider.notifier);
      return switch (ref.watch(provider)) {
        AsyncValue(
          value: FeedItems(:final items, :final hasMore, :final loadMoreError),
        ) =>
          ListView(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            children: [
              if (notifier.totals case final totals?)
                Text(
                  l10n.cpSpaceGiftWallTotals(
                    KFormat.grouped(totals.gifts),
                    KFormat.grouped(totals.coins),
                  ),
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(color: CpSpaceColors.ink),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: Text(
                    l10n.cpSpaceGiftWallEmpty,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: CpSpaceColors.inkSoft),
                  ),
                ),
              for (final e in items)
                ListTile(
                  leading: Image.asset(
                    CpSpaceAssets.giftArt(e.giftCode),
                    width: 44,
                    height: 44,
                    excludeFromSemantics: true,
                  ),
                  title: Text(
                    l10n.cpSpaceGiftWallEntry(
                      KFormat.bidiIsolate(_nameOf(e.sender)),
                      KFormat.bidiIsolate(_nameOf(e.receiver)),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: CpSpaceColors.ink),
                  ),
                  subtitle: Text(
                    KFormat.date(e.createdAt.toLocal(), locale),
                    style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
                  ),
                  trailing: Text(
                    l10n.bondsCoins(e.amount),
                    style: t.label.copyWith(color: CpSpaceColors.accent),
                  ),
                ),
              if (hasMore && loadMoreError == null)
                PostGridLoadMore(
                  key: ValueKey(items.length),
                  onVisible: () => unawaited(notifier.loadMore()),
                )
              else if (hasMore)
                Center(
                  child: TextButton(
                    onPressed: () => unawaited(notifier.loadMore()),
                    child: Text(l10n.actionRetry),
                  ),
                ),
            ],
          ),
        AsyncValue(:final error?, isLoading: false)
            when isErrorCode(error, ErrorCode.cpPrivilegeLocked) =>
          ListView(
            controller: scroll,
            children: [
              KEmptyState(
                icon: Icons.lock_rounded,
                iconColor: CpSpaceColors.accent,
                title: l10n.cpSpaceLocked,
                message: l10n.cpSpaceGiftWallLocked(
                  CpPrivilegeCode.giftWall.unlockLevel,
                ),
                compact: true,
              ),
            ],
          ),
        AsyncValue(:final error?, isLoading: false)
            when isErrorCode(error, ErrorCode.notFound) =>
          ListView(
            controller: scroll,
            children: [
              KEmptyState(
                icon: Icons.heart_broken_outlined,
                iconColor: CpSpaceColors.accent,
                title: l10n.cpSpaceGoneTitle,
                message: l10n.cpSpaceGoneBody,
                compact: true,
              ),
            ],
          ),
        AsyncValue(:final error?, isLoading: false) => ListView(
          controller: scroll,
          children: [
            FailureErrorState(
              title: l10n.cpSpaceGiftWallError,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(provider),
              compact: true,
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    },
  ),
);

/// The couples ranking: this week and all time, the caller's couple at the
/// bottom; a couple opens its page.
Future<void> showCpRanking(BuildContext context) => _sheet(
  context,
  title: context.l10n.cpSpaceRankingTitle,
  body: (context, scroll) => _RankingBody(scroll: scroll),
);

class _RankingBody extends ConsumerStatefulWidget {
  const new({required this.scroll});

  final ScrollController scroll;

  @override
  ConsumerState<_RankingBody> createState() => _RankingBodyState();
}

class _RankingBodyState extends ConsumerState<_RankingBody> {
  CpRankingPeriod _period = CpRankingPeriod.week;

  void _open(String coupleId) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(AppRoutes.cpCouple(coupleId)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final provider = cpRankingsProvider(_period);
    final notifier = ref.read(provider.notifier);
    final state = ref.watch(provider);
    final list = switch (state) {
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        ListView(
          controller: widget.scroll,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Text(
                  l10n.cpSpaceRankingEmpty,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: CpSpaceColors.inkSoft),
                ),
              ),
            for (final e in items)
              ListTile(
                key: CpSpaceScreen.rankingKey(e.coupleId),
                onTap: () => _open(e.coupleId),
                leading: SizedBox(
                  width: 92,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${e.rank}',
                          textAlign: TextAlign.center,
                          style: t.bodyStrong.copyWith(
                            color: e.rank <= 3
                                ? CpSpaceColors.accent
                                : CpSpaceColors.inkSoft,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        height: 40,
                        child: Stack(
                          children: [
                            for (final (i, u) in e.partners.indexed.take(2))
                              PositionedDirectional(
                                start: i * 24.0,
                                child: KAvatar(
                                  name: _nameOf(u),
                                  imageUrl: u.avatarUrl,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  l10n.cpSpacePair(
                    KFormat.bidiIsolate(_nameOf(e.partners.first)),
                    KFormat.bidiIsolate(_nameOf(e.partners.last)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: CpSpaceColors.ink),
                ),
                subtitle: Text(
                  '${l10n.cpSpaceLevel(e.level)} · ${e.levelName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
                ),
                trailing: Text(
                  formatBondPoints(e.points),
                  style: t.label.copyWith(color: CpSpaceColors.accent),
                ),
              ),
            if (hasMore && loadMoreError == null)
              PostGridLoadMore(
                key: ValueKey(items.length),
                onVisible: () => unawaited(notifier.loadMore()),
              )
            else if (hasMore)
              Center(
                child: TextButton(
                  onPressed: () => unawaited(notifier.loadMore()),
                  child: Text(l10n.actionRetry),
                ),
              ),
          ],
        ),
      AsyncValue(:final error?, isLoading: false) => ListView(
        controller: widget.scroll,
        children: [
          FailureErrorState(
            title: l10n.cpSpaceRankingError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(provider),
            compact: true,
          ),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    final me = state.hasValue ? notifier.me : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: KSpacing.sm,
            children: [
              for (final (period, key, label) in [
                (
                  CpRankingPeriod.week,
                  CpSpaceScreen.rankingWeekKey,
                  l10n.cpSpaceRankingWeek,
                ),
                (
                  CpRankingPeriod.all,
                  CpSpaceScreen.rankingAllKey,
                  l10n.cpSpaceRankingAll,
                ),
              ])
                ChoiceChip(
                  key: key,
                  label: Text(label),
                  selected: _period == period,
                  selectedColor: CpSpaceColors.accent,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _period == period ? Colors.white : CpSpaceColors.ink,
                  ),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _period = period),
                ),
            ],
          ),
        ),
        Expanded(child: list),
        if (me != null)
          Container(
            key: CpSpaceScreen.rankingMeKey,
            margin: const EdgeInsets.all(KSpacing.sm),
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(KRadius.lg),
              border: Border.all(color: CpSpaceColors.progressTrack),
            ),
            child: Row(
              children: [
                Image.asset(
                  CpSpaceAssets.heart,
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(switch (me.rank) {
                    final int rank => l10n.cpSpaceRankingMe('$rank'),
                    null => l10n.cpSpaceRankingMeUnranked,
                  }, style: t.bodyStrong.copyWith(color: CpSpaceColors.ink)),
                ),
                Text(
                  formatBondPoints(me.points),
                  style: t.label.copyWith(color: CpSpaceColors.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Keeps at most [max] Unicode code points (the server counts code points,
/// §10.24), so an emoji never gets cut in half.
class _CodePointLimit extends TextInputFormatter {
  const new(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    // Cut by whole characters until the code points fit.
    var chars = newValue.text.characters;
    while (chars.string.runes.length > max) {
      chars = chars.skipLast(1);
    }
    final text = chars.string;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// The confession wall: your couple writes (to the partner) and deletes;
/// anyone reads and reports (not their own).
class _ConfessionsCard extends ConsumerStatefulWidget {
  const new({required this.couple});

  final _Couple couple;

  @override
  ConsumerState<_ConfessionsCard> createState() => _ConfessionsCardState();
}

class _ConfessionsCardState extends ConsumerState<_ConfessionsCard> {
  final _text = TextEditingController();
  String? _clientId;
  bool _sending = false;

  _Couple get couple => widget.couple;
  String? get _wallId => couple.own ? null : couple.id;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    // The same id for a retry of this text: never written twice.
    final clientId = _clientId ??= newClientId();
    try {
      final c = await ref
          .read(cpRepositoryProvider)
          .createConfession(text: text, clientId: clientId);
      _clientId = null;
      if (!mounted) return;
      _text.clear();
      FocusScope.of(context).unfocus();
      ref.read(cpConfessionsProvider(null).notifier).prepend(c);
      KSnack.success(context, l10n.cpSpaceConfessionSent);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      if (failure is ServerFailure) _clientId = null;
      if (failure.code == ErrorCode.cpNotPaired) refreshCp(ref);
      KSnack.error(context, failureMessage(l10n, failure));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CpConfession c) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.cpSpaceConfessionDeleteTitle,
      confirm: l10n.cpSpaceConfessionDelete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(cpRepositoryProvider).deleteConfession(c.id);
      if (!mounted) return;
      ref.read(cpConfessionsProvider(_wallId).notifier).remove(c.id);
      KSnack.success(context, l10n.cpSpaceConfessionDeleted);
    } on Object catch (e) {
      if (!mounted) return;
      if (isErrorCode(e, ErrorCode.notFound)) {
        ref.read(cpConfessionsProvider(_wallId).notifier).remove(c.id);
      }
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  Future<void> _report(CpConfession c) async {
    final l10n = context.l10n;
    final reason = await pickReportReason(
      context,
      l10n.cpSpaceConfessionReportTitle,
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(cpRepositoryProvider).reportConfession(c.id, reason);
      if (mounted) KSnack.success(context, l10n.feedPostReported);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final me = ref.watch(currentUserProvider);
    final provider = cpConfessionsProvider(_wallId);
    final notifier = ref.read(provider.notifier);
    final count = _text.text.runes.length;
    final children = <Widget>[
      if (couple.own)
        Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: CpSpaceScreen.confessionFieldKey,
                  controller: _text,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => unawaited(_send()),
                  inputFormatters: [
                    // One line (the live chat rule): no line breaks.
                    FilteringTextInputFormatter.deny(RegExp('[\r\n]')),
                    const _CodePointLimit(cpConfessionMaxCodePoints),
                  ],
                  style: t.body.copyWith(color: CpSpaceColors.ink),
                  cursorColor: CpSpaceColors.accent,
                  decoration: InputDecoration(
                    hintText: l10n.cpSpaceConfessionHint(
                      KFormat.bidiIsolate(couple.second.name),
                    ),
                    hintStyle: t.body.copyWith(color: CpSpaceColors.inkSoft),
                    counterText: '$count/$cpConfessionMaxCodePoints',
                    counterStyle: t.caption.copyWith(
                      color: CpSpaceColors.inkSoft,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      borderSide: const BorderSide(
                        color: CpSpaceColors.progressTrack,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      borderSide: const BorderSide(
                        color: CpSpaceColors.progressTrack,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      borderSide: const BorderSide(
                        color: CpSpaceColors.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: _sending
                    ? const SizedBox.square(
                        dimension: 40,
                        child: Padding(
                          padding: EdgeInsets.all(KSpacing.sm),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filled(
                        key: CpSpaceScreen.confessionSendKey,
                        tooltip: l10n.cpSpaceConfessionSend,
                        style: IconButton.styleFrom(
                          backgroundColor: CpSpaceColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: CpSpaceColors.progressTrack,
                        ),
                        onPressed: _text.text.trim().isEmpty
                            ? null
                            : () => unawaited(_send()),
                        icon: const Icon(Icons.send_rounded),
                      ),
              ),
            ],
          ),
        ),
      ...switch (ref.watch(provider)) {
        AsyncValue(
          value: FeedItems(:final items, :final hasMore, :final loadMoreError),
        ) =>
          [
            if (items.isEmpty) _emptyWall(context),
            for (final c in items)
              _ConfessionTile(
                confession: c,
                onDelete: couple.own ? () => unawaited(_delete(c)) : null,
                onReport: c.author.id == me?.id
                    ? null
                    : () => unawaited(_report(c)),
              ),
            if (hasMore && loadMoreError == null)
              PostGridLoadMore(
                key: ValueKey(items.length),
                onVisible: () => unawaited(notifier.loadMore()),
              )
            else if (hasMore)
              Center(
                child: TextButton(
                  onPressed: () => unawaited(notifier.loadMore()),
                  child: Text(l10n.actionRetry),
                ),
              ),
          ],
        AsyncValue(:final error?, isLoading: false) => [
          FailureErrorState(
            title: l10n.cpSpaceConfessionsError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(provider),
            embedded: true,
          ),
        ],
        _ => [
          const Padding(
            padding: EdgeInsets.all(KSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      },
    ];
    return CpSectionCard(
      key: CpSpaceScreen.confessionsKey,
      title: l10n.cpSpaceConfessionsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _emptyWall(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
      child: Column(
        children: [
          Image.asset(
            CpSpaceAssets.heart,
            width: 56,
            height: 56,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            couple.own
                ? l10n.cpSpaceConfessionsEmpty
                : l10n.cpSpaceConfessionsEmptyPublic,
            textAlign: TextAlign.center,
            style: context.textStyles.body.copyWith(
              color: CpSpaceColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfessionTile extends StatelessWidget {
  const new({
    required this.confession,
    required this.onDelete,
    required this.onReport,
  });

  final CpConfession confession;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final c = confession;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when =
        KFormat.relative(c.createdAt, DateTime.now(), l10n, locale) ??
        l10n.feedPostJustNow;
    return Container(
      key: CpSpaceScreen.confessionKey(c.id),
      margin: const EdgeInsets.only(top: KSpacing.sm),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.sm,
        KSpacing.sm,
        0,
        KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: CpSpaceColors.progressTrack),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KAvatar(
            name: _nameOf(c.author),
            imageUrl: c.author.avatarUrl,
            size: 36,
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cpSpaceConfessionTo(
                    KFormat.bidiIsolate(_nameOf(c.author)),
                    KFormat.bidiIsolate(_nameOf(c.recipient)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(color: CpSpaceColors.accentDeep),
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(c.text, style: t.body.copyWith(color: CpSpaceColors.ink)),
                Text(
                  when,
                  style: t.caption.copyWith(color: CpSpaceColors.inkSoft),
                ),
              ],
            ),
          ),
          if (onDelete != null || onReport != null)
            PopupMenuButton<VoidCallback>(
              key: CpSpaceScreen.confessionMenuKey(c.id),
              tooltip: l10n.cpSpaceConfessionMenu,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: CpSpaceColors.inkSoft,
              ),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                if (onDelete case final delete?)
                  PopupMenuItem(
                    value: delete,
                    child: Text(l10n.cpSpaceConfessionDelete),
                  ),
                if (onReport case final report?)
                  PopupMenuItem(
                    value: report,
                    child: Text(l10n.cpSpaceConfessionReport),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
