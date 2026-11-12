import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';
import 'package:kabso_live/features/profile/category/category_style.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D386 (CONVENTIONS §10.175.1, §10.175.4): the category sheet of «تعديل
/// الملف» — the 24 categories grouped by family (each with its icon and the
/// family's accent), «بدون فئة», and on top the verification: verified ✓,
/// «طلب توثيق الفئة», the open request with «إلغاء الطلب», or the team's
/// reason for a rejection. A category the team locked shows read-only.
/// A choice pops `(category,)`; closing pops nothing.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const new({
    required this.current,
    required this.verified,
    required this.locked,
    this.scroll,
    super.key,
  });

  final AccountCategory? current;
  final bool verified;
  final bool locked;
  final ScrollController? scroll;

  static Key option(AccountCategory c) =>
      Key('profile.edit.category.${c.wire}');
  static const none = Key('profile.edit.category.none');
  static Key family(CategoryFamily f) =>
      Key('profile.edit.category.family.${f.name}');
  static const verifyCard = Key('profile.edit.category.verify');
  static const requestKey = Key('profile.edit.category.verify.request');
  static const cancelKey = Key('profile.edit.category.verify.cancel');
  static const verifiedKey = Key('profile.edit.category.verify.done');
  static const lockedKey = Key('profile.edit.category.locked');

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  bool _busy = false;

  Future<void> _run(
    Future<CategoryVerification> Function(CategoryProfileRepository) call, {
    String? done,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call(ref.read(categoryProfileRepositoryProvider));
      ref.invalidate(myCategoryVerificationProvider);
      if (mounted && done != null) KSnack.success(context, done);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
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
    final locked = widget.locked;
    return RadioGroup<AccountCategory?>(
      groupValue: widget.current,
      onChanged: (c) {
        if (!locked) Navigator.of(context).pop((c,));
      },
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.only(bottom: KSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.xs,
            ),
            child: Text(l10n.profileEditCategory, style: t.title),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              l10n.profileEditCategoryHint,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
          if (widget.current != null) _verification(context),
          if (locked)
            Padding(
              key: CategoryPickerSheet.lockedKey,
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: p.warning),
                  const SizedBox(width: KSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.categoryLockedNote,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else if (widget.verified)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                0,
              ),
              child: Text(
                l10n.categoryVerifyChangeWarning,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
          for (final family in CategoryFamily.values) ...[
            Padding(
              key: CategoryPickerSheet.family(family),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.xxs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: categoryAccent(context, family),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Text(
                    categoryFamilyLabel(l10n, family),
                    style: t.label.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            for (final c in family.categories)
              RadioListTile<AccountCategory?>(
                key: CategoryPickerSheet.option(c),
                value: c,
                enabled: !locked,
                dense: true,
                controlAffinity: ListTileControlAffinity.trailing,
                secondary: AppIcon(
                  categoryIcon(c),
                  size: 22,
                  color: categoryAccent(context, family),
                ),
                title: Text(categoryLabel(l10n, c)),
              ),
          ],
          const SizedBox(height: KSpacing.sm),
          RadioListTile<AccountCategory?>(
            key: CategoryPickerSheet.none,
            value: null,
            enabled: !locked,
            controlAffinity: ListTileControlAffinity.trailing,
            title: Text(l10n.profileEditCategoryNone),
          ),
        ],
      ),
    );
  }

  Widget _verification(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final current = widget.current!;
    final accent = categoryAccent(context, current.family);
    final state = ref.watch(myCategoryVerificationProvider).value;
    final verified = state?.verified ?? widget.verified;
    final request = state?.request;
    final Widget body;
    if (verified) {
      body = Row(
        key: CategoryPickerSheet.verifiedKey,
        children: [
          Icon(Icons.verified_rounded, color: accent, size: 22),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              l10n.categoryVerifyVerified,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      );
    } else if (state?.pending ?? false) {
      body = Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: accent, size: 20),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              l10n.categoryVerifyPending,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
          TextButton(
            key: CategoryPickerSheet.cancelKey,
            onPressed: _busy ? null : () => _run((r) => r.cancelVerification()),
            child: Text(l10n.categoryVerifyCancel),
          ),
        ],
      );
    } else {
      final rejected = request?.status == CategoryRequestStatus.rejected
          ? request?.rejectReason
          : null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.categoryVerifyHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (rejected != null) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.categoryVerifyRejected(rejected),
              style: t.caption.copyWith(color: p.error),
            ),
          ],
          const SizedBox(height: KSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: CategoryPickerSheet.requestKey,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? KCategoryAccents.onDark
                    : KCategoryAccents.onLight,
                shape: const StadiumBorder(),
              ),
              onPressed: _busy || state == null
                  ? null
                  : () => _run(
                      (r) => r.requestVerification(),
                      done: l10n.categoryVerifySent,
                    ),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(l10n.categoryVerifyRequest),
            ),
          ),
        ],
      );
    }
    return Padding(
      key: CategoryPickerSheet.verifyCard,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Padding(padding: const EdgeInsets.all(KSpacing.md), child: body),
      ),
    );
  }
}
