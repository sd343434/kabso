import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show photoPickerProvider;
import 'package:kabso_live/features/posts/data/media_repository.dart'
    show maxPhotoBytes, sniffImageType;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.5): «اقترح ميزة / أبلغ عن موظف» — a visitor's
/// sheet with two choices: a feature suggestion (≤ 1 000 characters, one
/// optional picture) or a confidential staff report (the Kabso Team member
/// by @username or staff ID, the reason, the text and up to four evidence
/// pictures). Both go to the owner's «صندوق المؤسس»; the staff member is
/// never told. Returns true when sent.
Future<bool> showOwnerFeedbackSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const OwnerFeedbackSheet(),
    ) ??
    false;

class OwnerFeedbackSheet extends ConsumerStatefulWidget {
  const new({super.key, this.initial});

  /// Opens straight on a form (tests and captures).
  final FeedbackKind? initial;

  static const sheetKey = Key('owner.feedback');
  static const featureKey = Key('owner.feedback.feature');
  static const reportKey = Key('owner.feedback.report');
  static const textKey = Key('owner.feedback.text');
  static const searchKey = Key('owner.feedback.staffSearch');
  static const addImageKey = Key('owner.feedback.addImage');
  static const sendKey = Key('owner.feedback.send');
  static const confidentialKey = Key('owner.feedback.confidential');
  static Key staffKey(String id) => Key('owner.feedback.staff.$id');
  static Key categoryKey(FeedbackCategory c) =>
      Key('owner.feedback.category.${c.wire}');

  @override
  ConsumerState<OwnerFeedbackSheet> createState() => _OwnerFeedbackSheetState();
}

class _OwnerFeedbackSheetState extends ConsumerState<OwnerFeedbackSheet> {
  late FeedbackKind? _kind = widget.initial;
  final _text = TextEditingController();
  final _search = TextEditingController();
  final List<(Uint8List, String)> _images = [];
  FeedbackStaff? _staff;
  FeedbackCategory? _category;
  List<FeedbackStaff>? _results;
  Timer? _debounce;
  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  int get _maxImages => _kind == FeedbackKind.staffReport ? 4 : 1;

  bool get _ready =>
      !_sending &&
      _text.text.trim().isNotEmpty &&
      (_kind == FeedbackKind.feature || (_staff != null && _category != null));

  void _query(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await ref
            .read(ownerProfileRepositoryProvider)
            .searchStaff(q);
        if (mounted) setState(() => _results = found);
      } on Object catch (e) {
        if (mounted) {
          KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
        }
      }
    });
  }

  Future<void> _addImage() async {
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (picked.isEmpty || !mounted) return;
    final bytes = picked.first;
    final type = sniffImageType(bytes);
    if (type == null || bytes.length > maxPhotoBytes) {
      KSnack.error(context, context.l10n.ownerFeedbackImageInvalid);
      return;
    }
    setState(() => _images.add((bytes, type)));
  }

  Future<void> _send() async {
    final kind = _kind;
    if (kind == null || !_ready) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    final repo = ref.read(ownerProfileRepositoryProvider);
    try {
      final ids = <String>[];
      for (final (bytes, type) in _images) {
        ids.add(await repo.uploadFeedbackImage(bytes, type));
      }
      await repo.sendFeedback(
        kind: kind,
        text: _text.text.trim(),
        imageUploadIds: ids,
        staffUserId: kind == FeedbackKind.staffReport ? _staff?.id : null,
        category: kind == FeedbackKind.staffReport ? _category : null,
      );
      if (!mounted) return;
      KSnack.success(context, l10n.ownerFeedbackSent);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        setState(() => _sending = false);
      }
    }
  }

  String _categoryLabel(FeedbackCategory c) {
    final l10n = context.l10n;
    return switch (c) {
      FeedbackCategory.rudeness => l10n.ownerCategoryRudeness,
      FeedbackCategory.abuseOfPower => l10n.ownerCategoryAbuseOfPower,
      FeedbackCategory.unfairAction => l10n.ownerCategoryUnfairAction,
      FeedbackCategory.noResponse => l10n.ownerCategoryNoResponse,
      FeedbackCategory.corruption => l10n.ownerCategoryCorruption,
      FeedbackCategory.other => l10n.ownerCategoryOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Padding(
      key: OwnerFeedbackSheet.sheetKey,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
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
            Text(l10n.ownerFeedbackTitle, style: t.title),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.ownerFeedbackSubtitle,
              style: t.caption.copyWith(color: context.palette.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    key: OwnerFeedbackSheet.featureKey,
                    icon: Icons.lightbulb_rounded,
                    tint: KBrandColors.gold,
                    title: l10n.ownerFeedbackFeature,
                    selected: _kind == FeedbackKind.feature,
                    onTap: () => setState(() {
                      _kind = FeedbackKind.feature;
                      if (_images.length > 1) {
                        _images.removeRange(1, _images.length);
                      }
                    }),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: _Choice(
                    key: OwnerFeedbackSheet.reportKey,
                    icon: Icons.shield_rounded,
                    tint: KBrandColors.red500,
                    title: l10n.ownerFeedbackReport,
                    selected: _kind == FeedbackKind.staffReport,
                    onTap: () {
                      setState(() => _kind = FeedbackKind.staffReport);
                      if (_results == null) _query('');
                    },
                  ),
                ),
              ],
            ),
            if (_kind != null) ..._form(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final report = _kind == FeedbackKind.staffReport;
    return [
      const SizedBox(height: KSpacing.lg),
      if (report) ...[
        Text(l10n.ownerFeedbackStaff, style: t.label),
        const SizedBox(height: KSpacing.xs),
        if (_staff case final s?)
          _StaffTile(
            staff: s,
            selected: true,
            onTap: () => setState(() => _staff = null),
          )
        else ...[
          TextField(
            key: OwnerFeedbackSheet.searchKey,
            controller: _search,
            onChanged: _query,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.ownerFeedbackStaffHint,
            ),
          ),
          for (final s in (_results ?? const <FeedbackStaff>[]).take(5))
            _StaffTile(
              key: OwnerFeedbackSheet.staffKey(s.id),
              staff: s,
              onTap: () => setState(() => _staff = s),
            ),
          if (_results case final r? when r.isEmpty)
            Padding(
              padding: const EdgeInsets.all(KSpacing.sm),
              child: Text(
                l10n.ownerFeedbackStaffNone,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
        ],
        const SizedBox(height: KSpacing.md),
        Text(l10n.ownerFeedbackCategory, style: t.label),
        const SizedBox(height: KSpacing.xs),
        Wrap(
          spacing: KSpacing.xs,
          runSpacing: KSpacing.xs,
          children: [
            for (final c in FeedbackCategory.values)
              ChoiceChip(
                key: OwnerFeedbackSheet.categoryKey(c),
                label: Text(_categoryLabel(c)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: KSpacing.md),
      ],
      TextField(
        key: OwnerFeedbackSheet.textKey,
        controller: _text,
        minLines: 3,
        maxLines: 6,
        maxLength: ownerFeedbackMaxText,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: report
              ? l10n.ownerFeedbackReportHint
              : l10n.ownerFeedbackFeatureHint,
        ),
      ),
      Wrap(
        spacing: KSpacing.sm,
        runSpacing: KSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, (bytes, _)) in _images.indexed)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  child: Image.memory(
                    bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(i)),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xB3000000),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_images.length < _maxImages)
            OutlinedButton.icon(
              key: OwnerFeedbackSheet.addImageKey,
              onPressed: _sending ? null : () => unawaited(_addImage()),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                report
                    ? l10n.ownerFeedbackEvidence(_maxImages)
                    : l10n.ownerFeedbackImage,
              ),
            ),
        ],
      ),
      if (report) ...[
        const SizedBox(height: KSpacing.md),
        Container(
          key: OwnerFeedbackSheet.confidentialKey,
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            color: KBrandColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KRadius.sm),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 16,
                color: Color(0xFFB8860B),
              ),
              const SizedBox(width: KSpacing.xs),
              Expanded(
                child: Text(
                  l10n.ownerFeedbackConfidential,
                  style: t.caption.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: KSpacing.md),
      FilledButton(
        key: OwnerFeedbackSheet.sendKey,
        onPressed: _ready ? () => unawaited(_send()) : null,
        child: _sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.ownerFeedbackSend),
      ),
    ];
  }
}

class _Choice extends StatelessWidget {
  const new({
    required this.icon,
    required this.tint,
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            vertical: KSpacing.md,
            horizontal: KSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.14) : p.surface,
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(
              color: selected ? tint : p.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: tint, size: 28),
              const SizedBox(height: KSpacing.xs),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const new({
    required this.staff,
    required this.onTap,
    super.key,
    this.selected = false,
  });

  final FeedbackStaff staff;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: p.surfaceRaised,
        foregroundImage: switch (staff.avatarUrl) {
          final url? => NetworkImage(url),
          null => null,
        },
        child: Icon(Icons.badge_rounded, color: p.textSecondary),
      ),
      title: Text(staff.displayName, maxLines: 1),
      subtitle: Text(
        KHandle.ltr('@${staff.staffId ?? staff.username}'),
        maxLines: 1,
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: p.success)
          : null,
    );
  }
}
