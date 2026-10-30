import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shared parts of the recharge-agent screens (D185).

/// A raised card of the theme (the Me pages' look).
class RechargeCard extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// A short line with an icon (rules, privacy, warnings).
class RechargeNotice extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    super.key,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final color = warning ? p.error : p.textSecondary;
    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceOverlay,
        borderRadius: BorderRadius.circular(KRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: KSpacing.xs),
          Expanded(
            child: Text(text, style: t.caption.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// A row that opens another page or sheet.
class RechargeNavRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.xs),
      child: Material(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, color: p.primary),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      if (subtitle case final s?)
                        Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: p.textSecondary),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: p.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «في الدوام الآن» / «خارج الدوام».
class RechargeShiftChip extends StatelessWidget {
  const new({required this.onShift, super.key});

  final bool onShift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final color = onShift ? const Color(0xFF1E9E5A) : const Color(0xFF8A8F98);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        onShift ? l10n.rechargeOnShift : l10n.rechargeOffShift,
        style: t.caption.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The short name of an ISO weekday (1 = Monday … 7 = Sunday).
String rechargeDayName(AppLocalizations l10n, int day) => switch (day) {
  1 => l10n.rechargeDay1,
  2 => l10n.rechargeDay2,
  3 => l10n.rechargeDay3,
  4 => l10n.rechargeDay4,
  5 => l10n.rechargeDay5,
  6 => l10n.rechargeDay6,
  _ => l10n.rechargeDay7,
};

/// «السبت، الأحد · 10:00–18:00» (+ the zone when given).
String rechargeSlotText(
  BuildContext context,
  WeeklySlot slot, {
  String? timeZone,
}) {
  final l10n = context.l10n;
  final days = [for (final d in slot.days) rechargeDayName(l10n, d)].join('، ');
  final hours = KFormat.bidiIsolate('${slot.start}–${slot.end}');
  return timeZone == null
      ? '$days · $hours'
      : '$days · $hours (${KFormat.bidiIsolate(timeZone)})';
}

/// The time zones offered (the agents' region first; IANA names).
const rechargeTimeZones = [
  'Africa/Cairo',
  'Asia/Riyadh',
  'Asia/Dubai',
  'Asia/Baghdad',
  'Asia/Amman',
  'Asia/Beirut',
  'Asia/Damascus',
  'Asia/Kuwait',
  'Asia/Qatar',
  'Asia/Bahrain',
  'Asia/Muscat',
  'Asia/Aden',
  'Asia/Gaza',
  'Africa/Algiers',
  'Africa/Casablanca',
  'Africa/Tunis',
  'Africa/Tripoli',
  'Africa/Khartoum',
  'Europe/Istanbul',
  'Europe/London',
  'UTC',
];

/// Edits one weekly slot: the days, start and end, and (for availability)
/// the WhatsApp number and payment method.
class RechargeSlotEditor extends StatefulWidget {
  const new({
    required this.slot,
    required this.onChanged,
    required this.onRemove,
    super.key,
    this.withContact = false,
  });

  final WeeklySlot slot;
  final ValueChanged<WeeklySlot> onChanged;
  final VoidCallback onRemove;
  final bool withContact;

  @override
  State<RechargeSlotEditor> createState() => _RechargeSlotEditorState();
}

class _RechargeSlotEditorState extends State<RechargeSlotEditor> {
  late final _whatsapp = TextEditingController(text: widget.slot.whatsapp);
  late final _method = TextEditingController(text: widget.slot.paymentMethod);

  @override
  void dispose() {
    _whatsapp.dispose();
    _method.dispose();
    super.dispose();
  }

  void _emit({List<int>? days, String? start, String? end}) => widget.onChanged(
    WeeklySlot(
      days: days ?? widget.slot.days,
      start: start ?? widget.slot.start,
      end: end ?? widget.slot.end,
      whatsapp: widget.withContact ? _whatsapp.text.trim() : null,
      paymentMethod: widget.withContact ? _method.text.trim() : null,
    ),
  );

  Future<void> _time(bool start) async {
    final current = start ? widget.slot.start : widget.slot.end;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]) % 24,
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    // The end may be midnight (24:00) of the same day.
    final value = !start && v == '00:00' ? '24:00' : v;
    _emit(start: start ? value : null, end: start ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(rechargeDayName(l10n, d)),
                  selected: widget.slot.days.contains(d),
                  onSelected: (on) {
                    final days = {...widget.slot.days};
                    if (on) {
                      days.add(d);
                    } else if (days.length > 1) {
                      days.remove(d);
                    }
                    _emit(days: days.toList()..sort());
                  },
                ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Row(
            children: [
              Text(l10n.rechargeFrom, style: t.caption),
              TextButton(
                onPressed: () => unawaited(_time(true)),
                child: Text(
                  widget.slot.start,
                  textDirection: TextDirection.ltr,
                ),
              ),
              Text(l10n.rechargeTo, style: t.caption),
              TextButton(
                onPressed: () => unawaited(_time(false)),
                child: Text(widget.slot.end, textDirection: TextDirection.ltr),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.rechargeRemove,
                icon: Icon(Icons.delete_outline_rounded, color: p.error),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          if (widget.withContact) ...[
            KTextField(
              label: l10n.rechargeWhatsapp,
              helperText: l10n.rechargePhoneHint,
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: KSpacing.xs),
            KTextField(
              label: l10n.rechargePaymentNow,
              controller: _method,
              maxLength: 80,
              onChanged: (_) => _emit(),
            ),
          ],
        ],
      ),
    );
  }
}

/// A zone picker over [rechargeTimeZones] (the current one kept).
class RechargeZoneField extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final zones = {value, ...rechargeTimeZones}.toList();
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.l10n.rechargeTimeZone),
      items: [
        for (final z in zones)
          DropdownMenuItem(
            value: z,
            child: Text(z, textDirection: TextDirection.ltr),
          ),
      ],
      onChanged: (z) {
        if (z != null) onChanged(z);
      },
    );
  }
}

/// «أوقات التواصل وطرق الدفع»: the agent's weekly slots with the WhatsApp
/// number and payment method of each (public in the directory).
Future<void> showRechargeAvailabilitySheet(
  BuildContext context,
  WidgetRef ref,
  RechargeAvailability current,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => RechargeAvailabilitySheet(current: current),
);

class RechargeAvailabilitySheet extends ConsumerStatefulWidget {
  const new({required this.current, super.key});

  final RechargeAvailability current;

  static const saveKey = Key('recharge.availability.save');
  static const addKey = Key('recharge.availability.add');

  @override
  ConsumerState<RechargeAvailabilitySheet> createState() =>
      _RechargeAvailabilitySheetState();
}

class _RechargeAvailabilitySheetState
    extends ConsumerState<RechargeAvailabilitySheet> {
  late String _zone = widget.current.timeZone;
  late final List<WeeklySlot> _slots = [...widget.current.slots];
  int _version = 0;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(rechargeRepositoryProvider)
          .setAvailability(
            RechargeAvailability(timeZone: _zone, slots: _slots),
          );
      if (!mounted) return;
      ref.invalidate(myRechargeAgentProvider);
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(KSpacing.lg),
            children: [
              Text(
                l10n.rechargeAvailabilityTitle,
                textAlign: TextAlign.center,
                style: t.title.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: KSpacing.xs),
              RechargeNotice(
                icon: Icons.public_rounded,
                text: l10n.rechargeAvailabilityNote,
              ),
              const SizedBox(height: KSpacing.sm),
              RechargeZoneField(
                value: _zone,
                onChanged: (z) => setState(() => _zone = z),
              ),
              const SizedBox(height: KSpacing.sm),
              for (final (i, s) in _slots.indexed)
                RechargeSlotEditor(
                  key: ValueKey('slot.$_version.$i'),
                  slot: s,
                  withContact: true,
                  onChanged: (v) => setState(() => _slots[i] = v),
                  onRemove: () => setState(() {
                    _slots.removeAt(i);
                    _version++;
                  }),
                ),
              if (_slots.length < 28)
                TextButton.icon(
                  key: RechargeAvailabilitySheet.addKey,
                  onPressed: () => setState(
                    () => _slots.add(
                      const WeeklySlot(
                        days: [1, 2, 3, 4, 5, 6, 7],
                        start: '10:00',
                        end: '22:00',
                        whatsapp: '',
                        paymentMethod: '',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.rechargeAddSlot),
                ),
              if (_error case final e?)
                Padding(
                  padding: const EdgeInsets.only(top: KSpacing.xs),
                  child: Text(e, style: t.caption.copyWith(color: p.error)),
                ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: RechargeAvailabilitySheet.saveKey,
                label: l10n.rechargeSave,
                loading: _busy,
                onPressed: _busy ? null : () => unawaited(_save()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Digits only, for amount fields.
final List<TextInputFormatter> rechargeDigits = [
  FilteringTextInputFormatter.digitsOnly,
];
