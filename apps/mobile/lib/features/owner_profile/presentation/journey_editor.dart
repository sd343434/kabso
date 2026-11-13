import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.3; owner: «في التطبيق»): the owner edits
/// «رحلة Kabso» from his own profile — add, edit (a sheet form in Arabic and
/// English), delete, and reorder by drag or ▲ / ▼. Every change goes to the
/// API at once (owner only); the timeline refreshes after.
Future<void> showJourneyEditor(
  BuildContext context, {
  required String username,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => JourneyEditorSheet(username: username),
);

class JourneyEditorSheet extends ConsumerStatefulWidget {
  const new({required this.username, super.key});

  final String username;

  static const sheetKey = Key('owner.journey.editor');
  static const addKey = Key('owner.journey.add');
  static Key rowKey(String id) => Key('owner.journey.editor.$id');
  static Key upKey(String id) => Key('owner.journey.up.$id');
  static Key downKey(String id) => Key('owner.journey.down.$id');
  static Key editKey(String id) => Key('owner.journey.editRow.$id');
  static Key deleteKey(String id) => Key('owner.journey.delete.$id');

  @override
  ConsumerState<JourneyEditorSheet> createState() => _JourneyEditorSheetState();
}

class _JourneyEditorSheetState extends ConsumerState<JourneyEditorSheet> {
  List<JourneyMilestone>? _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final items = await _guard(
      () => ref.read(ownerProfileRepositoryProvider).journey(widget.username),
    );
    if (items != null && mounted) setState(() => _items = items);
  }

  Future<T?> _guard<T>(Future<T> Function() run) async {
    setState(() => _busy = true);
    try {
      return await run();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed() => ref.invalidate(ownerJourneyProvider(widget.username));

  Future<void> _reorder(List<JourneyMilestone> next) async {
    final before = _items;
    setState(() => _items = next);
    final saved = await _guard(
      () => ref.read(ownerProfileRepositoryProvider).reorder([
        for (final m in next) m.id,
      ]),
    );
    if (!mounted) return;
    setState(() => _items = saved ?? before);
    if (saved != null) _changed();
  }

  void _move(int from, int to) {
    final items = [...?_items];
    if (to < 0 || to >= items.length) return;
    items.insert(to, items.removeAt(from));
    unawaited(_reorder(items));
  }

  Future<void> _edit([JourneyMilestone? milestone]) async {
    final draft = await showMilestoneForm(context, milestone: milestone);
    if (draft == null || !mounted) return;
    final repo = ref.read(ownerProfileRepositoryProvider);
    final saved = await _guard(
      () => milestone == null
          ? repo.createMilestone(draft)
          : repo.updateMilestone(draft),
    );
    if (saved == null || !mounted) return;
    _changed();
    await _load();
  }

  Future<void> _delete(JourneyMilestone m) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.ownerJourneyDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('owner.journey.deleteConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.ownerDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _guard(() async {
      await ref.read(ownerProfileRepositoryProvider).deleteMilestone(m.id);
      return true;
    });
    if (done == null || !mounted) return;
    _changed();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lang = Localizations.localeOf(context).languageCode;
    final items = _items;
    final full = (items?.length ?? 0) >= ownerJourneyMax;
    return SizedBox(
      key: JourneyEditorSheet.sheetKey,
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.ownerJourneyEditorTitle, style: t.title),
                ),
                FilledButton.icon(
                  key: JourneyEditorSheet.addKey,
                  onPressed: _busy || full || items == null
                      ? null
                      : () => unawaited(_edit()),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.ownerJourneyAdd),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.xs,
              KSpacing.lg,
              KSpacing.sm,
            ),
            child: Text(
              l10n.ownerJourneyEditorHint(ownerJourneyMax),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Text(
                      l10n.ownerJourneyEmptyOwn,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorderItem: (from, to) {
                      final next = [...items];
                      next.insert(to, next.removeAt(from));
                      unawaited(_reorder(next));
                    },
                    itemBuilder: (context, i) {
                      final m = items[i];
                      return Card(
                        key: JourneyEditorSheet.rowKey(m.id),
                        margin: const EdgeInsets.symmetric(
                          vertical: KSpacing.xs,
                        ),
                        elevation: 0,
                        color: p.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadius.md),
                          side: BorderSide(color: p.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: KSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.all(KSpacing.xs),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    color: p.textTertiary,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: m.icon.deep,
                                child: Icon(
                                  m.icon.icon,
                                  size: 16,
                                  color: const Color(0xFFFFFFFF),
                                ),
                              ),
                              const SizedBox(width: KSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.title(lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodyStrong,
                                    ),
                                    Text(
                                      [
                                        journeyDate(context, m.year, m.month),
                                        if (m.latest) l10n.ownerJourneyLatest,
                                      ].join(' · '),
                                      style: t.caption.copyWith(
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: JourneyEditorSheet.upKey(m.id),
                                tooltip: l10n.ownerMoveUp,
                                onPressed: _busy || i == 0
                                    ? null
                                    : () => _move(i, i - 1),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                              IconButton(
                                key: JourneyEditorSheet.downKey(m.id),
                                tooltip: l10n.ownerMoveDown,
                                onPressed: _busy || i == items.length - 1
                                    ? null
                                    : () => _move(i, i + 1),
                                icon: const Icon(Icons.arrow_downward_rounded),
                              ),
                              PopupMenuButton<bool>(
                                tooltip: l10n.feedPostMore,
                                onSelected: (edit) =>
                                    unawaited(edit ? _edit(m) : _delete(m)),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    key: JourneyEditorSheet.editKey(m.id),
                                    value: true,
                                    child: Text(l10n.ownerEdit),
                                  ),
                                  PopupMenuItem(
                                    key: JourneyEditorSheet.deleteKey(m.id),
                                    value: false,
                                    child: Text(l10n.ownerDelete),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The milestone's form (a sheet): the title and the line in Arabic and
/// English, the month and the year, the icon and «الأحدث». Returns the
/// draft (with [milestone]'s id when editing), or null when cancelled.
Future<JourneyMilestone?> showMilestoneForm(
  BuildContext context, {
  JourneyMilestone? milestone,
}) => showModalBottomSheet<JourneyMilestone>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => MilestoneForm(milestone: milestone),
);

class MilestoneForm extends StatefulWidget {
  const new({super.key, this.milestone});

  final JourneyMilestone? milestone;

  static const formKey = Key('owner.milestone.form');
  static const titleArKey = Key('owner.milestone.titleAr');
  static const titleEnKey = Key('owner.milestone.titleEn');
  static const lineArKey = Key('owner.milestone.lineAr');
  static const lineEnKey = Key('owner.milestone.lineEn');
  static const monthKey = Key('owner.milestone.month');
  static const yearKey = Key('owner.milestone.year');
  static const latestKey = Key('owner.milestone.latest');
  static const saveKey = Key('owner.milestone.save');
  static Key iconKey(JourneyIcon icon) =>
      Key('owner.milestone.icon.${icon.name}');

  @override
  State<MilestoneForm> createState() => _MilestoneFormState();
}

class _MilestoneFormState extends State<MilestoneForm> {
  late final _titleAr = TextEditingController(text: widget.milestone?.titleAr);
  late final _titleEn = TextEditingController(text: widget.milestone?.titleEn);
  late final _lineAr = TextEditingController(text: widget.milestone?.lineAr);
  late final _lineEn = TextEditingController(text: widget.milestone?.lineEn);
  late int _month = widget.milestone?.month ?? clock.now().month;
  late int _year = widget.milestone?.year ?? clock.now().year;
  late JourneyIcon _icon = widget.milestone?.icon ?? JourneyIcon.rocket;
  late bool _latest = widget.milestone?.latest ?? false;
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _lineAr.dispose();
    _lineEn.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? context.l10n.ownerFieldRequired : null;

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    String? line(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.of(context).pop(
      JourneyMilestone(
        id: widget.milestone?.id ?? '',
        titleAr: _titleAr.text.trim(),
        titleEn: _titleEn.text.trim(),
        lineAr: line(_lineAr),
        lineEn: line(_lineEn),
        year: _year,
        month: _month,
        icon: _icon,
        latest: _latest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final years = [for (var y = 2020; y <= clock.now().year + 5; y++) y];
    if (!years.contains(_year)) years.add(_year);
    Widget field(
      Key key,
      TextEditingController c,
      String label,
      int max, {
      bool required = false,
      TextDirection? direction,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: TextFormField(
        key: key,
        controller: c,
        maxLength: max,
        textDirection: direction,
        validator: required ? _required : null,
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: MilestoneForm.formKey,
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.milestone == null
                    ? l10n.ownerJourneyAdd
                    : l10n.ownerJourneyEditOne,
                style: t.title,
              ),
              const SizedBox(height: KSpacing.md),
              field(
                MilestoneForm.titleArKey,
                _titleAr,
                l10n.ownerMilestoneTitleAr,
                60,
                required: true,
                direction: TextDirection.rtl,
              ),
              field(
                MilestoneForm.titleEnKey,
                _titleEn,
                l10n.ownerMilestoneTitleEn,
                60,
                required: true,
                direction: TextDirection.ltr,
              ),
              field(
                MilestoneForm.lineArKey,
                _lineAr,
                l10n.ownerMilestoneLineAr,
                120,
                direction: TextDirection.rtl,
              ),
              field(
                MilestoneForm.lineEnKey,
                _lineEn,
                l10n.ownerMilestoneLineEn,
                120,
                direction: TextDirection.ltr,
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: MilestoneForm.monthKey,
                      initialValue: _month,
                      decoration: InputDecoration(
                        labelText: l10n.ownerMilestoneMonth,
                      ),
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              DateFormat.MMMM(tag).format(DateTime(2026, m)),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: MilestoneForm.yearKey,
                      initialValue: _year,
                      decoration: InputDecoration(
                        labelText: l10n.ownerMilestoneYear,
                      ),
                      items: [
                        for (final y in years)
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                      ],
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              Text(l10n.ownerMilestoneIcon, style: t.label),
              const SizedBox(height: KSpacing.sm),
              Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: [
                  for (final icon in JourneyIcon.values)
                    Semantics(
                      selected: icon == _icon,
                      button: true,
                      label: icon.name,
                      child: InkWell(
                        key: MilestoneForm.iconKey(icon),
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _icon = icon),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [icon.light, icon.deep],
                            ),
                            border: Border.all(
                              color: icon == _icon
                                  ? p.textPrimary
                                  : const Color(0x00000000),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            icon.icon,
                            size: 20,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
              SwitchListTile(
                key: MilestoneForm.latestKey,
                contentPadding: EdgeInsets.zero,
                value: _latest,
                onChanged: (v) => setState(() => _latest = v),
                title: Text(l10n.ownerJourneyLatest),
                subtitle: Text(l10n.ownerMilestoneLatestHint),
              ),
              const SizedBox(height: KSpacing.md),
              FilledButton(
                key: MilestoneForm.saveKey,
                onPressed: _save,
                child: Text(l10n.ownerSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
