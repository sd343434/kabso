import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/tasks` (D166): the Task Center «مركز المهام» in the layout of the
/// owner's reference — two tabs (daily tasks, weekly host tasks), the level
/// card, the 7-day check-in strip and the task rewards, each with «اذهب»,
/// «استلام» or «تم». Progress and rewards come from the server
/// (`GET /me/tasks`); nothing is counted on the phone.
class TaskCenterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const levelCardKey = Key('tasks.level');
  static const checkInKey = Key('tasks.checkIn');
  static const checkInButtonKey = Key('tasks.checkIn.button');
  static const capKey = Key('tasks.cap');
  static const weeklyEmptyKey = Key('tasks.weekly.empty');

  static Key taskKey(String code) => Key('tasks.task.$code');
  static Key actionKey(String code) => Key('tasks.action.$code');
  static Key dayKey(int index) => Key('tasks.day.$index');

  @override
  ConsumerState<TaskCenterScreen> createState() => _TaskCenterScreenState();
}

class _TaskCenterScreenState extends ConsumerState<TaskCenterScreen> {
  int _tab = 0;
  final Set<String> _busy = {};

  Future<void> _refresh() async {
    ref
      ..invalidate(myTasksProvider)
      ..invalidate(myLevelsProvider);
    try {
      await ref.read(myTasksProvider.future);
    } on Object {
      // The page shows the failure with a retry.
    }
  }

  Future<void> _run(String id, Future<ProgramPayout> Function() call) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    final l10n = context.l10n;
    try {
      final payout = await call();
      if (!mounted) return;
      KSnack.success(
        context,
        payout.paidCoins > 0
            ? l10n.tasksRewardReceived(KFormat.grouped(payout.paidCoins))
            : l10n.tasksNoCoinsCap,
      );
      ref.invalidate(liveCoinsProvider);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      final cap =
          failure is ServerFailure &&
          failure.rawCode == 'TASK_DAILY_CAP_REACHED';
      KSnack.error(
        context,
        cap ? l10n.tasksCapReached : failureMessage(l10n, failure),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
      ref.invalidate(myTasksProvider);
    }
  }

  void _go(TaskMetric metric) {
    switch (metric) {
      case TaskMetric.follows:
        unawaited(context.push(AppRoutes.discover));
      case TaskMetric.hostLiveMinutes || TaskMetric.hostGiftCoins:
        unawaited(context.push(AppRoutes.goLive));
      case TaskMetric.watchLives ||
          TaskMetric.liveChatMessages ||
          TaskMetric.giftSends ||
          TaskMetric.other:
        context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final tasks = ref.watch(myTasksProvider);
    final repo = ref.read(programsRepositoryProvider);

    final body = switch (tasks) {
      AsyncValue(:final value?) => [
        const _LevelCard(),
        if (_tab == 0) ...[
          _CheckInCard(
            state: value.checkIn,
            busy: _busy.contains('check-in'),
            onCheckIn: () => unawaited(_run('check-in', repo.checkIn)),
          ),
          Padding(
            key: TaskCenterScreen.capKey,
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: Text(
              l10n.tasksDailyCap(
                '${value.dailyEarnedCoins}',
                '${value.dailyCapCoins}',
              ),
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
        ],
        _taskList(
          _tab == 0 ? value.daily : value.weekly,
          weekly: _tab == 1,
          onClaim: (code) => unawaited(_run(code, () => repo.claim(code))),
        ),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.tasksLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myTasksProvider),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.meHubTaskCenter),
      ),
      body: Column(
        children: [
          KPrimaryTabs(
            labels: [l10n.tasksTabDaily, l10n.tasksTabWeekly],
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  KSpacing.sm,
                  KSpacing.lg,
                  KSpacing.xl,
                ),
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskList(
    List<ProgramTask> list, {
    required bool weekly,
    required ValueChanged<String> onClaim,
  }) {
    final l10n = context.l10n;
    if (list.isEmpty) {
      return KEmptyState(
        key: weekly ? TaskCenterScreen.weeklyEmptyKey : null,
        icon: weekly ? Icons.videocam_rounded : Icons.task_alt_rounded,
        title: weekly ? l10n.tasksWeeklyEmpty : l10n.tasksEmpty,
        message: weekly ? l10n.tasksWeeklyEmptyBody : l10n.tasksEmptyBody,
        compact: true,
      );
    }
    return ProgramSection(
      title: weekly ? l10n.tasksWeeklyTitle : l10n.tasksRewardsTitle,
      subtitle: weekly ? l10n.tasksWeeklyHint : null,
      child: Column(
        children: [
          for (final t in list)
            _TaskRow(
              task: t,
              busy: _busy.contains(t.code),
              onGo: () => _go(t.metric),
              onClaim: () => onClaim(t.code),
            ),
        ],
      ),
    );
  }
}

/// The caller's level, from the level systems (CP-005): the support level
/// when it is active, else the first active one. Tap → levels.
class _LevelCard extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final levels = ref.watch(myLevelsProvider).value ?? const [];
    final active = [
      for (final l in levels)
        if (l.available) l,
    ];
    final level =
        active.where((l) => l.category == LevelCategory.support).firstOrNull ??
        active.firstOrNull;
    final brief = level?.level;
    final tier = brief == null
        ? 1
        : KLevelArt.tier(brief.levelNumber, iconKey: brief.iconKey);
    void open() => unawaited(context.push(AppRoutes.levels));
    final label = level == null
        ? l10n.tasksLevelNone
        : [
            level.name,
            if (brief != null) l10n.levelsLevelNumber(brief.levelNumber),
            l10n.tasksLevelPoints(formatPoints(level.points)),
          ].join('، ');
    return Semantics(
      key: TaskCenterScreen.levelCardKey,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: KSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Color.alphaBlend(
                KBrandColors.gold.withValues(alpha: 0.22),
                p.surfaceRaised,
              ),
              p.surfaceRaised,
            ],
          ),
          borderRadius: BorderRadius.circular(KRadius.lg),
          border: Border.all(color: p.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(KRadius.lg),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Row(
                children: [
                  if (level != null && brief != null)
                    KLevelEmblem(category: level.category, tier: tier, size: 64)
                  else
                    const ProgramIconTile(
                      icon: Icons.diamond_rounded,
                      hue: KBrandColors.red500,
                      size: 64,
                    ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brief?.name ?? level?.name ?? l10n.meHubLevels,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.title.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xs),
                        if (level != null) ...[
                          KLevelProgressBar(
                            percent: level.progressPercent ?? 0,
                            color: KLevelArt.gem(tier),
                          ),
                          const SizedBox(height: KSpacing.xs),
                          Text(
                            l10n.tasksLevelPoints(formatPoints(level.points)),
                            style: t.caption.copyWith(
                              color: programGold(context),
                            ),
                          ),
                        ] else
                          Text(
                            l10n.tasksLevelNone,
                            style: t.caption.copyWith(color: p.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 7-day check-in strip «تسجيل الدخول اليومي»: today and the next six
/// days (the 7th of the cycle carries the bonus) and the check-in button.
class _CheckInCard extends StatelessWidget {
  const new({required this.state, required this.busy, required this.onCheckIn});

  final CheckInState state;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final toBonus = state.daysToBonus;
    return KeyedSubtree(
      key: TaskCenterScreen.checkInKey,
      child: ProgramSection(
        title: l10n.tasksCheckInTitle,
        subtitle: toBonus <= 0
            ? l10n.tasksCheckInBonusToday('${state.bonusCoins}')
            : l10n.tasksCheckInToBonus('$toBonus', '${state.bonusCoins}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (i, day) in state.days.indexed)
                  Expanded(
                    child: _DaySlot(index: i, day: day, state: state),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tasksStreak('${state.streak}'),
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                ProgramPillButton(
                  key: TaskCenterScreen.checkInButtonKey,
                  label: state.checkedInToday
                      ? l10n.tasksActionDone
                      : l10n.tasksCheckInAction,
                  loading: busy,
                  onPressed: state.checkedInToday ? null : onCheckIn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySlot extends StatelessWidget {
  const new({required this.index, required this.day, required this.state});

  final int index;
  final CheckInDay day;
  final CheckInState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final bonus = day.cycleDay == state.cycleDays;
    final hue = bonus ? KBrandColors.gold : p.primary;
    final label = day.today
        ? l10n.tasksToday
        : '${day.date.month}.${day.date.day}';
    return Semantics(
      key: TaskCenterScreen.dayKey(index),
      label: [
        label,
        l10n.meHubCoins('${day.rewardCoins}'),
        if (day.checkedIn) l10n.tasksActionDone,
      ].join('، '),
      excludeSemantics: true,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: day.checkedIn
                  ? hue.withValues(alpha: 0.18)
                  : Color.alphaBlend(hue.withValues(alpha: 0.10), p.surface),
              border: day.today ? Border.all(color: hue, width: 2) : null,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                day.checkedIn
                    ? Icons.check_rounded
                    : bonus
                    ? Icons.redeem_rounded
                    : Icons.card_giftcard_rounded,
                size: 20,
                color: hue,
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textDirection: day.today ? null : TextDirection.ltr,
              style: context.textStyles.caption.copyWith(
                color: day.today ? p.textPrimary : p.textTertiary,
                fontWeight: day.today ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+${day.rewardCoins}',
              maxLines: 1,
              textDirection: TextDirection.ltr,
              style: context.textStyles.caption.copyWith(
                color: programGold(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One task: icon tile, «name (x/y)», the coin chip and the action.
class _TaskRow extends StatelessWidget {
  const new({
    required this.task,
    required this.busy,
    required this.onGo,
    required this.onClaim,
  });

  final ProgramTask task;
  final bool busy;
  final VoidCallback onGo;
  final VoidCallback onClaim;

  static (IconData, Color) _look(TaskMetric metric) => switch (metric) {
    TaskMetric.watchLives => (Icons.videocam_rounded, const Color(0xFF14B8A6)),
    TaskMetric.follows => (Icons.person_add_rounded, const Color(0xFFFF3B6B)),
    TaskMetric.liveChatMessages => (
      Icons.chat_bubble_rounded,
      const Color(0xFF4DA3FF),
    ),
    TaskMetric.giftSends => (Icons.redeem_rounded, const Color(0xFFE0A21B)),
    TaskMetric.hostLiveMinutes => (Icons.live_tv_rounded, KBrandColors.red500),
    TaskMetric.hostGiftCoins => (
      Icons.volunteer_activism_rounded,
      const Color(0xFFF5A623),
    ),
    TaskMetric.other => (Icons.task_alt_rounded, const Color(0xFF14B8A6)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final (icon, hue) = _look(task.metric);
    final title = '${task.name} (${task.progress}/${task.target})';
    final Widget action;
    if (task.claimed) {
      action = ProgramPillButton(
        key: TaskCenterScreen.actionKey(task.code),
        label: l10n.tasksActionDone,
        onPressed: null,
      );
    } else if (task.completed) {
      action = ProgramPillButton(
        key: TaskCenterScreen.actionKey(task.code),
        label: l10n.tasksActionClaim,
        loading: busy,
        onPressed: onClaim,
      );
    } else {
      action = ProgramPillButton(
        key: TaskCenterScreen.actionKey(task.code),
        label: l10n.tasksActionGo,
        filled: false,
        onPressed: onGo,
      );
    }
    return Padding(
      key: TaskCenterScreen.taskKey(task.code),
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: Row(
        children: [
          ProgramIconTile(icon: icon, hue: hue),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xxs),
                Semantics(
                  label: l10n.meHubCoins('${task.rewardCoins}'),
                  excludeSemantics: true,
                  child: CoinAmount(
                    task.claimedCoins ?? task.rewardCoins,
                    prefix: '+',
                    style: t.label.copyWith(color: programGold(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          action,
        ],
      ),
    );
  }
}
