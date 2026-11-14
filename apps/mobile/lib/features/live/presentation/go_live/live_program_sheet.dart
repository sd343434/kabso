import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/data/live_program_repository.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154e («قائمة البرامج», CONVENTIONS §10.37): the host edits the live's
/// program — up to 10 segments, each a start time and a title — and saves
/// the whole list (`PUT …/program`); everyone in the room sees it at once
/// and the server announces each segment when it starts. [startedAt] is
/// the live's start: a picked time is placed on or after it.
Future<void> showLiveProgramEditor(
  BuildContext context, {
  required String roomId,
  required DateTime startedAt,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => LiveProgramEditor(roomId: roomId, startedAt: startedAt),
);

class LiveProgramEditor extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.startedAt, super.key});

  final String roomId;
  final DateTime startedAt;

  static const addKey = Key('program.add');
  static const saveKey = Key('program.save');
  static Key titleKey(int i) => Key('program.title.$i');
  static Key timeKey(int i) => Key('program.time.$i');
  static Key removeKey(int i) => Key('program.remove.$i');

  /// The time a picked [time] of day means for a live that started at
  /// [startedAt]: that day, or the next one when it would be before the
  /// start (a live past midnight).
  static DateTime placeTime(TimeOfDay time, DateTime startedAt) {
    final start = startedAt.toLocal();
    final day = DateTime(
      start.year,
      start.month,
      start.day,
      time.hour,
      time.minute,
    );
    return day.isBefore(start.subtract(const Duration(minutes: 1)))
        ? day.add(const Duration(days: 1))
        : day;
  }

  @override
  ConsumerState<LiveProgramEditor> createState() => _LiveProgramEditorState();
}

class _Draft {
  new(this.startsAt, String title) : title = TextEditingController(text: title);

  DateTime startsAt;
  final TextEditingController title;
}

class _LiveProgramEditorState extends ConsumerState<LiveProgramEditor> {
  final _rows = <_Draft>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final program = ref.read(liveProgramProvider(widget.roomId)).program;
    for (final item in program?.items ?? const <LiveProgramItem>[]) {
      _rows.add(_Draft(item.startsAt.toLocal(), item.title));
    }
    if (_rows.isEmpty) _add();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.title.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (_rows.length >= LiveProgram.maxItems) return;
    final last = _rows.lastOrNull?.startsAt;
    final DateTime at;
    if (last != null) {
      at = last.add(const Duration(minutes: 15));
    } else {
      // The next whole five minutes.
      final now = clock.now();
      final m = (now.minute ~/ 5 + 1) * 5;
      at = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(Duration(minutes: m));
    }
    _rows.add(_Draft(at, ''));
  }

  Future<void> _pick(_Draft row) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(row.startsAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      row.startsAt = LiveProgramEditor.placeTime(time, widget.startedAt);
      _error = null;
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final rows = [
      for (final r in _rows)
        if (r.title.text.trim().isNotEmpty) r,
    ];
    for (var i = 1; i < rows.length; i++) {
      if (!rows[i].startsAt.isAfter(rows[i - 1].startsAt)) {
        setState(() => _error = l10n.liveProgramOrderError);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final program = await ref.read(liveProgramRepositoryProvider).set(
        widget.roomId,
        [
          for (final r in rows)
            (startsAt: r.startsAt, title: r.title.text.trim()),
        ],
      );
      ref.read(liveProgramProvider(widget.roomId).notifier).replace(program);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failureMessage(l10n, toAppFailure(e));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.lg,
            KSpacing.lg,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.liveProgramTitle, style: t.title.copyWith(color: ink)),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.liveProgramEditorHint,
                style: t.caption.copyWith(color: soft),
              ),
              const SizedBox(height: KSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, row) in _rows.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: KSpacing.sm),
                        child: Row(
                          children: [
                            Semantics(
                              button: true,
                              label: l10n.liveProgramTimeLabel(
                                KFormat.time(row.startsAt, locale),
                              ),
                              excludeSemantics: true,
                              child: InkWell(
                                key: LiveProgramEditor.timeKey(i),
                                borderRadius: BorderRadius.circular(10),
                                onTap: _saving
                                    ? null
                                    : () => unawaited(_pick(row)),
                                child: Container(
                                  width: 84,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    KFormat.bidiIsolate(
                                      KFormat.time(row.startsAt, locale),
                                    ),
                                    style: t.bodyStrong.copyWith(
                                      color: ink,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: KSpacing.sm),
                            Expanded(
                              child: TextField(
                                key: LiveProgramEditor.titleKey(i),
                                controller: row.title,
                                enabled: !_saving,
                                maxLength: LiveProgram.titleMax,
                                maxLengthEnforcement:
                                    MaxLengthEnforcement.enforced,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                    RegExp('[\n\r]'),
                                  ),
                                ],
                                style: t.body.copyWith(color: ink),
                                decoration: InputDecoration(
                                  hintText: l10n.liveProgramTitleHint,
                                  counterText: '',
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFFF5F7FB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              key: LiveProgramEditor.removeKey(i),
                              tooltip: l10n.liveProgramRemove,
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _rows.removeAt(i).title.dispose();
                                      _error = null;
                                    }),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: soft,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_rows.length < LiveProgram.maxItems)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: LiveProgramEditor.addKey,
                    onPressed: _saving ? null : () => setState(_add),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.liveProgramAdd),
                  ),
                ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: Text(
                    error,
                    style: t.caption.copyWith(color: const Color(0xFFD93A4A)),
                  ),
                ),
              KButton(
                key: LiveProgramEditor.saveKey,
                label: l10n.liveProgramSave,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
