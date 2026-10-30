import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge/employees` «الموظفون» (D185, §10.48): the agent's employees —
/// each with their weekly hours in their time zone, on shift now or not,
/// and their sales today, in 7 and in 30 days (count and coins). The agent
/// adds an existing user, changes the hours or removes them (they stop
/// selling at once).
class RechargeEmployeesScreen extends ConsumerWidget {
  const new({super.key});

  static const addKey = Key('recharge.employees.add');
  static const emptyKey = Key('recharge.employees.empty');
  static Key rowKey(String username) => Key('recharge.employee.$username');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final load = ref.watch(rechargeEmployeesProvider);
    Future<void> refresh() async {
      ref.invalidate(rechargeEmployeesProvider);
      try {
        await ref.read(rechargeEmployeesProvider.future);
      } on Object {
        // Shown with a retry.
      }
    }

    return MePage(
      title: l10n.rechargeEmployeesTitle,
      onRefresh: refresh,
      children: [
        KButton(
          key: addKey,
          label: l10n.rechargeAddEmployee,
          icon: Icons.person_add_alt_1_rounded,
          variant: KButtonVariant.secondary,
          onPressed: () => unawaited(_edit(context, ref, null)),
        ),
        const SizedBox(height: KSpacing.md),
        ...switch (load) {
          AsyncValue(:final value?) when value.isEmpty => [
            KEmptyState(
              key: emptyKey,
              icon: Icons.badge_outlined,
              title: l10n.rechargeEmployeesEmpty,
              message: l10n.rechargeEmployeesHint,
              compact: true,
            ),
          ],
          AsyncValue(:final value?) => [
            for (final e in value) _EmployeeCard(employee: e),
          ],
          AsyncValue(:final error?, isLoading: false) => [
            FailureErrorState(
              title: l10n.errorTitle,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(rechargeEmployeesProvider),
              compact: true,
            ),
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }
}

Future<void> _edit(
  BuildContext context,
  WidgetRef ref,
  RechargeEmployee? employee,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => RechargeEmployeeSheet(employee: employee),
);

class _EmployeeCard extends ConsumerWidget {
  const new({required this.employee});

  final RechargeEmployee employee;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(
          l10n.rechargeRemoveEmployeeConfirm(
            KFormat.bidiIsolate(employee.user.displayName),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.rechargeRemove),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(rechargeRepositoryProvider)
          .removeEmployee(employee.user.username);
      ref.invalidate(rechargeEmployeesProvider);
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
    final t = context.textStyles;
    final u = employee.user;
    String totals(SalesTotals s) => l10n.rechargeSalesTotals(
      s.count,
      KFormat.bidiIsolate(KFormat.grouped(s.coins)),
    );
    return Padding(
      key: RechargeEmployeesScreen.rowKey(u.username),
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: RechargeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KAvatar(name: u.displayName, imageUrl: u.avatarUrl, size: 44),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        '@${u.username}',
                        textDirection: TextDirection.ltr,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                RechargeShiftChip(onShift: employee.onShiftNow),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            for (final s in employee.schedule)
              Text(
                rechargeSlotText(context, s, timeZone: employee.timeZone),
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            const SizedBox(height: KSpacing.sm),
            MeStatGrid(
              stats: [
                (
                  Key('recharge.employee.${u.username}.today'),
                  l10n.rechargeToday,
                  totals(employee.sales.today),
                ),
                (
                  Key('recharge.employee.${u.username}.7'),
                  l10n.rechargeLast7,
                  totals(employee.sales.last7Days),
                ),
                (
                  Key('recharge.employee.${u.username}.30'),
                  l10n.rechargeLast30,
                  totals(employee.sales.last30Days),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => unawaited(_edit(context, ref, employee)),
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(l10n.rechargeHours),
                ),
                TextButton.icon(
                  onPressed: () => unawaited(_remove(context, ref)),
                  icon: Icon(Icons.person_remove_rounded, color: p.error),
                  label: Text(
                    l10n.rechargeRemove,
                    style: TextStyle(color: p.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add an employee (username, zone, hours) or change one's hours.
class RechargeEmployeeSheet extends ConsumerStatefulWidget {
  const new({super.key, this.employee});

  final RechargeEmployee? employee;

  static const usernameKey = Key('recharge.employee.username');
  static const saveKey = Key('recharge.employee.save');

  @override
  ConsumerState<RechargeEmployeeSheet> createState() =>
      _RechargeEmployeeSheetState();
}

class _RechargeEmployeeSheetState extends ConsumerState<RechargeEmployeeSheet> {
  final _username = TextEditingController();
  late String _zone = widget.employee?.timeZone ?? 'Africa/Cairo';
  late final List<WeeklySlot> _slots = [
    ...?widget.employee?.schedule,
    if (widget.employee == null)
      const WeeklySlot(days: [1, 2, 3, 4, 5], start: '10:00', end: '18:00'),
  ];
  int _version = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final repo = ref.read(rechargeRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = widget.employee;
      if (e == null) {
        await repo.addEmployee(_username.text, _zone, _slots);
      } else {
        await repo.updateEmployee(e.user.username, _zone, _slots);
      }
      if (!mounted) return;
      ref.invalidate(rechargeEmployeesProvider);
      Navigator.of(context).pop();
      KSnack.success(context, l10n.rechargeSaved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(KSpacing.lg),
          children: [
            Text(
              widget.employee == null
                  ? l10n.rechargeAddEmployee
                  : l10n.rechargeHours,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.md),
            if (widget.employee == null) ...[
              KTextField(
                fieldKey: RechargeEmployeeSheet.usernameKey,
                label: l10n.rechargeEmployeeUsername,
                controller: _username,
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            RechargeZoneField(
              value: _zone,
              onChanged: (z) => setState(() => _zone = z),
            ),
            const SizedBox(height: KSpacing.sm),
            for (final (i, s) in _slots.indexed)
              RechargeSlotEditor(
                key: ValueKey('eslot.$_version.$i'),
                slot: s,
                onChanged: (v) => setState(() => _slots[i] = v),
                onRemove: () => setState(() {
                  if (_slots.length > 1) _slots.removeAt(i);
                  _version++;
                }),
              ),
            TextButton.icon(
              onPressed: () => setState(
                () => _slots.add(
                  const WeeklySlot(days: [6], start: '10:00', end: '18:00'),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.rechargeAddSlot),
            ),
            if (_error case final e?)
              Text(e, style: t.caption.copyWith(color: p.error)),
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: RechargeEmployeeSheet.saveKey,
              label: l10n.rechargeSave,
              loading: _busy,
              onPressed: _busy ? null : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }
}
