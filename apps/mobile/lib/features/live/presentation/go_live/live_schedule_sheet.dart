import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the live schedule sheet (tests and captures).
abstract final class LiveScheduleKeys {
  static const add = Key('schedule.add');
  static const title = Key('schedule.title');
  static const pick = Key('schedule.pick');
  static const save = Key('schedule.save');
  static const count = Key('schedule.count');
  static Key slot(String id) => Key('schedule.slot.$id');
  static Key remove(String id) => Key('schedule.remove.$id');
}

/// The host's live schedule (CP-016 C, ref 71 "Live schedule"): the
/// upcoming lives, soonest first, each with ✕ to cancel, n/10, and "Schedule
/// a live" (a title and a date and time 15 minutes to 30 days ahead). The
/// server reminds the host's followers 15 minutes before each start; going
/// live stays the host's own action.
Future<void> showLiveSchedule(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      barrierColor: const Color(0x00000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ScheduleSheet(),
    );

class _ScheduleSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  final _title = TextEditingController();
  DateTime? _at;
  bool _adding = false;
  bool _saving = false;
  String? _timeError;

  static const _ink = Color(0xFF1C1B1F);
  static const _soft = Color(0xFF7A7B8C);
  static const _field = Color(0xFFF3F3F3);

  /// Kabso's red (the brand identity, not a reference's colour).
  static const Color _accent = KBrandColors.red500;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _localeTag() => Localizations.localeOf(context).toLanguageTag();

  String _when(DateTime at) => context.l10n.liveScheduleWhen(
    KFormat.date(at, _localeTag()),
    KFormat.time(at, _localeTag()),
  );

  /// Too soon or too far, as the server checks it (it stays the authority).
  String? _check(DateTime at) {
    final now = clock.now();
    if (at.isBefore(now.add(liveScheduleMinLead))) {
      return context.l10n.liveScheduleTooSoon;
    }
    if (at.isAfter(now.add(liveScheduleMaxLead))) {
      return context.l10n.liveScheduleTooFar;
    }
    return null;
  }

  Future<void> _pick() async {
    final now = clock.now();
    final first = now.add(liveScheduleMinLead + const Duration(minutes: 5));
    final initial = _at ?? first;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(liveScheduleMaxLead),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      _at = at;
      _timeError = _check(at);
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    final at = _at;
    if (title.isEmpty || at == null || _saving) return;
    final error = _check(at);
    if (error != null) {
      setState(() => _timeError = error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(liveScheduleRepositoryProvider)
          .create(title: title, startsAt: at);
      ref.invalidate(liveScheduleProvider);
      await ref.read(liveScheduleProvider.future);
      if (mounted) {
        setState(() {
          _adding = false;
          _at = null;
          _timeError = null;
          _title.clear();
        });
      }
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(String id) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(liveScheduleRepositoryProvider).remove(id);
      ref.invalidate(liveScheduleProvider);
      await ref.read(liveScheduleProvider.future);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String hint) {
    final text = context.textStyles;
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      counterText: '',
      // A light field on the white sheet (the app's dark input theme would
      // show a black box).
      filled: true,
      fillColor: _field,
      hintStyle: text.body.copyWith(color: _soft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: shape,
      enabledBorder: shape,
      focusedBorder: shape.copyWith(
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }

  Widget _form() {
    final l10n = context.l10n;
    final text = context.textStyles;
    final at = _at;
    final ready =
        !_saving &&
        _title.text.trim().isNotEmpty &&
        at != null &&
        _timeError == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: LiveScheduleKeys.title,
            controller: _title,
            maxLength: maxLiveScheduleTitleLength,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp('[\n\r  ]')),
            ],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            style: text.body.copyWith(color: _ink),
            decoration: _decoration(l10n.liveScheduleTitleHint),
          ),
          const SizedBox(height: 10),
          Material(
            color: _field,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: LiveScheduleKeys.pick,
              borderRadius: BorderRadius.circular(12),
              onTap: _saving ? null : _pick,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 20, color: _soft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        at == null ? l10n.liveSchedulePickTime : _when(at),
                        style: text.body.copyWith(
                          color: at == null ? _soft : _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_timeError case final error?)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
              child: Text(
                error,
                style: text.caption.copyWith(color: const Color(0xFFE5484D)),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: LiveScheduleKeys.save,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: const Color(0xFFFFFFFF),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: ready ? _save : null,
            child: Text(l10n.liveScheduleSave),
          ),
        ],
      ),
    );
  }

  Widget _slot(LiveScheduleSlot s) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Padding(
      key: LiveScheduleKeys.slot(s.id),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_rounded, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  KFormat.bidiIsolate(s.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong.copyWith(color: _ink),
                ),
                const SizedBox(height: 2),
                Text(
                  _when(s.startsAt),
                  style: text.caption.copyWith(color: _soft),
                ),
              ],
            ),
          ),
          IconButton(
            key: LiveScheduleKeys.remove(s.id),
            tooltip: l10n.liveScheduleRemove(s.title),
            onPressed: _saving ? null : () => _remove(s.id),
            icon: const Icon(Icons.close_rounded, color: _soft),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final slots = ref.watch(liveScheduleProvider);
    final list = slots.value ?? const <LiveScheduleSlot>[];
    final full = list.length >= maxLiveScheduleSlots;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveWhiteSheetHeader(
                title: l10n.liveSettingsSchedule,
                centred: true,
                titleTop: 15.6,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
                child: Text(
                  l10n.liveScheduleHint,
                  style: text.caption.copyWith(color: _soft, fontSize: 13),
                ),
              ),
              if (_adding) _form(),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 20, 2),
                child: Text(
                  '${list.length}/$maxLiveScheduleSlots',
                  key: LiveScheduleKeys.count,
                  style: text.caption.copyWith(color: _soft),
                ),
              ),
              Expanded(
                child: switch (slots) {
                  AsyncData(:final value) when value.isEmpty => Center(
                    child: Text(
                      l10n.liveScheduleEmpty,
                      style: text.body.copyWith(color: _soft),
                    ),
                  ),
                  AsyncData(:final value) => ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [for (final s in value) _slot(s)],
                  ),
                  AsyncError(:final error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        failureMessage(l10n, toAppFailure(error)),
                        textAlign: TextAlign.center,
                        style: text.body.copyWith(color: _soft),
                      ),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              if (!_adding)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: FilledButton.icon(
                    key: LiveScheduleKeys.add,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFFFFFFFF),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: slots.hasValue && !full
                        ? () => setState(() => _adding = true)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      full ? l10n.errorLiveScheduleFull : l10n.liveScheduleAdd,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
