import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Edit-profile geometry (D58, layout from the owner's reference).
abstract final class KEditProfile {
  static const double avatar = KSizes.avatarLg;

  /// Width of the label column; values start after it.
  static const double labelWidth = 112;
  static const double rowPadding = KSpacing.md;
}

/// `/profile/edit` (D58), in the owner's settings-list style: the photo in
/// the centre with "Change photo" under it, then rows with the label at the
/// start and the value beside it (name, username, bio), hairlines between
/// them starting at the values.
///
/// Saving is not possible yet: `PATCH /me` accepts only `locale` (contract
/// v1.3.1), so the rows are read-only, "Change photo" and Save are disabled
/// and a notice says why. The contract change that would enable it is
/// drafted in `docs/contracts/proposals/CP-001-edit-profile.md` (not
/// approved).
///
/// Below, the options the owner chose from the reference (links, gender,
/// account category; reorder grid and account privacy) are rows marked
/// "Coming soon": greyed, not buttons, with no value until CP-001 (or the
/// posts API, for the grid) exists. Privacy shows the real public/private
/// state from `GET /me`.
class EditProfileScreen extends ConsumerWidget {
  const new({super.key});

  static const noticeKey = Key('profile.edit.notice');
  static const saveKey = Key('profile.edit.save');
  static const photoKey = Key('profile.edit.photo');
  static const nameKey = Key('profile.edit.name');
  static const usernameKey = Key('profile.edit.username');
  static const bioKey = Key('profile.edit.bio');
  static const linksKey = Key('profile.edit.links');
  static const genderKey = Key('profile.edit.gender');
  static const categoryKey = Key('profile.edit.category');
  static const gridKey = Key('profile.edit.grid');
  static const privacyKey = Key('profile.edit.privacy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = ref.watch(meProvider).value ?? ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.profileEditTitle),
        actions: [
          TextButton(
            key: saveKey,
            // No endpoint saves these fields yet (D58).
            onPressed: null,
            child: Text(l10n.profileEditSave),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(KMetrics.hairline),
          child: Divider(
            height: KMetrics.hairline,
            thickness: KMetrics.hairline,
            color: p.border,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: KSpacing.xl),
                Center(
                  child: KAvatar(
                    name: user.displayName,
                    imageUrl: user.avatarUrl,
                    size: KEditProfile.avatar,
                  ),
                ),
                Center(
                  child: TextButton(
                    key: photoKey,
                    // Photo upload is outside CP-001 (needs storage).
                    onPressed: null,
                    child: Text(l10n.profileEditPhoto),
                  ),
                ),
                Padding(
                  key: noticeKey,
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.lg,
                    0,
                    KSpacing.lg,
                    KSpacing.md,
                  ),
                  child: Text(
                    l10n.profileEditUnavailable,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                Divider(
                  height: KMetrics.hairline,
                  thickness: KMetrics.hairline,
                  color: p.border,
                ),
                _Row(
                  key: nameKey,
                  label: l10n.profileEditName,
                  value: user.displayName,
                ),
                _Row(
                  key: usernameKey,
                  label: l10n.profileEditUsername,
                  value: user.username,
                  ltr: true,
                ),
                _Row(
                  key: bioKey,
                  label: l10n.profileEditBio,
                  value: user.bio ?? '',
                  placeholder: l10n.profileEditBio,
                ),
                _Row(key: linksKey, label: l10n.profileEditLinks, soon: true),
                _Row(key: genderKey, label: l10n.profileEditGender, soon: true),
                _Row(
                  key: categoryKey,
                  label: l10n.profileEditCategory,
                  soon: true,
                  last: true,
                ),
                Divider(
                  height: KMetrics.hairline,
                  thickness: KMetrics.hairline,
                  color: p.border,
                ),
                _Row(
                  key: gridKey,
                  label: l10n.profileEditReorderGrid,
                  soon: true,
                  wideLabel: true,
                  last: true,
                ),
                Divider(
                  height: KMetrics.hairline,
                  thickness: KMetrics.hairline,
                  color: p.border,
                ),
                _Row(
                  key: privacyKey,
                  label: l10n.profileEditPrivacy,
                  value: user.isPrivate
                      ? l10n.profilePrivacyPrivate
                      : l10n.profilePrivacyPublic,
                  soon: true,
                  wideLabel: true,
                  last: true,
                ),
                Divider(
                  height: KMetrics.hairline,
                  thickness: KMetrics.hairline,
                  color: p.border,
                ),
              ],
            ),
    );
  }
}

/// One label/value row; the hairline under it starts at the value column
/// (none under the [last] row, whose section divider follows). A [soon]
/// row is greyed and ends with "Coming soon" and a chevron; it is not a
/// button. A [wideLabel] row puts its label in the full width and its
/// value at the end (section rows such as "Reorder grid").
class _Row extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.value = '',
    this.placeholder,
    this.ltr = false,
    this.last = false,
    this.soon = false,
    this.wideLabel = false,
  });

  final String label;
  final String value;
  final String? placeholder;
  final bool ltr;
  final bool last;
  final bool soon;
  final bool wideLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final empty = value.isEmpty;
    final labelText = Text(
      label,
      style: t.body.copyWith(color: soon ? p.textSecondary : p.textPrimary),
    );
    final valueText = Text(
      empty ? (placeholder ?? '') : value,
      textDirection: ltr ? TextDirection.ltr : null,
      textAlign: ltr && Directionality.of(context) == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.start,
      style: t.body.copyWith(
        color: empty || soon ? p.textTertiary : p.textPrimary,
      ),
    );
    final trailing = soon
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: KSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: p.surfaceOverlay,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  l10n.profileEditSoon,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ],
          )
        : null;
    const vertical = EdgeInsets.symmetric(vertical: KEditProfile.rowPadding);
    final valueColumn = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        KEditProfile.rowPadding,
        KSpacing.md,
        KEditProfile.rowPadding,
      ),
      child: Row(
        children: [
          Expanded(child: wideLabel ? labelText : valueText),
          if (wideLabel && !empty) valueText,
          ?trailing,
        ],
      ),
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: KSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!wideLabel)
              SizedBox(
                width: KEditProfile.labelWidth,
                child: Padding(padding: vertical, child: labelText),
              ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: last
                      ? null
                      : Border(bottom: BorderSide(color: p.border)),
                ),
                child: valueColumn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
