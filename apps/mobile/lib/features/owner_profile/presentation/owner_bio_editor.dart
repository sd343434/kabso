import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.98-social (D307, §10.112.11): «بايو المؤسس» — opens the editor of the
/// founder's bilingual bio from «لوحة المؤسس». Saving refreshes his page
/// (`profileStatsProvider(username)`).
Future<void> showOwnerBioEditor(
  BuildContext context, {
  required String username,
  OwnerBio? bio,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => OwnerBioEditor(username: username, bio: bio),
);

/// The two fields (Arabic, English; the ordinary bio's 300 limit) with the
/// app's default founder texts as hints; an empty field shows the default.
class OwnerBioEditor extends ConsumerStatefulWidget {
  const new({required this.username, super.key, this.bio});

  final String username;
  final OwnerBio? bio;

  static const sheetKey = Key('owner.bio.editor');
  static const arKey = Key('owner.bio.editor.ar');
  static const enKey = Key('owner.bio.editor.en');
  static const saveKey = Key('owner.bio.editor.save');

  /// The ordinary bio's limit (§10.42).
  static const maxLength = 300;

  @override
  ConsumerState<OwnerBioEditor> createState() => _OwnerBioEditorState();
}

class _OwnerBioEditorState extends ConsumerState<OwnerBioEditor> {
  late final _ar = TextEditingController(text: widget.bio?.ar ?? '');
  late final _en = TextEditingController(text: widget.bio?.en ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref
          .read(ownerProfileRepositoryProvider)
          .setBio(ar: text(_ar), en: text(_en));
      ref.invalidate(profileStatsProvider(widget.username));
      if (!mounted) return;
      KSnack.success(context, l10n.ownerBioSaved);
      Navigator.of(context).pop();
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
    final p = context.palette;
    // The defaults come from each language's own strings (gen-l10n).
    final arDefault = lookupAppLocalizations(const Locale('ar'))
        .ownerBioDefault;
    final enDefault = lookupAppLocalizations(const Locale('en'))
        .ownerBioDefault;
    Widget field(
      Key key,
      TextEditingController c,
      String label,
      String hint,
      TextDirection direction,
    ) => TextField(
      key: key,
      controller: c,
      enabled: !_busy,
      maxLength: OwnerBioEditor.maxLength,
      minLines: 2,
      maxLines: 5,
      textDirection: direction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintMaxLines: 4,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    );
    return Padding(
      key: OwnerBioEditor.sheetKey,
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
            Text(l10n.ownerBioTitle, style: t.title),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.ownerBioHint,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            field(
              OwnerBioEditor.arKey,
              _ar,
              l10n.ownerBioArabic,
              arDefault,
              TextDirection.rtl,
            ),
            const SizedBox(height: KSpacing.sm),
            field(
              OwnerBioEditor.enKey,
              _en,
              l10n.ownerBioEnglish,
              enDefault,
              TextDirection.ltr,
            ),
            const SizedBox(height: KSpacing.md),
            FilledButton(
              key: OwnerBioEditor.saveKey,
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
