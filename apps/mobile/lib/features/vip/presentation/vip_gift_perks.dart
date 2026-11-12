import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/vip/application/vip_gift_perks_providers.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// v1.134-social (D381, CONVENTIONS §10.171): «الخاص بي VIP»'s rows for the
// gift, CP, support, rocket and voice perks, and «هدية مؤجلة» — the member's
// scheduled gifts (schedule, list, cancel).

/// What the member's D381 perks give now — one row per held perk; nothing
/// while loading, on an error or without any of them.
class VipPerksNowSection extends StatelessWidget {
  const new({required this.now, super.key, this.onOpenScheduled});

  /// `MyVip.perksNow` (null: an older API — nothing shown).
  final VipPerksNow? now;

  static const sectionKey = Key('vip.now');
  static Key rowKey(String code) => Key('vip.now.$code');
  static const scheduledKey = Key('vip.now.SCHEDULED_GIFT');

  /// Opens «هدية مؤجلة» (the sheet closes itself first).
  final VoidCallback? onOpenScheduled;

  @override
  Widget build(BuildContext context) {
    final now = this.now;
    if (now == null || now.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    Widget row(String code, IconData icon, String text, [String? sub]) =>
        ListTile(
          key: rowKey(code),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: context.palette.primary),
          title: Text(text),
          subtitle: sub == null ? null : Text(sub),
        );
    return Column(
      key: sectionKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: KSpacing.sm),
          child: Text(l10n.vipNowTitle, style: context.textStyles.bodyStrong),
        ),
        if (now.monthlyRockets case final r?)
          row(
            'MONTHLY_ROCKETS',
            Icons.rocket_launch_outlined,
            l10n.vipNowRockets('${r.count}', '${r.minutes}'),
            l10n.vipNowRocketsNext(KFormat.date(r.nextAt.toLocal(), localeTag)),
          ),
        if (now.freeCpRequests case final f?)
          row(
            'FREE_CP_REQUEST',
            Icons.favorite_border,
            l10n.vipNowFreeCp('${f.left}', '${f.perMonth}'),
          ),
        if (now.exclusiveGifts case final n?)
          row(
            'EXCLUSIVE_GIFTS',
            Icons.card_giftcard_outlined,
            l10n.vipNowExclusive('$n'),
          ),
        if (now.maxGiftQuantity case final q?)
          row(
            'HIGHER_GIFT_QUANTITY',
            Icons.layers_outlined,
            l10n.vipNowMaxQuantity(KFormat.grouped(q)),
          ),
        if (now.voiceSeconds case final s?)
          row('LONGER_VOICE', Icons.mic_none, l10n.vipNowVoice('$s')),
        if (now.prioritySupport)
          row(
            'PRIORITY_SUPPORT',
            Icons.support_agent_outlined,
            l10n.vipNowPriority,
          ),
        if (now.scheduledGifts)
          ListTile(
            key: scheduledKey,
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.schedule_send_outlined,
              color: context.palette.primary,
            ),
            title: Text(l10n.vipScheduledEntry),
            subtitle: Text(
              l10n.vipScheduledEntrySub(
                '${now.scheduledPending}',
                '${now.scheduledMax}',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenScheduled,
          ),
      ],
    );
  }
}

/// «هدية مؤجلة» (SCHEDULED_GIFT, §10.171.5): the member's scheduled gifts —
/// the waiting ones first with «إلغاء الهدية», then the others with their
/// outcome — and «جدولة هدية».
class VipScheduledGiftsScreen extends ConsumerWidget {
  const new({super.key});

  static const listKey = Key('vip.scheduled.list');
  static const emptyKey = Key('vip.scheduled.empty');
  static const newKey = Key('vip.scheduled.new');
  static Key cancelKey(String id) => Key('vip.scheduled.cancel.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(vipScheduledGiftsProvider);
    final full = switch (list) {
      AsyncData(:final value) => value.pending >= value.maxPending,
      _ => true,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vipScheduledEntry)),
      floatingActionButton: FloatingActionButton.extended(
        key: newKey,
        onPressed: full
            ? null
            : () => unawaited(showVipScheduleSheet(context, ref)),
        icon: const Icon(Icons.add),
        label: Text(l10n.vipScheduledNew),
      ),
      body: SafeArea(
        child: switch (list) {
          AsyncData(:final value) when value.data.isEmpty => KEmptyState(
            key: emptyKey,
            icon: Icons.schedule_send_outlined,
            title: l10n.vipScheduledEmptyTitle,
            message: l10n.vipScheduledEmptyBody,
          ),
          AsyncData(:final value) => ListView.separated(
            key: listKey,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              96,
            ),
            itemCount: value.data.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _Row(gift: value.data[i]),
          ),
          AsyncError(:final error) => KErrorState(
            title: l10n.vipScheduledEntry,
            message: failureMessage(l10n, toAppFailure(error)),
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.invalidate(vipScheduledGiftsProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const new({required this.gift});

  final VipScheduledGift gift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final at = gift.deliverAt.toLocal();
    final name = switch (gift.to) {
      final u? => u.displayName.isEmpty ? u.username : u.displayName,
      null => '—',
    };
    final status = switch (gift.status) {
      VipScheduledGiftStatus.pending => l10n.vipScheduledStatusPending,
      VipScheduledGiftStatus.delivered => l10n.vipScheduledStatusDelivered,
      VipScheduledGiftStatus.cancelled => l10n.vipScheduledStatusCancelled,
      VipScheduledGiftStatus.failed => l10n.vipScheduledStatusFailed,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.card_giftcard_outlined),
      title: Text(
        l10n.vipScheduledLine(
          KFormat.grouped(gift.quantity),
          gift.gift?.name ?? gift.giftCode,
          name,
        ),
      ),
      subtitle: Text(l10n.vipScheduledMeta(_when(at, localeTag), status)),
      trailing: gift.status == VipScheduledGiftStatus.pending
          ? TextButton(
              key: VipScheduledGiftsScreen.cancelKey(gift.id),
              onPressed: () => unawaited(_cancel(context, ref)),
              child: Text(l10n.vipScheduledCancel),
            )
          : null,
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final r = await ref.read(vipGiftPerksRepositoryProvider).cancel(gift.id);
      if (!context.mounted) return;
      showCoins(ref, r.coins);
      ref
        ..invalidate(vipScheduledGiftsProvider)
        ..invalidate(myVipProvider);
      KSnack.success(context, l10n.vipScheduledCancelled);
    } on Object catch (e) {
      if (!context.mounted) return;
      ref.invalidate(vipScheduledGiftsProvider);
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// Whether [gift] can be scheduled (the server checks again): a paid gift of
/// a normal tab — not lucky, a quip, custom or a PK booster.
bool vipSchedulable(Gift gift) =>
    gift.priceCoins > 0 &&
    gift.pkBooster == null &&
    gift.category != GiftCategory.lucky &&
    gift.category != GiftCategory.quips &&
    gift.category != GiftCategory.custom;

/// «جدولة هدية»: the recipient's username, the gift, the quantity (the
/// caller's, VIP ones included) and the time; [initialTo] prefills the
/// recipient. Returns true when scheduled.
Future<bool> showVipScheduleSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialTo,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => VipScheduleForm(initialTo: initialTo),
  );
  return done ?? false;
}

/// The «جدولة هدية» form (in a sheet).
class VipScheduleForm extends ConsumerStatefulWidget {
  const new({super.key, this.initialTo});

  final String? initialTo;

  static const toKey = Key('vip.schedule.to');
  static const giftKey = Key('vip.schedule.gift');
  static const quantityKey = Key('vip.schedule.quantity');
  static const whenKey = Key('vip.schedule.when');
  static const submitKey = Key('vip.schedule.submit');

  @override
  ConsumerState<VipScheduleForm> createState() => _VipScheduleFormState();
}

class _VipScheduleFormState extends ConsumerState<VipScheduleForm> {
  late final TextEditingController _to = TextEditingController(
    text: widget.initialTo ?? '',
  );
  String? _gift;
  int _quantity = 1;

  /// The quantity the form shows (the picked one when allowed, else the
  /// first allowed); what is sent.
  int _shown = 1;
  DateTime? _at;
  bool _busy = false;

  /// One `clientId` per filled form: a retry never holds coins twice.
  final String _clientId = newClientId();

  @override
  void dispose() {
    _to.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = clock.now();
    final first = _at ?? now.add(const Duration(hours: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(first),
    );
    if (time == null || !mounted) return;
    setState(
      () =>
          _at = DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final to = _to.text.trim().replaceFirst('@', '');
    final gift = _gift;
    final at = _at;
    if (to.isEmpty || gift == null || at == null) return;
    if (at.difference(clock.now()) < const Duration(minutes: 5)) {
      KSnack.error(context, l10n.vipScheduledBadTime);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(vipGiftPerksRepositoryProvider)
          .schedule(
            to: to,
            giftCode: gift,
            quantity: _shown,
            deliverAt: at,
            clientId: _clientId,
          );
      if (!mounted) return;
      showCoins(ref, r.coins);
      ref
        ..invalidate(vipScheduledGiftsProvider)
        ..invalidate(myVipProvider);
      KSnack.success(context, l10n.vipScheduledDone);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      final issue = failure is ServerFailure
          ? failure.details.firstOrNull?.issue
          : null;
      KSnack.error(context, switch (issue) {
        'too_many' => l10n.vipScheduledTooMany,
        'out_of_range' => l10n.vipScheduledBadTime,
        'no_perk' => l10n.vipScheduledNoPerkTitle,
        _ => failureMessage(l10n, failure),
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final gifts = [
      for (final g in catalogue?.data ?? const <Gift>[])
        if (vipSchedulable(g)) g,
    ];
    final quantities = [
      ...?catalogue?.quantities,
      ...?catalogue?.vipQuantities,
    ];
    final quantity = quantities.contains(_quantity)
        ? _quantity
        : (quantities.firstOrNull ?? 1);
    _shown = quantity;
    final picked = gifts.where((g) => g.code == _gift).firstOrNull;
    final at = _at;
    return Padding(
      padding: EdgeInsets.only(
        left: KSpacing.lg,
        right: KSpacing.lg,
        top: KSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + KSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.vipScheduledNew, style: context.textStyles.title),
            const SizedBox(height: KSpacing.md),
            TextField(
              key: VipScheduleForm.toKey,
              controller: _to,
              decoration: InputDecoration(labelText: l10n.vipScheduledTo),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpacing.sm),
            DropdownButtonFormField<String>(
              key: VipScheduleForm.giftKey,
              initialValue: picked?.code,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.vipScheduledGift),
              items: [
                for (final g in gifts)
                  DropdownMenuItem(
                    value: g.code,
                    child: Text(
                      l10n.vipScheduledGiftOption(
                        g.name,
                        KFormat.grouped(g.priceCoins),
                      ),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _gift = v),
            ),
            const SizedBox(height: KSpacing.sm),
            DropdownButtonFormField<int>(
              key: VipScheduleForm.quantityKey,
              initialValue: quantity,
              decoration: InputDecoration(labelText: l10n.vipScheduledQuantity),
              items: [
                for (final q in quantities)
                  DropdownMenuItem(value: q, child: Text(KFormat.grouped(q))),
              ],
              onChanged: (v) => setState(() => _quantity = v ?? 1),
            ),
            const SizedBox(height: KSpacing.sm),
            ListTile(
              key: VipScheduleForm.whenKey,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.vipScheduledWhen),
              subtitle: at == null ? null : Text(_when(at, localeTag)),
              onTap: () => unawaited(_pickTime()),
            ),
            if (picked != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Text(
                  l10n.vipScheduledHold(
                    KFormat.grouped(picked.priceCoins * quantity),
                  ),
                  style: context.textStyles.caption,
                ),
              ),
            FilledButton(
              key: VipScheduleForm.submitKey,
              onPressed:
                  _busy ||
                      picked == null ||
                      at == null ||
                      _to.text.trim().isEmpty
                  ? null
                  : () => unawaited(_submit()),
              child: Text(l10n.vipScheduledSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

/// A time as the page shows it: the date, then the time.
String _when(DateTime at, String localeTag) =>
    '${KFormat.date(at, localeTag)} ${KFormat.time(at, localeTag)}';

/// Opens «هدية مؤجلة».
void openVipScheduledGifts(BuildContext context) =>
    unawaited(context.push(AppRoutes.vipScheduledGifts));
