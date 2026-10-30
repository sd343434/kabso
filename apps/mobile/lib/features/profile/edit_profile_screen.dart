import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/auth_failures.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/application/profile_edit_controller.dart';
import 'package:kabso_live/features/profile/avatar_crop_screen.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Edit-profile geometry (D58, layout from the owner's reference).
abstract final class KEditProfile {
  static const double avatar = KSizes.avatarLg;

  /// Width of the label column; values start after it.
  static const double labelWidth = 112;
  static const double rowPadding = KSpacing.md;
}

/// Bio limits (CONVENTIONS §10.42), checked again by the server.
abstract final class BioRules {
  static const int maxCodePoints = 300;
  static const int maxLineBreaks = 4;

  /// The value the server keeps: lines without trailing spaces, no blank
  /// lines at either end, trimmed; empty means "no bio".
  static String normalize(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trimRight())
        .toList();
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n').trim();
  }

  /// Whether [value] (normalized) is within the limits.
  static bool fits(String value) =>
      value.runes.length <= maxCodePoints &&
      '\n'.allMatches(value).length <= maxLineBreaks;
}

/// `/profile/edit` (D58 layout; D168 working): the photo in the centre with
/// "Change photo" under it, then label/value rows with hairlines starting at
/// the values.
///
/// D168 (owner: «فعّل الأزرار المتبقية في تعديل الملف وتغيير الصورة»,
/// contract v1.45-social): the photo is chosen from the photos or taken with
/// the camera, cropped square, uploaded as an `AVATAR` and set with
/// `PUT /me/avatar` (or removed); the name and the bio open an editor saved
/// with `PATCH /me`; the username opens the D146 change screen. While
/// uploads are off the server answers 503 and the screen says so; nothing
/// changes.
///
/// Links, gender, account category, reordering the grid and the private
/// account switch wait for the owner's decisions (D168 questions): greyed
/// rows marked "Coming soon", not buttons. Privacy shows the real
/// public/private state from `GET /me`.
class EditProfileScreen extends ConsumerWidget {
  const new({super.key});

  static const photoKey = Key('profile.edit.photo');
  static const avatarKey = Key('profile.edit.avatar');
  static const nameKey = Key('profile.edit.name');
  static const usernameKey = Key('profile.edit.username');
  static const bioKey = Key('profile.edit.bio');
  static const linksKey = Key('profile.edit.links');
  static const genderKey = Key('profile.edit.gender');
  static const categoryKey = Key('profile.edit.category');
  static const gridKey = Key('profile.edit.grid');
  static const privacyKey = Key('profile.edit.privacy');
  static const photoLibraryKey = Key('profile.edit.photo.library');
  static const photoCameraKey = Key('profile.edit.photo.camera');
  static const photoRemoveKey = Key('profile.edit.photo.remove');
  static const photoProgressKey = Key('profile.edit.photo.progress');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    // `GET /me` refreshes the session's user; the session shows edits at once.
    final me = ref.watch(meProvider);
    final user = ref.watch(currentUserProvider) ?? me.value;
    final photo = ref.watch(profilePhotoControllerProvider);
    Widget divider() => Divider(
      height: KMetrics.hairline,
      thickness: KMetrics.hairline,
      color: p.border,
    );
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.profileEditTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(KMetrics.hairline),
          child: divider(),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: KSpacing.xl),
                Center(
                  child: Semantics(
                    button: true,
                    enabled: !photo.busy,
                    label: photo.busy
                        ? l10n.profileEditPhotoUploading
                        : l10n.profileEditPhoto,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: avatarKey,
                      onTap: photo.busy
                          ? null
                          : () => _changePhoto(
                              context,
                              ref,
                              hasPhoto: user.avatarUrl != null,
                            ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          KAvatar(
                            name: user.displayName,
                            imageUrl: user.avatarUrl,
                            size: KEditProfile.avatar,
                          ),
                          if (photo.busy)
                            SizedBox.square(
                              dimension: KEditProfile.avatar,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: Color(0x8C000000),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(
                                      key: photoProgressKey,
                                      value: photo.progress,
                                      strokeWidth: 2.4,
                                      color: const Color(0xFFFFFFFF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    key: photoKey,
                    onPressed: photo.busy
                        ? null
                        : () => _changePhoto(
                            context,
                            ref,
                            hasPhoto: user.avatarUrl != null,
                          ),
                    child: Text(
                      photo.busy
                          ? l10n.profileEditPhotoUploading
                          : l10n.profileEditPhoto,
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                divider(),
                _Row(
                  key: nameKey,
                  label: l10n.profileEditName,
                  value: user.displayName,
                  onTap: () => _edit(context, _ProfileField.name, user),
                ),
                _Row(
                  key: usernameKey,
                  label: l10n.profileEditUsername,
                  value: user.username,
                  ltr: true,
                  // D146: the username has its own rules and screen.
                  onTap: () =>
                      GoRouter.maybeOf(context)?.push(AppRoutes.changeUsername),
                ),
                _Row(
                  key: bioKey,
                  label: l10n.profileEditBio,
                  value: user.bio ?? '',
                  placeholder: l10n.profileEditBioPlaceholder,
                  onTap: () => _edit(context, _ProfileField.bio, user),
                ),
                _Row(key: linksKey, label: l10n.profileEditLinks, soon: true),
                _Row(key: genderKey, label: l10n.profileEditGender, soon: true),
                _Row(
                  key: categoryKey,
                  label: l10n.profileEditCategory,
                  soon: true,
                  last: true,
                ),
                divider(),
                _Row(
                  key: gridKey,
                  label: l10n.profileEditReorderGrid,
                  soon: true,
                  wideLabel: true,
                  last: true,
                ),
                divider(),
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
                divider(),
              ],
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    _ProfileField field,
    User user,
  ) async {
    final l10n = context.l10n;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FieldScreen(
          field: field,
          initial: field == _ProfileField.name
              ? user.displayName
              : user.bio ?? '',
        ),
      ),
    );
    if (saved == true && context.mounted) {
      KSnack.success(context, l10n.profileEditSaved);
    }
  }

  Future<void> _changePhoto(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPhoto,
  }) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
              child: Text(
                l10n.profileEditPhotoSheetTitle,
                style: sheet.textStyles.title,
              ),
            ),
            ListTile(
              key: photoLibraryKey,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileEditPhotoLibrary),
              onTap: () => Navigator.of(sheet).pop(_PhotoAction.library),
            ),
            ListTile(
              key: photoCameraKey,
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profileEditPhotoCamera),
              onTap: () => Navigator.of(sheet).pop(_PhotoAction.camera),
            ),
            if (hasPhoto)
              ListTile(
                key: photoRemoveKey,
                leading: Icon(Icons.delete_outline, color: sheet.palette.error),
                title: Text(l10n.profileEditPhotoRemove),
                onTap: () => Navigator.of(sheet).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final controller = ref.read(profilePhotoControllerProvider.notifier);
    try {
      switch (action) {
        case _PhotoAction.library || _PhotoAction.camera:
          final bytes = await ref
              .read(avatarPhotoPickerProvider)
              .pick(
                action == _PhotoAction.camera
                    ? AvatarSource.camera
                    : AvatarSource.library,
              );
          if (!context.mounted || bytes == null) return;
          if (sniffImageType(bytes) == null) {
            KSnack.error(context, l10n.createPhotoUnsupported);
            return;
          }
          if (bytes.length > maxPhotoBytes) {
            KSnack.error(context, l10n.createPhotoTooLarge);
            return;
          }
          final cropped = await Navigator.of(context).push<Uint8List>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => AvatarCropScreen(bytes: bytes),
            ),
          );
          if (!context.mounted || cropped == null) return;
          await controller.change(cropped, 'image/png');
          if (context.mounted) {
            KSnack.success(context, l10n.profileEditPhotoUpdated);
          }
        case _PhotoAction.remove:
          await controller.remove();
          if (context.mounted) {
            KSnack.success(context, l10n.profileEditPhotoRemoved);
          }
      }
    } on PlatformException {
      if (context.mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }
}

enum _PhotoAction { library, camera, remove }

enum _ProfileField { name, bio }

/// The editor of one field: the name (the registration rules, §6) or the
/// bio (≤ 300 characters, ≤ 5 lines). Save is enabled when the value
/// changed and fits; the server's field errors show under the field.
/// Pops `true` once saved.
class _FieldScreen extends ConsumerStatefulWidget {
  const new({required this.field, required this.initial});

  final _ProfileField field;
  final String initial;

  @override
  ConsumerState<_FieldScreen> createState() => _FieldScreenState();
}

/// Keys of the field editor (tests).
abstract final class EditProfileFieldKeys {
  static const field = Key('profile.edit.field');
  static const save = Key('profile.edit.field.save');
}

class _FieldScreenState extends ConsumerState<_FieldScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  bool _saving = false;
  String? _serverError;

  bool get _name => widget.field == _ProfileField.name;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_serverError != null) _serverError = null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? _localError(AppLocalizations l10n) {
    if (_name) {
      return displayNameIssueMessage(
        l10n,
        AuthValidators.displayNameIssue(_text.text),
      );
    }
    return BioRules.fits(BioRules.normalize(_text.text))
        ? null
        : l10n.profileEditBioTooLong(
            BioRules.maxCodePoints,
            BioRules.maxLineBreaks + 1,
          );
  }

  bool get _changed => _name
      ? _text.text.trim() != widget.initial.trim()
      : BioRules.normalize(_text.text) != BioRules.normalize(widget.initial);

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_saving || !_changed || _localError(l10n) != null) return;
    setState(() => _saving = true);
    try {
      if (_name) {
        await ref.read(saveDisplayNameProvider)(_text.text.trim());
      } else {
        final bio = BioRules.normalize(_text.text);
        await ref.read(saveBioProvider)(bio.isEmpty ? null : bio);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      final issue = failure is ServerFailure
          ? failure.details
                .where((d) => d.field == (_name ? 'displayName' : 'bio'))
                .firstOrNull
          : null;
      setState(() {
        _saving = false;
        _serverError = issue == null
            ? null
            : _name
            ? serverIssueMessage(
                l10n,
                AuthField.displayName,
                ValidationIssueCode.fromWire(issue.issue),
              )
            : issue.issue == 'too_long' || issue.issue == 'too_big'
            ? l10n.profileEditBioTooLong(
                BioRules.maxCodePoints,
                BioRules.maxLineBreaks + 1,
              )
            : l10n.profileEditBioInvalid;
      });
      if (issue == null) KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final local = _localError(l10n);
    // The empty name says "required" only after typing, not on arrival.
    final error = _serverError ?? (_text.text.isEmpty && _name ? null : local);
    final count = _name
        ? AuthValidators.displayNameLength(_text.text)
        : BioRules.normalize(_text.text).runes.length;
    final max = _name ? AuthRules.displayNameMax : BioRules.maxCodePoints;
    final canSave = !_saving && _changed && local == null;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(_name ? l10n.profileEditName : l10n.profileEditBio),
        actions: [
          TextButton(
            key: EditProfileFieldKeys.save,
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.profileEditSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          TextField(
            key: EditProfileFieldKeys.field,
            controller: _text,
            autofocus: true,
            enabled: !_saving,
            maxLines: _name ? 1 : 6,
            minLines: 1,
            keyboardType: _name ? TextInputType.name : TextInputType.multiline,
            textInputAction: _name
                ? TextInputAction.done
                : TextInputAction.newline,
            onSubmitted: _name ? (_) => _save() : null,
            style: t.body,
            decoration: InputDecoration(
              labelText: _name ? l10n.profileEditName : l10n.profileEditBio,
              hintText: _name ? null : l10n.profileEditBioPlaceholder,
              errorText: error,
              errorMaxLines: 3,
              counterText: '$count/$max',
              counterStyle: t.caption.copyWith(
                color: count > max ? p.error : p.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            _name ? l10n.profileEditNameHelp : l10n.profileEditBioHelp,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One label/value row; the hairline under it starts at the value column
/// (none under the [last] row, whose section divider follows). A row with
/// [onTap] is a button ending with a chevron. A [soon] row is greyed and
/// ends with "Coming soon" and a chevron; it is not a button. A [wideLabel]
/// row puts its label in the full width and its value at the end (section
/// rows such as "Reorder grid").
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
    this.onTap,
  });

  final String label;
  final String value;
  final String? placeholder;
  final bool ltr;
  final bool last;
  final bool soon;
  final bool wideLabel;
  final VoidCallback? onTap;

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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: t.body.copyWith(
        color: empty || soon ? p.textTertiary : p.textPrimary,
      ),
    );
    // Mirrored by the icon itself in RTL (it points to the reading end).
    final chevron = Icon(Icons.chevron_right_rounded, color: p.textTertiary);
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
              chevron,
            ],
          )
        : onTap != null
        ? chevron
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
    final row = Padding(
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
    );
    final tap = onTap;
    return MergeSemantics(
      child: soon || tap == null
          ? Semantics(enabled: soon ? false : null, child: row)
          : Semantics(
              button: true,
              child: InkWell(onTap: tap, child: row),
            ),
    );
  }
}
