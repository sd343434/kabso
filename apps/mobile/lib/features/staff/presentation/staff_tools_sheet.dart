import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/presentation/staff_step_up_dialog.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.68-live (D273, §10.96.6; owner: «بعض الموظفين ليس لديهم لابتوب»):
/// «أدوات فريق كابسو» inside a live — the panel's moderation of a live from
/// the phone, each action limited by the staff member's role exactly as in
/// the panel (SUPPORT reads the reports; MODERATION and OWNER act), each
/// with a reason (audited `via: app`). Locked until the step-up.
Future<void> showStaffTools(
  BuildContext context, {
  required String roomId,
  required String hostName,
  required StaffVisibility visibility,
  ValueChanged<StaffVisibility>? onSwitchMode,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => StaffToolsSheet(
    roomId: roomId,
    hostName: hostName,
    visibility: visibility,
    onSwitchMode: onSwitchMode,
  ),
);

/// D273: the live's «أدوات فريق كابسو» button (the team's shield; an eye
/// struck through while watching hidden).
class StaffToolsButton extends StatelessWidget {
  const new({required this.onTap, super.key, this.hidden = false});

  final VoidCallback onTap;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.staffToolsTitle,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: KabsoTeamColors.gradient,
          border: Border.all(color: const Color(0xCCFFFFFF), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: Icon(
          hidden ? Icons.visibility_off_rounded : Icons.admin_panel_settings,
          size: 24,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    ),
  );
}

/// The panel's quick durations (hours) for a ban from going live or a
/// suspension.
const staffDurations = [1, 24, 72, 168, 720];

class StaffToolsSheet extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.hostName,
    required this.visibility,
    super.key,
    this.onSwitchMode,
  });

  static const unlockKey = Key('staff.tools.unlock');
  static const lockKey = Key('staff.tools.lock');
  static const switchKey = Key('staff.tools.switchMode');
  static const personKey = Key('staff.tools.person');
  static Key action(StaffLiveAction a) => Key('staff.tools.action.${a.name}');
  static const dismissKey = Key('staff.tools.dismiss');
  static Key report(int i) => Key('staff.tools.report.$i');

  final String roomId;
  final String hostName;
  final StaffVisibility visibility;
  final ValueChanged<StaffVisibility>? onSwitchMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final status = ref.watch(staffStatusProvider).value;
    final canHidden = status?.can(StaffCapability.watchHidden) ?? false;
    final modeLabel = visibility == StaffVisibility.hidden
        ? l10n.staffEnterHidden
        : l10n.staffEnterVisible;

    Widget body;
    if (status == null) {
      body = const Padding(
        padding: EdgeInsets.all(KSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!status.unlocked) {
      body = _Locked(enrolled: status.authenticatorEnrolled);
    } else {
      body = _Tools(roomId: roomId, hostName: hostName, status: status);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.md,
          KSpacing.lg,
          KSpacing.xl,
        ),
        children: [
          Row(
            children: [
              const KabsoTeamShield(size: 36),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.staffToolsTitle, style: text.title),
                    Text(
                      hostName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          // D273 (owner): visible or hidden, switched from here.
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                visibility == StaffVisibility.hidden
                    ? Icons.visibility_off_rounded
                    : Icons.verified_user_rounded,
                color: KabsoTeamColors.end,
              ),
              title: Text(l10n.staffModeNow(modeLabel)),
              trailing: canHidden && onSwitchMode != null
                  ? TextButton(
                      key: switchKey,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSwitchMode!(
                          visibility == StaffVisibility.hidden
                              ? StaffVisibility.visible
                              : StaffVisibility.hidden,
                        );
                      },
                      child: Text(l10n.staffModeSwitch),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: KSpacing.md),
          body,
        ],
      ),
    );
  }
}

class _Locked extends ConsumerWidget {
  const new({required this.enrolled});

  final bool enrolled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: KSpacing.lg),
        Icon(Icons.lock_rounded, size: 40, color: p.textTertiary),
        const SizedBox(height: KSpacing.sm),
        Text(
          enrolled ? l10n.staffLockedTools : l10n.staffStepUpEnrol,
          textAlign: TextAlign.center,
          style: context.textStyles.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: KSpacing.lg),
        if (enrolled)
          KButton(
            key: StaffToolsSheet.unlockKey,
            label: l10n.staffUnlock,
            icon: Icons.key_rounded,
            onPressed: () => unawaited(showStaffStepUp(context)),
          ),
      ],
    );
  }
}

class _Tools extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.hostName,
    required this.status,
  });

  final String roomId;
  final String hostName;
  final StaffStatus status;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(StaffRepository repo) call,
  ) async {
    try {
      await call(ref.read(staffRepositoryProvider));
      ref.invalidate(staffReportsProvider(roomId));
      if (context.mounted) KSnack.success(context, context.l10n.staffDone);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
      // The step-up ended (role, lockout, sign-out): show the lock again.
      ref.invalidate(staffStatusProvider);
    }
  }

  Future<void> _live(
    BuildContext context,
    WidgetRef ref,
    StaffLiveAction action,
    String title,
  ) async {
    final input = await showStaffReasonDialog(
      context,
      title: title,
      toHost: true,
      timed: action.timed,
    );
    if (input == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (r) =>
          r.moderate(roomId, action, reason: input.reason, hours: input.hours),
    );
  }

  Future<void> _person(
    BuildContext context,
    WidgetRef ref,
    String username, {
    required bool kick,
  }) async {
    final l10n = context.l10n;
    final input = await showStaffReasonDialog(
      context,
      title:
          '${kick ? l10n.staffActionKick : l10n.staffActionMute} · '
          '@$username',
    );
    if (input == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (r) => kick
          ? r.kick(roomId, username: username, reason: input.reason)
          : r.mute(roomId, username: username, reason: input.reason),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final canAct = status.can(StaffCapability.moderate);
    final reports = status.can(StaffCapability.reports)
        ? ref.watch(staffReportsProvider(roomId))
        : null;
    final until = status.stepUpUntil!.toLocal();
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(until));

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: KSpacing.lg, bottom: KSpacing.sm),
      child: Text(title, style: text.bodyStrong),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.lock_open_rounded, size: 18, color: p.success),
            const SizedBox(width: KSpacing.xs),
            Expanded(
              child: Text(
                l10n.staffUnlocked(time),
                style: text.caption.copyWith(color: p.textSecondary),
              ),
            ),
            TextButton(
              key: StaffToolsSheet.lockKey,
              onPressed: () =>
                  unawaited(ref.read(staffStatusProvider.notifier).endStepUp()),
              child: Text(l10n.staffLock),
            ),
          ],
        ),
        if (!canAct)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.sm),
            child: Text(
              l10n.staffReadOnly,
              style: text.caption.copyWith(color: p.warning),
            ),
          ),
        if (reports != null) ...[
          section(l10n.staffReports),
          switch (reports) {
            AsyncData(:final value) when value.isEmpty => Text(
              l10n.staffReportsEmpty,
              style: text.body.copyWith(color: p.textTertiary),
            ),
            AsyncData(:final value) => Column(
              children: [
                for (final (i, r) in value.indexed)
                  _ReportTile(
                    key: StaffToolsSheet.report(i),
                    report: r,
                    canAct: canAct,
                    onKick: (u) => _person(context, ref, u, kick: true),
                    onMute: (u) => _person(context, ref, u, kick: false),
                    onRemove: (id) async {
                      final input = await showStaffReasonDialog(
                        context,
                        title: l10n.staffActionRemoveMessage,
                      );
                      if (input == null || !context.mounted) return;
                      await _run(
                        context,
                        ref,
                        (rep) =>
                            rep.removeMessage(roomId, id, reason: input.reason),
                      );
                    },
                  ),
              ],
            ),
            AsyncError(:final error) => Text(
              failureMessage(l10n, toAppFailure(error)),
              style: text.body.copyWith(color: p.error),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
        if (canAct) ...[
          section(l10n.staffActions),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final (a, label, icon) in [
                (
                  StaffLiveAction.warn,
                  l10n.staffActionWarn,
                  Icons.report_rounded,
                ),
                (
                  StaffLiveAction.end,
                  l10n.staffActionEnd,
                  Icons.stop_circle_rounded,
                ),
                (
                  StaffLiveAction.noLive,
                  l10n.staffActionNoLive,
                  Icons.videocam_off_rounded,
                ),
                (
                  StaffLiveAction.suspend,
                  l10n.staffActionSuspend,
                  Icons.block_rounded,
                ),
              ])
                ActionChip(
                  key: StaffToolsSheet.action(a),
                  avatar: Icon(
                    icon,
                    size: 18,
                    color: a == StaffLiveAction.warn ? p.warning : p.error,
                  ),
                  label: Text(label),
                  onPressed: () => unawaited(_live(context, ref, a, label)),
                ),
              ActionChip(
                key: StaffToolsSheet.dismissKey,
                avatar: Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: p.success,
                ),
                label: Text(l10n.staffActionDismiss),
                onPressed: () async {
                  final input = await showStaffReasonDialog(
                    context,
                    title: l10n.staffActionDismiss,
                  );
                  if (input == null || !context.mounted) return;
                  await _run(
                    context,
                    ref,
                    (r) => r.dismissReports(roomId, reason: input.reason),
                  );
                },
              ),
            ],
          ),
          section(l10n.staffPersonActions),
          _PersonField(
            onKick: (u) => _person(context, ref, u, kick: true),
            onMute: (u) => _person(context, ref, u, kick: false),
          ),
        ],
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const new({
    required this.report,
    required this.canAct,
    required this.onKick,
    required this.onMute,
    required this.onRemove,
    super.key,
  });

  final StaffReport report;
  final bool canAct;
  final Future<void> Function(String username) onKick;
  final Future<void> Function(String username) onMute;
  final Future<void> Function(String messageId) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final who = report.person;
    final name = who == null
        ? ''
        : (who.displayName.isEmpty ? who.username : who.displayName);
    final title = switch (report.target) {
      StaffReportTarget.live => l10n.staffReportOnLive,
      StaffReportTarget.user => l10n.staffReportOnUser(name),
      StaffReportTarget.message => l10n.staffReportOnMessage(name),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(
          color: report.open ? p.error.withValues(alpha: 0.5) : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: text.bodyStrong)),
              Text(
                report.open
                    ? reportReasonLabel(
                        l10n,
                        ReportReason.values.firstWhere(
                          (r) => r.wire == report.reason,
                          orElse: () => ReportReason.other,
                        ),
                      )
                    : l10n.staffReportClosed,
                style: text.caption.copyWith(
                  color: report.open ? p.error : p.textTertiary,
                ),
              ),
            ],
          ),
          if (report.messageText case final t? when t.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                '«$t»',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.body,
              ),
            ),
          if (report.note case final n? when n.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                n,
                style: text.caption.copyWith(color: p.textSecondary),
              ),
            ),
          if (report.reporter case final r?)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                l10n.staffReportBy(
                  r.displayName.isEmpty ? r.username : r.displayName,
                ),
                style: text.caption.copyWith(color: p.textTertiary),
              ),
            ),
          if (canAct && report.open && who != null)
            Wrap(
              spacing: KSpacing.xs,
              children: [
                if (report.messageId case final id?)
                  TextButton(
                    onPressed: () => unawaited(onRemove(id)),
                    child: Text(l10n.staffActionRemoveMessage),
                  ),
                TextButton(
                  onPressed: () => unawaited(onMute(who.username)),
                  child: Text(l10n.staffActionMute),
                ),
                TextButton(
                  onPressed: () => unawaited(onKick(who.username)),
                  child: Text(l10n.staffActionKick),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PersonField extends StatefulWidget {
  const new({required this.onKick, required this.onMute});

  final Future<void> Function(String username) onKick;
  final Future<void> Function(String username) onMute;

  @override
  State<_PersonField> createState() => _PersonFieldState();
}

class _PersonFieldState extends State<_PersonField> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _username {
    final u = _name.text.trim().replaceFirst(RegExp('^@'), '');
    return u.isEmpty ? null : u;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: StaffToolsSheet.personKey,
          controller: _name,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.staffPersonField,
            prefixText: '@',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: KSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _username == null
                    ? null
                    : () => unawaited(widget.onMute(_username!)),
                child: Text(l10n.staffActionMute),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: _username == null
                    ? null
                    : () => unawaited(widget.onKick(_username!)),
                child: Text(l10n.staffActionKick),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A reason (required, recorded with the action) and, for a ban from going
/// live or a suspension, the duration — the panel's quick choices.
Future<({String reason, int? hours})?> showStaffReasonDialog(
  BuildContext context, {
  required String title,
  bool toHost = false,
  bool timed = false,
}) => showDialog<({String reason, int? hours})>(
  context: context,
  builder: (_) => StaffReasonDialog(title: title, toHost: toHost, timed: timed),
);

class StaffReasonDialog extends StatefulWidget {
  const new({
    required this.title,
    super.key,
    this.toHost = false,
    this.timed = false,
  });

  static const reasonKey = Key('staff.reason.text');
  static const applyKey = Key('staff.reason.apply');

  final String title;
  final bool toHost;
  final bool timed;

  @override
  State<StaffReasonDialog> createState() => _StaffReasonDialogState();
}

class _StaffReasonDialogState extends State<StaffReasonDialog> {
  final _reason = TextEditingController();
  int _hours = staffDurations[1];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n, int h) => switch (h) {
    1 => l10n.staffDuration1h,
    24 => l10n.staffDuration24h,
    72 => l10n.staffDuration3d,
    168 => l10n.staffDuration7d,
    _ => l10n.staffDuration30d,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final ok = _reason.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: StaffReasonDialog.reasonKey,
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.staffReason),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.toHost)
              Text(
                l10n.staffReasonHostHint,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            if (widget.timed) ...[
              const SizedBox(height: KSpacing.md),
              Text(l10n.staffDuration, style: context.textStyles.bodyStrong),
              const SizedBox(height: KSpacing.xs),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final h in staffDurations)
                    ChoiceChip(
                      label: Text(_label(l10n, h)),
                      selected: _hours == h,
                      onSelected: (_) => setState(() => _hours = h),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: StaffReasonDialog.applyKey,
          onPressed: ok
              ? () => Navigator.of(context).pop((
                  reason: _reason.text.trim(),
                  hours: widget.timed ? _hours : null,
                ))
              : null,
          child: Text(l10n.staffApply),
        ),
      ],
    );
  }
}
