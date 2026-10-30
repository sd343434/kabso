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
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/tasks` (D166, D176, D184): the Task Center «مركز المهام» in the layout
/// of the owner's reference (D176) with Kabso's colours and icons — only the
/// active tasks (D184, owner: the «مهام الماس» tab and the tab bar are gone),
/// a warm page, the sign-in rewards card (a 7-day strip, today first, the 7th
/// day the bonus, and the check-in pill; it pays coins), the task rewards
/// card (today's tasks from the daily pool, each «اذهب» → «استلم» → «تم»), the
/// weekly host tasks for hosts and the team's banners at the bottom (hidden
/// when none). Progress, targets and rewards come from the server
/// (`GET /me/tasks`); task rewards are cherries since v1.53-social (D184:
/// the cherry icon and «+N» on each row and in the claim feedback).
class TaskCenterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const checkInKey = Key('tasks.checkIn');
  static const checkInButtonKey = Key('tasks.checkIn.button');
  static const calendarKey = Key('tasks.checkIn.calendar');
  static const calendarSheetKey = Key('tasks.checkIn.sheet');
  static const capKey = Key('tasks.cap');
  static const rewardsKey = Key('tasks.rewards');
  static const weeklyKey = Key('tasks.weekly');
  static const emptyKey = Key('tasks.empty');

  /// D184: the claim feedback's «+N» cherries.
  static const claimFeedbackKey = Key('tasks.claimFeedback');
  static const bannerKey = Key('tasks.banner');

  static Key taskKey(String code) => Key('tasks.task.$code');

  /// D184: a task row's «+N» cherries.
  static Key rewardAmountKey(String code) => Key('tasks.reward.$code');
  static Key actionKey(String code) => Key('tasks.action.$code');
  static Key dayKey(int index) => Key('tasks.day.$index');

  /// The reference's measured geometry (D176 spec, 393 × 852 lp).
  static const double pagePadding = 12;
  static const double cardPadding = 14;
  static const double cardRadius = 17;
  static const double rowPitch = 62;
  static const double iconTile = 37;

  /// D184: one width for every pill (the check-in's too), so the rows'
  /// actions line up; a longer label (English «Check in») grows it.
  static const Size pill = Size(76, 28);

  @override
  ConsumerState<TaskCenterScreen> createState() => _TaskCenterScreenState();
}

class _TaskCenterScreenState extends ConsumerState<TaskCenterScreen> {
  final Set<String> _busy = {};

  Future<void> _refresh() async {
    ref
      ..invalidate(myTasksProvider)
      ..invalidate(taskBannersProvider);
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
      if (payout.paidCherries > 0) {
        // D184: task rewards are cherries — the cherry icon and «+N».
        KSnack.success(
          context,
          l10n.tasksRewardReceivedCherries(
            KFormat.grouped(payout.paidCherries),
          ),
          leading: TaskCherryAmount(
            payout.paidCherries,
            key: TaskCenterScreen.claimFeedbackKey,
            size: 18,
          ),
        );
        ref
          ..invalidate(myCherriesProvider)
          ..invalidate(cherryLedgerProvider);
      } else {
        KSnack.success(
          context,
          payout.paidCoins > 0
              ? l10n.tasksRewardReceived(KFormat.grouped(payout.paidCoins))
              : l10n.tasksNoCoinsCap,
        );
      }
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

  /// «اذهب»: where the task's action is done.
  void _go(TaskMetric metric) {
    final route = switch (metric) {
      TaskMetric.follows || TaskMetric.postComments => AppRoutes.discover,
      TaskMetric.audioRooms => AppRoutes.voiceRooms,
      TaskMetric.posts => AppRoutes.create,
      TaskMetric.reels => AppRoutes.newReel,
      TaskMetric.stories => AppRoutes.newStory,
      TaskMetric.dmFriends || TaskMetric.dmVoiceMessages => AppRoutes.messages,
      TaskMetric.hostLiveMinutes ||
      TaskMetric.hostGiftCoins ||
      TaskMetric.hostGiftsReceived ||
      TaskMetric.hostGuests => AppRoutes.goLive,
      TaskMetric.watchLives ||
      TaskMetric.watchMinutes ||
      TaskMetric.liveChatMessages ||
      TaskMetric.liveTaps ||
      TaskMetric.giftSends ||
      TaskMetric.newHostGifts ||
      TaskMetric.other => null,
    };
    if (route == null) {
      context.go(AppRoutes.home);
    } else {
      unawaited(context.push(route));
    }
  }

  void _openCalendar(CheckInState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CheckInCalendarSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final tasks = ref.watch(myTasksProvider);
    final repo = ref.read(programsRepositoryProvider);

    // D184: the cherry cap (an older server: the coin cap).
    String capCaption(MyTasks v) => v.dailyCapCherries > 0
        ? l10n.tasksDailyCap(
            KFormat.grouped(v.dailyEarnedCherries),
            KFormat.grouped(v.dailyCapCherries),
          )
        : l10n.tasksDailyCap(
            KFormat.grouped(v.dailyEarnedCoins),
            KFormat.grouped(v.dailyCapCoins),
          );

    final body = switch (tasks) {
      AsyncValue(:final value?) => <Widget>[
        _CheckInCard(
          state: value.checkIn,
          busy: _busy.contains('check-in'),
          onCheckIn: () => unawaited(_run('check-in', repo.checkIn)),
          onCalendar: () => _openCalendar(value.checkIn),
        ),
        _RewardsCard(
          key: TaskCenterScreen.rewardsKey,
          title: l10n.tasksRewardsTitle,
          caption: capCaption(value),
          captionKey: TaskCenterScreen.capKey,
          tasks: value.daily,
          busy: _busy,
          onGo: _go,
          onClaim: (code) => unawaited(_run(code, () => repo.claim(code))),
        ),
        if (value.weekly.isNotEmpty)
          _RewardsCard(
            key: TaskCenterScreen.weeklyKey,
            title: l10n.tasksWeeklyTitle,
            caption: l10n.tasksWeeklyHint,
            tasks: value.weekly,
            busy: _busy,
            onGo: _go,
            onClaim: (code) => unawaited(_run(code, () => repo.claim(code))),
          ),
        const _TaskBanners(),
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

    // D184 (owner): the page follows the theme like the other Me-hub pages
    // (the wallet's surface page with raised cards) — no fixed warm beige —
    // and the header is the standard centred app bar.
    return Scaffold(
      backgroundColor: p.surface,
      appBar: KAppBar(
        backgroundColor: p.surface,
        centerTitle: true,
        title: Text(l10n.meHubTaskCenter),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            TaskCenterScreen.pagePadding,
            KSpacing.xs,
            TaskCenterScreen.pagePadding,
            KSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          children: body,
        ),
      ),
    );
  }
}

/// A card on the theme's raised surface (D184: no fixed warm wash; light
/// and dark follow the palette).
class _TaskCard extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(TaskCenterScreen.cardRadius),
      ),
      child: child,
    );
  }
}

/// The card title: a short gold bar, the words, an optional trailing link.
class _CardTitle extends StatelessWidget {
  const new({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trailing = this.trailing;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: KBrandColors.gold,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.title.copyWith(
                color: p.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A small stadium pill (26 lp, the reference's) inside a 44 lp tap area.
class TaskPill extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.kind = TaskPillKind.go,
    this.loading = false,
    this.minWidth = 76,
  });

  final String label;
  final VoidCallback? onPressed;
  final TaskPillKind kind;
  final bool loading;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !loading;
    final (Gradient? fill, Color flat, Color fg) = switch (kind) {
      TaskPillKind.go => (
        const LinearGradient(
          colors: [KBrandColors.red400, KBrandColors.red500],
        ),
        p.primary,
        p.onPrimary,
      ),
      TaskPillKind.claim => (
        const LinearGradient(colors: [Color(0xFFFFD66B), KBrandColors.gold]),
        KBrandColors.gold,
        const Color(0xFF4A3300),
      ),
      TaskPillKind.done => (null, p.surfaceOverlay, p.textTertiary),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: BoxConstraints(
                minWidth: minWidth,
                minHeight: TaskCenterScreen.pill.height,
              ),
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                gradient: fill,
                color: fill == null ? flat : null,
              ),
              child: loading
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      style: context.textStyles.label.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum TaskPillKind { go, claim, done }

/// «مكافآت تسجيل الدخول»: the line to the bonus, today and the next six days
/// (the 7th of the cycle is the bonus) and the check-in pill.
class _CheckInCard extends StatelessWidget {
  const new({
    required this.state,
    required this.busy,
    required this.onCheckIn,
    required this.onCalendar,
  });

  final CheckInState state;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final toBonus = state.daysToBonus;
    final line = toBonus <= 0
        ? l10n.tasksCheckInBonusToday('${state.bonusCoins}')
        : l10n.tasksCheckInMoreDays(toBonus);
    return KeyedSubtree(
      key: TaskCenterScreen.checkInKey,
      child: _TaskCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TaskCenterScreen.cardPadding,
            0,
            TaskCenterScreen.cardPadding,
            KSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The title row keeps a 44 lp tap target for «التقويم».
              SizedBox(
                height: 44,
                child: _CardTitle(
                  title: l10n.tasksCheckInTitle,
                  trailing: _CalendarLink(onTap: onCalendar),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              // D184: the seven days share the card's full width (no day cut
              // at the edge); the line and the pill sit under them.
              _DayStrip(state: state),
              const SizedBox(height: KSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _HighlightedLine(text: line, highlight: '$toBonus'),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  TaskPill(
                    key: TaskCenterScreen.checkInButtonKey,
                    label: state.checkedInToday
                        ? l10n.tasksActionDone
                        : l10n.tasksCheckInAction,
                    kind: state.checkedInToday
                        ? TaskPillKind.done
                        : TaskPillKind.go,
                    loading: busy,
                    onPressed: state.checkedInToday ? null : onCheckIn,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey line with its number in gold (the reference's «2»).
class _HighlightedLine extends StatelessWidget {
  const new({required this.text, required this.highlight});

  final String text;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.textStyles.caption.copyWith(
      color: p.textSecondary,
      fontSize: 12.5,
    );
    final at = text.indexOf(highlight);
    if (at < 0 || highlight.isEmpty) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: highlight,
            style: TextStyle(
              color: programGold(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(at + highlight.length)),
        ],
      ),
      style: style,
    );
  }
}

class _CalendarLink extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = context.l10n.tasksCheckInCalendar;
    return Semantics(
      key: TaskCenterScreen.calendarKey,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyles.caption.copyWith(
                  color: p.textTertiary,
                  fontSize: 12.5,
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: p.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today and the next six days on a thin line, sharing the full width
/// (D184: nothing is cut at the edge; the labels shrink to fit).
class _DayStrip extends StatelessWidget {
  const new({required this.state});

  final CheckInState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = state.days.length;
    // The mark (26), a gap (3) and the date's line, which grows with the
    // text size.
    final height =
        29 +
        MediaQuery.textScalerOf(context).scale(11 * 1.2).ceilToDouble() +
        2;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = box.maxWidth / count;
          return Stack(
            children: [
              PositionedDirectional(
                start: slot / 2,
                end: slot / 2,
                top: 12,
                height: 2,
                child: ColoredBox(
                  color: Color.alphaBlend(
                    KBrandColors.gold.withValues(alpha: 0.22),
                    p.surfaceRaised,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, day) in state.days.indexed)
                    Expanded(
                      child: _DaySlot(index: i, day: day, state: state),
                    ),
                ],
              ),
            ],
          );
        },
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
    final label = day.today
        ? l10n.tasksToday
        : '${day.date.month}.${day.date.day}';
    final hue = ProgramHues.all[(index + 2) % ProgramHues.all.length];
    final Widget mark;
    if (day.checkedIn) {
      mark = DecoratedBox(
        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
        child: const SizedBox.square(
          dimension: 19,
          child: Icon(Icons.check_rounded, size: 14, color: Color(0xFFFFFFFF)),
        ),
      );
    } else if (bonus) {
      mark = const Icon(
        Icons.redeem_rounded,
        size: 26,
        color: KBrandColors.gold,
      );
    } else {
      mark = Icon(
        Icons.card_giftcard_rounded,
        size: 22,
        color: day.today ? p.primary : hue,
      );
    }
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
          SizedBox(height: 26, child: Center(child: mark)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textDirection: day.today ? null : TextDirection.ltr,
              style: context.textStyles.caption.copyWith(
                color: day.today ? p.textSecondary : p.textTertiary,
                fontSize: 11,
                fontWeight: day.today ? FontWeight.w600 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «مكافآت المهام» (and the weekly host tasks): a row per task.
class _RewardsCard extends StatelessWidget {
  const new({
    required this.title,
    required this.tasks,
    required this.busy,
    required this.onGo,
    required this.onClaim,
    super.key,
    this.caption,
    this.captionKey,
  });

  final String title;
  final String? caption;
  final Key? captionKey;
  final List<ProgramTask> tasks;
  final Set<String> busy;
  final ValueChanged<TaskMetric> onGo;
  final ValueChanged<String> onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final caption = this.caption;
    return _TaskCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TaskCenterScreen.cardPadding,
          KSpacing.md,
          TaskCenterScreen.cardPadding,
          KSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardTitle(
              title: title,
              trailing: caption == null
                  ? null
                  : Flexible(
                      child: Text(
                        caption,
                        key: captionKey,
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        style: context.textStyles.caption.copyWith(
                          color: p.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: KSpacing.xs),
            if (tasks.isEmpty)
              KEmptyState(
                key: TaskCenterScreen.emptyKey,
                icon: Icons.task_alt_rounded,
                title: l10n.tasksEmpty,
                message: l10n.tasksEmptyBody,
                compact: true,
              )
            else
              for (final t in tasks)
                _TaskRow(
                  task: t,
                  busy: busy.contains(t.code),
                  onGo: () => onGo(t.metric),
                  onClaim: () => onClaim(t.code),
                ),
          ],
        ),
      ),
    );
  }
}

/// One task: the tinted icon tile, «name (x/y)» in bold, «+N» cherries (D184)
/// and the pill («اذهب», «استلم» or «تم»).
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

  static const _teal = Color(0xFF14B8A6);
  static const _pink = Color(0xFFFF3B6B);
  static const _blue = Color(0xFF4DA3FF);
  static const _amber = Color(0xFFE0A21B);

  static (IconData, Color) look(TaskMetric metric) => switch (metric) {
    TaskMetric.watchLives => (Icons.videocam_rounded, _teal),
    TaskMetric.watchMinutes => (Icons.timer_rounded, _teal),
    TaskMetric.audioRooms => (Icons.mic_rounded, _blue),
    TaskMetric.follows => (Icons.person_add_rounded, _pink),
    TaskMetric.liveChatMessages => (Icons.chat_bubble_rounded, _blue),
    TaskMetric.liveTaps => (Icons.favorite_rounded, _pink),
    TaskMetric.giftSends => (Icons.redeem_rounded, _amber),
    TaskMetric.newHostGifts => (Icons.volunteer_activism_rounded, _amber),
    TaskMetric.posts => (Icons.edit_note_rounded, _teal),
    TaskMetric.reels => (Icons.movie_rounded, KBrandColors.red500),
    TaskMetric.stories => (Icons.amp_stories_rounded, _pink),
    TaskMetric.postComments => (Icons.mode_comment_rounded, _blue),
    TaskMetric.dmFriends => (Icons.send_rounded, _blue),
    TaskMetric.dmVoiceMessages => (Icons.keyboard_voice_rounded, _teal),
    TaskMetric.hostLiveMinutes => (Icons.live_tv_rounded, KBrandColors.red500),
    TaskMetric.hostGiftCoins ||
    TaskMetric.hostGiftsReceived => (Icons.card_giftcard_rounded, _amber),
    TaskMetric.hostGuests => (Icons.event_seat_rounded, _blue),
    TaskMetric.other => (Icons.task_alt_rounded, _teal),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final (icon, hue) = look(task.metric);
    final progress = ' (${task.progress}/${task.target})';
    final key = TaskCenterScreen.actionKey(task.code);
    final Widget action;
    if (task.claimed) {
      action = TaskPill(
        key: key,
        label: l10n.tasksActionDone,
        kind: TaskPillKind.done,
        onPressed: null,
      );
    } else if (task.completed) {
      action = TaskPill(
        key: key,
        label: l10n.tasksActionClaim,
        kind: TaskPillKind.claim,
        loading: busy,
        onPressed: onClaim,
      );
    } else {
      action = TaskPill(key: key, label: l10n.tasksActionGo, onPressed: onGo);
    }
    final amount = task.shownReward;
    return ConstrainedBox(
      key: TaskCenterScreen.taskKey(task.code),
      constraints: const BoxConstraints(minHeight: TaskCenterScreen.rowPitch),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                hue.withValues(alpha: 0.14),
                p.surfaceRaised,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: TaskCenterScreen.iconTile,
              child: Icon(icon, size: 21, color: hue),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // D184: the name first, its progress quieter, then the
                  // reward on a smaller line.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: task.name),
                        TextSpan(
                          text: progress,
                          style: TextStyle(
                            color: p.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(
                      color: p.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  // D184: cherries (a claim made in coins before keeps its
                  // coin).
                  Semantics(
                    label: task.inCoins
                        ? l10n.meHubCoins('$amount')
                        : l10n.walletCherries(KFormat.grouped(amount)),
                    excludeSemantics: true,
                    child: task.inCoins
                        ? CoinAmount(
                            amount,
                            prefix: '+',
                            size: 14,
                            style: t.caption.copyWith(
                              color: programGold(context),
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : TaskCherryAmount(
                            amount,
                            key: TaskCenterScreen.rewardAmountKey(task.code),
                            size: 14,
                            style: t.caption.copyWith(
                              color: p.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          action,
        ],
      ),
    );
  }
}

/// The team's Task Center banners (`placement=tasks`); nothing when none.
class _TaskBanners extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(taskBannersProvider).value ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: TaskCenterScreen.bannerKey,
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: KHomeBannerCarousel(
        banners: banners,
        canOpen: (b) => b.link.startsWith('/'),
        onOpen: (b) => unawaited(context.push(b.link)),
      ),
    );
  }
}

/// «التقويم»: the 7-day cycle with each day's coins, the streak and the rule.
class _CheckInCalendarSheet extends StatelessWidget {
  const new({required this.state});

  final CheckInState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SafeArea(
      key: TaskCenterScreen.calendarSheetKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tasksCalendarTitle,
              style: t.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.tasksCalendarBody('${state.bonusCoins}'),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            for (final day in state.days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      day.checkedIn
                          ? Icons.check_circle_rounded
                          : day.cycleDay == state.cycleDays
                          ? Icons.redeem_rounded
                          : Icons.card_giftcard_rounded,
                      size: 20,
                      color: day.checkedIn
                          ? p.primary
                          : day.cycleDay == state.cycleDays
                          ? KBrandColors.gold
                          : p.textTertiary,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Text(
                        day.today
                            ? l10n.tasksToday
                            : '${day.date.month}.${day.date.day}',
                        textDirection: day.today ? null : TextDirection.ltr,
                        textAlign:
                            Directionality.of(context) == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        style: t.body,
                      ),
                    ),
                    Text(
                      l10n.tasksDayCoins('${day.rewardCoins}'),
                      style: t.label.copyWith(color: programGold(context)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.tasksStreak('${state.streak}'),
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// D184: «+N» with the cherry (`KCherryIcon`), Latin digits — a task's reward.
class TaskCherryAmount extends StatelessWidget {
  const new(this.cherries, {super.key, this.size = 15, this.style});

  final int cherries;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      KCherryIcon(size: size),
      const SizedBox(width: KSpacing.xxs),
      Text(
        '+${KFormat.grouped(cherries)}',
        textDirection: TextDirection.ltr,
        // In a snack bar: the bar's own text colour.
        style:
            style ??
            DefaultTextStyle.of(context).style
                .copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
