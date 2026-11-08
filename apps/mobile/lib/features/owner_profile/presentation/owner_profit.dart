import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart'
    show FounderDashboardCard, ownerMoney;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D301 follow-up (owner 2026-11-07: «ان تزيل نسب الجميع لكون ربح نهائي
/// وضعها قبل وبعد … تكاليف ثابتة … يتم تقسيمها على الشهر»; §10.112.10):
/// «الربح» — the money Kabso received («قبل»), every share it owes from the
/// real ledgers, the fixed monthly costs prorated by day, and what is left
/// («بعد», red when negative). Owner only.

/// The red that marks a loss (also on white).
const Color ownerLossRed = Color(0xFFD7263D);

/// A local day `YYYY-MM-DD` as a local date.
DateTime ownerDayDate(String key) => DateTime(
  int.parse(key.substring(0, 4)),
  int.parse(key.substring(5, 7)),
  int.parse(key.substring(8, 10)),
);

/// A local date as `YYYY-MM-DD`.
String ownerDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _signedCost(int minor) => minor < 0
    ? '+${ownerMoney(-minor, 'USD')}'
    : (minor == 0 ? ownerMoney(0, 'USD') : '−${ownerMoney(minor, 'USD')}');

String _signed(int minor) =>
    minor < 0 ? '−${ownerMoney(-minor, 'USD')}' : ownerMoney(minor, 'USD');

// ---- the card's strip -------------------------------------------------------

/// «ربح اليوم»: «قبل» → «بعد» on «لوحة المؤسس», blurred like the income until
/// tapped.
class FounderProfitStrip extends ConsumerWidget {
  const new({required this.hidden, this.onTap, super.key});

  final bool hidden;
  final VoidCallback? onTap;

  static const stripKey = Key('owner.profit.strip');
  static const hiddenKey = Key('owner.profit.strip.hidden');
  static const afterKey = Key('owner.profit.strip.after');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = ref.watch(ownerProfitProvider(null)).value;
    const white = Color(0xFFFFFFFF);
    const soft = Color(0xE6FFFFFF);
    final before = p == null ? '—' : ownerMoney(p.day.beforeMinor, 'USD');
    final afterMinor = p?.day.afterMinor;
    final loss = (afterMinor ?? 0) < 0;
    Widget value(String text, {Key? key, bool pill = false}) {
      Widget v = Text(
        text,
        key: key,
        maxLines: 1,
        textDirection: TextDirection.ltr,
        style: t.bodyStrong.copyWith(
          color: pill ? ownerLossRed : white,
          fontWeight: FontWeight.w800,
        ),
      );
      if (pill) {
        v = DecoratedBox(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(KRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: v,
          ),
        );
      }
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: v,
      );
    }

    Widget half(String label, Widget v) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: t.caption.copyWith(color: soft, fontSize: 11),
          ),
          v,
        ],
      ),
    );
    Widget numbers = Row(
      children: [
        half(l10n.ownerProfitBeforeShort, value(before)),
        Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          size: 16,
          color: soft,
        ),
        const SizedBox(width: KSpacing.sm),
        half(
          l10n.ownerProfitAfterShort,
          value(
            afterMinor == null ? '—' : _signed(afterMinor),
            key: afterKey,
            pill: loss,
          ),
        ),
      ],
    );
    if (hidden) {
      numbers = ImageFiltered(
        key: hiddenKey,
        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ExcludeSemantics(child: numbers),
      );
    }
    final strip = DecoratedBox(
      key: stripKey,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.xs,
        ),
        child: Row(
          children: [
            const Icon(Icons.trending_up_rounded, size: 16, color: soft),
            const SizedBox(width: KSpacing.xs),
            Text(
              l10n.ownerProfitToday,
              style: t.caption.copyWith(color: soft, fontSize: 11),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(child: numbers),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: hidden
          ? '${l10n.ownerProfitToday}، ${l10n.ownerDashboardIncomeHidden}'
          : '${l10n.ownerProfitToday}: ${l10n.ownerProfitBeforeShort} $before، '
                '${l10n.ownerProfitAfterShort} '
                '${afterMinor == null ? '—' : _signed(afterMinor)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: strip,
      ),
    );
  }
}

// ---- the details ------------------------------------------------------------

/// «الربح» in the dashboard's details: a day or its month (a past day can be
/// picked), «قبل» with its parts, each deduction (expandable), the fixed
/// costs, «بعد», other currencies apart, and «إدارة التكاليف الثابتة».
class OwnerProfitView extends ConsumerStatefulWidget {
  const new({super.key, this.initialMonth = false});

  /// Opens on the month (else the day).
  final bool initialMonth;

  static const viewKey = Key('owner.profit');
  static const dayTabKey = Key('owner.profit.tab.day');
  static const monthTabKey = Key('owner.profit.tab.month');
  static const pickDayKey = Key('owner.profit.pickDay');
  static const beforeKey = Key('owner.profit.before');
  static const afterKey = Key('owner.profit.after');
  static const fixedKey = Key('owner.profit.fixed');
  static const partialKey = Key('owner.profit.partial');
  static const manageCostsKey = Key('owner.profit.manageCosts');
  static const retryKey = Key('owner.profit.retry');
  static const Key incomeNoteKey = FounderDashboardCard.incomeNoteKey;

  /// D307 follow-up: the sheet of [showOwnerProfitSheet].
  static const sheetKey = Key('owner.profit.sheet');
  static Key deductionKey(ProfitDeductionKey k) =>
      Key('owner.profit.deduction.${k.wire}');

  @override
  ConsumerState<OwnerProfitView> createState() => _OwnerProfitViewState();
}

class _OwnerProfitViewState extends ConsumerState<OwnerProfitView> {
  late bool _month = widget.initialMonth;
  String? _day;

  Future<void> _pickDay(OwnerProfit p) async {
    final today = ownerDayDate(p.today);
    final current = ownerDayDate(_day ?? p.today);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2026),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    final key = ownerDayKey(picked);
    setState(() => _day = key == p.today ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final load = ref.watch(ownerProfitProvider(_day));
    final data = load.value;
    final header = Row(
      children: [
        Expanded(child: Text(l10n.ownerProfitTitle, style: t.title)),
        TextButton.icon(
          key: OwnerProfitView.pickDayKey,
          onPressed: data == null ? null : () => unawaited(_pickDay(data)),
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(
            data == null
                ? l10n.ownerProfitPickDay
                : (_month
                      ? DateFormat.yMMMM(tag)
                            .format(ownerDayDate(data.month.from))
                      : KFormat.date(ownerDayDate(data.day.key), tag)),
          ),
        ),
      ],
    );
    final tabs = SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          label: Text(l10n.ownerProfitDay, key: OwnerProfitView.dayTabKey),
        ),
        ButtonSegment(
          value: true,
          label: Text(l10n.ownerProfitMonth, key: OwnerProfitView.monthTabKey),
        ),
      ],
      selected: {_month},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _month = s.first),
    );
    final Widget body;
    if (data == null) {
      body = load.hasError
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.ownerProfitFailed,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  ),
                  TextButton(
                    key: OwnerProfitView.retryKey,
                    onPressed: () => ref.invalidate(ownerProfitProvider(_day)),
                    child: Text(l10n.ownerProfitRetry),
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(KSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
    } else {
      body = _PeriodView(profit: data, period: _month ? data.month : data.day);
    }
    return Column(
      key: OwnerProfitView.viewKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: KSpacing.xs),
        tabs,
        const SizedBox(height: KSpacing.sm),
        body,
        const SizedBox(height: KSpacing.sm),
        OutlinedButton.icon(
          key: OwnerProfitView.manageCostsKey,
          onPressed: () => unawaited(showFixedCostsEditor(context)),
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text(l10n.ownerCostsManage),
        ),
      ],
    );
  }
}

String deductionLabel(AppLocalizations l10n, ProfitDeductionKey k) =>
    switch (k) {
      ProfitDeductionKey.gifts => l10n.ownerProfitGifts,
      ProfitDeductionKey.agencyCommissions => l10n.ownerProfitAgencies,
      ProfitDeductionKey.referralRewards => l10n.ownerProfitReferrals,
      ProfitDeductionKey.taskRewards => l10n.ownerProfitTasks,
      ProfitDeductionKey.staffCommissions => l10n.ownerProfitStaff,
      ProfitDeductionKey.teamAdjustments => l10n.ownerProfitTeam,
      ProfitDeductionKey.coinRewards => l10n.ownerProfitCoins,
      ProfitDeductionKey.cardFees => l10n.ownerProfitCardFees,
    };

class _PeriodView extends StatelessWidget {
  const new({required this.profit, required this.period});

  final OwnerProfit profit;
  final OwnerProfitPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    Widget amount(String text, {Color? color, bool strong = false}) => Text(
      text,
      textDirection: TextDirection.ltr,
      style: (strong ? t.bodyStrong : t.body).copyWith(color: color),
    );
    Widget line(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: t.caption.copyWith(color: color ?? p.textSecondary),
          ),
        ],
      ),
    );
    Widget group({
      required Key key,
      required String title,
      required String value,
      required List<Widget> children,
      Color? color,
      bool strong = false,
      IconData? icon,
    }) => Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0x00000000)),
      child: ExpansionTile(
        key: key,
        tilePadding: EdgeInsets.zero,
        dense: true,
        minTileHeight: 44,
        visualDensity: VisualDensity.compact,
        childrenPadding: const EdgeInsetsDirectional.only(
          start: KSpacing.lg,
          bottom: KSpacing.xs,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: icon == null ? null : Icon(icon, size: 18),
        // The amount beside the label; the arrow says it opens.
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: strong ? t.bodyStrong : t.body,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            amount(value, color: color, strong: strong),
          ],
        ),
        children: children,
      ),
    );
    final rate = ownerMoney(profit.rateMinor, 'USD');
    final bps = profit.cardFeeBps;
    final percent = '${(bps / 100).toStringAsFixed(bps % 100 == 0 ? 0 : 1)}%';
    final loss = period.afterMinor < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        group(
          key: OwnerProfitView.beforeKey,
          title: l10n.ownerProfitBefore,
          value: ownerMoney(period.beforeMinor, 'USD'),
          strong: true,
          icon: Icons.account_balance_wallet_rounded,
          children: [
            line(
              l10n.ownerProfitCardCharged,
              ownerMoney(period.cardChargedMinor, 'USD'),
            ),
            line(l10n.ownerProfitRefunds, _signedCost(period.refundsMinor)),
            line(
              l10n.ownerProfitChargebacks,
              _signedCost(period.chargebacksMinor),
            ),
            line(l10n.ownerProfitAgents, ownerMoney(period.agentsMinor, 'USD')),
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xxs),
              child: Text(
                l10n.ownerDashboardIncomeNote,
                key: OwnerProfitView.incomeNoteKey,
                style: t.caption.copyWith(color: p.textTertiary),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: KSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.ownerProfitDeductions,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ),
              Text(
                _signedCost(period.deductionsMinor + period.fixedCostsMinor),
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        for (final d in period.deductions)
          group(
            key: OwnerProfitView.deductionKey(d.key),
            title: deductionLabel(l10n, d.key),
            value: _signedCost(d.amountMinor),
            children: [
              Text(switch (d.key) {
                ProfitDeductionKey.cardFees => l10n.ownerProfitFees(
                  KFormat.grouped(d.orders ?? 0),
                  percent,
                  ownerMoney(profit.cardFeeFixedMinor, 'USD'),
                ),
                ProfitDeductionKey.coinRewards => l10n.ownerProfitCoinsDetail(
                  KFormat.grouped(d.coins ?? 0),
                  ownerMoney(profit.coinValueMinorPerMillion, 'USD'),
                ),
                _ => l10n.ownerProfitCherries(
                  KFormat.grouped(d.cherries ?? 0),
                  rate,
                ),
              }, style: t.caption.copyWith(color: p.textSecondary)),
            ],
          ),
        group(
          key: OwnerProfitView.fixedKey,
          title: l10n.ownerProfitFixed,
          value: _signedCost(period.fixedCostsMinor),
          children: [
            if (period.fixedCosts.isEmpty)
              Text(
                l10n.ownerProfitFixedNone,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            for (final c in period.fixedCosts) ...[
              line(c.name, _signedCost(c.shareMinor)),
              Text(
                l10n.ownerProfitFixedShare(
                  '${c.days}/${period.daysInMonth}',
                  ownerMoney(c.monthlyMinor, 'USD'),
                ),
                style: t.caption.copyWith(color: p.textTertiary, fontSize: 11),
              ),
            ],
          ],
        ),
        if (period.partial)
          Text(
            l10n.ownerProfitPartial,
            key: OwnerProfitView.partialKey,
            style: t.caption.copyWith(color: p.textTertiary),
          ),
        const SizedBox(height: KSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: (loss ? ownerLossRed : const Color(0xFF12B76A)).withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.ownerProfitAfter, style: t.bodyStrong),
                ),
                Text(
                  _signed(period.afterMinor),
                  key: OwnerProfitView.afterKey,
                  textDirection: TextDirection.ltr,
                  style: t.title.copyWith(
                    color: loss ? ownerLossRed : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final o in period.otherCurrencies)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: Text(
              l10n.ownerProfitOther(
                o.currency,
                ownerMoney(o.beforeMinor, o.currency),
                ownerMoney(o.afterMinor, o.currency),
              ),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}

// ---- «تكاليف ثابتة» ---------------------------------------------------------

/// The owner's fixed monthly costs: the list, add, edit and delete.
/// D307 follow-up: «الربح» on its own (the founder's Me tab) — the same
/// view as in «لوحة المؤسس»'s details.
Future<void> showOwnerProfitSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SingleChildScrollView(
        key: OwnerProfitView.sheetKey,
        padding: EdgeInsets.fromLTRB(KSpacing.lg, 0, KSpacing.lg, KSpacing.lg),
        child: OwnerProfitView(),
      ),
    );

Future<void> showFixedCostsEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FixedCostsSheet(),
    );

class FixedCostsSheet extends ConsumerStatefulWidget {
  const new({super.key});

  static const sheetKey = Key('owner.costs');
  static const addKey = Key('owner.costs.add');
  static const emptyKey = Key('owner.costs.empty');
  static Key rowKey(String id) => Key('owner.costs.row.$id');
  static Key editKey(String id) => Key('owner.costs.edit.$id');
  static Key deleteKey(String id) => Key('owner.costs.delete.$id');

  @override
  ConsumerState<FixedCostsSheet> createState() => _FixedCostsSheetState();
}

class _FixedCostsSheetState extends ConsumerState<FixedCostsSheet> {
  bool _busy = false;

  void _changed() {
    ref
      ..invalidate(ownerFixedCostsProvider)
      ..invalidate(ownerProfitProvider);
  }

  Future<void> _edit([OwnerFixedCost? cost]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FixedCostForm(cost: cost),
    );
    if ((saved ?? false) && mounted) _changed();
  }

  Future<void> _delete(OwnerFixedCost cost) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.ownerCostsDeleteConfirm(cost.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.ownerCostsCancel),
          ),
          TextButton(
            key: const Key('owner.costs.deleteConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: ownerLossRed),
            child: Text(l10n.ownerCostsDelete),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(ownerProfileRepositoryProvider).deleteFixedCost(cost.id);
      _changed();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final load = ref.watch(ownerFixedCostsProvider);
    final items = load.value;
    final today = ownerDayKey(clock.now());
    return Padding(
      key: FixedCostsSheet.sheetKey,
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
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: KBrandColors.red500,
              ),
              const SizedBox(width: KSpacing.xs),
              Expanded(child: Text(l10n.ownerProfitFixed, style: t.title)),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
          Text(
            l10n.ownerCostsHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          if (items == null && load.hasError)
            Text(
              l10n.ownerProfitFailed,
              style: t.body.copyWith(color: p.textSecondary),
            )
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(KSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            Padding(
              key: FixedCostsSheet.emptyKey,
              padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
              child: Text(
                l10n.ownerCostsEmpty,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in items)
                    ListTile(
                      key: FixedCostsSheet.rowKey(c.id),
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name, style: t.bodyStrong),
                      subtitle: Text(
                        _costLine(l10n, c, tag, today),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: FixedCostsSheet.editKey(c.id),
                            tooltip: l10n.ownerCostsEdit,
                            onPressed: _busy ? null : () => unawaited(_edit(c)),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            key: FixedCostsSheet.deleteKey(c.id),
                            tooltip: l10n.ownerCostsDelete,
                            onPressed: _busy
                                ? null
                                : () => unawaited(_delete(c)),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: ownerLossRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          FilledButton.icon(
            key: FixedCostsSheet.addKey,
            style: FilledButton.styleFrom(
              backgroundColor: KBrandColors.red500,
              foregroundColor: const Color(0xFFFFFFFF),
            ),
            onPressed: _busy ? null : () => unawaited(_edit()),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.ownerCostsAdd),
          ),
        ],
      ),
    );
  }
}

String _costLine(
  AppLocalizations l10n,
  OwnerFixedCost c,
  String tag,
  String today,
) {
  final amount = l10n.ownerCostsPerMonth(ownerMoney(c.monthlyMinor, 'USD'));
  final from = KFormat.date(ownerDayDate(c.activeFrom), tag);
  final to = c.activeTo == null
      ? l10n.ownerCostsOngoing
      : KFormat.date(ownerDayDate(c.activeTo!), tag);
  final ended = c.activeOn(today) ? '' : ' · ${l10n.ownerCostsEnded}';
  return '$amount · $from – $to$ended';
}

/// Add or edit one fixed cost: the name, the monthly amount in US dollars,
/// from (default today) and an optional end. Pops true when saved.
class FixedCostForm extends ConsumerStatefulWidget {
  const new({super.key, this.cost});

  final OwnerFixedCost? cost;

  static const formKey = Key('owner.costs.form');
  static const nameKey = Key('owner.costs.form.name');
  static const amountKey = Key('owner.costs.form.amount');
  static const fromKey = Key('owner.costs.form.from');
  static const toKey = Key('owner.costs.form.to');
  static const clearToKey = Key('owner.costs.form.clearTo');
  static const saveKey = Key('owner.costs.form.save');

  @override
  ConsumerState<FixedCostForm> createState() => _FixedCostFormState();
}

class _FixedCostFormState extends ConsumerState<FixedCostForm> {
  late final _name = TextEditingController(text: widget.cost?.name);
  late final _amount = TextEditingController(
    text: widget.cost == null
        ? ''
        : (widget.cost!.monthlyMinor / 100).toStringAsFixed(2),
  );
  late String _from = widget.cost?.activeFrom ?? ownerDayKey(clock.now());
  late String? _to = widget.cost?.activeTo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// The amount in cents, or null when it is not a positive number.
  int? get _minor {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  Future<void> _pick({required bool from}) async {
    final initial = ownerDayDate(from ? _from : (_to ?? _from));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: from ? DateTime(2024) : ownerDayDate(_from),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = ownerDayKey(picked);
        if (_to != null && _to!.compareTo(_from) < 0) _to = null;
      } else {
        _to = ownerDayKey(picked);
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final minor = _minor;
    if (name.isEmpty || minor == null) {
      KSnack.error(context, l10n.ownerCostsInvalid);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(ownerProfileRepositoryProvider);
    try {
      final c = widget.cost;
      if (c == null) {
        await repo.createFixedCost(
          name: name,
          monthlyMinor: minor,
          activeFrom: _from,
          activeTo: _to,
        );
      } else {
        await repo.updateFixedCost(
          c.id,
          name: name,
          monthlyMinor: minor,
          activeFrom: _from,
          activeTo: _to,
        );
      }
      if (!mounted) return;
      KSnack.success(context, l10n.ownerCostsSaved);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      key: FixedCostForm.formKey,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.cost == null ? l10n.ownerCostsAdd : l10n.ownerCostsEdit,
              style: t.title,
            ),
            const SizedBox(height: KSpacing.md),
            TextField(
              key: FixedCostForm.nameKey,
              controller: _name,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.ownerCostsName,
                hintText: l10n.ownerCostsNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            TextField(
              key: FixedCostForm.amountKey,
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.ownerCostsMonthly,
                prefixText: r'$ ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: FixedCostForm.fromKey,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_pick(from: true)),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${l10n.ownerCostsFrom}: '
                        '${KFormat.date(ownerDayDate(_from), tag)}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: FixedCostForm.toKey,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_pick(from: false)),
                    icon: const Icon(Icons.event_busy_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _to == null
                            ? l10n.ownerCostsTo
                            : KFormat.date(ownerDayDate(_to!), tag),
                      ),
                    ),
                  ),
                ),
                if (_to != null)
                  IconButton(
                    key: FixedCostForm.clearToKey,
                    tooltip: l10n.ownerCostsOngoing,
                    onPressed: () => setState(() => _to = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.lg),
            FilledButton(
              key: FixedCostForm.saveKey,
              style: FilledButton.styleFrom(
                backgroundColor: KBrandColors.red500,
                foregroundColor: const Color(0xFFFFFFFF),
              ),
              onPressed: _busy ? null : () => unawaited(_save()),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.ownerSave),
            ),
          ],
        ),
      ),
    );
  }
}
