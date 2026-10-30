import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/profile/application/profile_edit_controller.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D175 (owner, contract v1.47-social, CONVENTIONS §10.47): the editors of
/// Edit profile's gender, account category and links. Each saves with
/// `PATCH /me` and shows the result at once ([saveProfileFieldsProvider]).

/// Keys of the editors (tests).
abstract final class EditProfileFieldsKeys {
  static Key gender(Gender g) => Key('profile.edit.gender.${g.wire}');
  static const genderShow = Key('profile.edit.gender.show');
  static const genderSave = Key('profile.edit.gender.save');
  static Key category(AccountCategory c) =>
      Key('profile.edit.category.${c.wire}');
  static const categoryNone = Key('profile.edit.category.none');
  static Key linkUrl(int i) => Key('profile.edit.link.$i.url');
  static Key linkLabel(int i) => Key('profile.edit.link.$i.label');
  static Key linkRemove(int i) => Key('profile.edit.link.$i.remove');
  static const linkAdd = Key('profile.edit.link.add');
  static const linksSave = Key('profile.edit.links.save');
}

Future<void> _save(
  BuildContext context,
  WidgetRef ref,
  ProfileFieldsChange change,
) async {
  final l10n = context.l10n;
  try {
    await ref.read(saveProfileFieldsProvider)(change);
    if (context.mounted) KSnack.success(context, l10n.profileEditSaved);
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// The gender sheet: the three choices and whether others see it (off by
/// default; «أفضّل عدم الذكر» never shows).
Future<void> editGender(BuildContext context, WidgetRef ref, User user) async {
  final result = await showModalBottomSheet<(Gender, bool)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GenderSheet(gender: user.gender, show: user.showGender),
  );
  if (result == null || !context.mounted) return;
  final (gender, show) = result;
  if (gender == user.gender && show == user.showGender) return;
  await _save(
    context,
    ref,
    ProfileFieldsChange(
      gender: gender == user.gender ? null : gender,
      showGender: show == user.showGender ? null : show,
    ),
  );
}

class _GenderSheet extends StatefulWidget {
  const new({required this.gender, required this.show});

  final Gender? gender;
  final bool show;

  @override
  State<_GenderSheet> createState() => _GenderSheetState();
}

class _GenderSheetState extends State<_GenderSheet> {
  late Gender? _gender = widget.gender;
  late bool _show = widget.show;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final gender = _gender;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                0,
              ),
              child: GenderChoice(
                label: l10n.profileEditGender,
                value: gender,
                optionKey: EditProfileFieldsKeys.gender,
                onChanged: (g) => setState(() => _gender = g),
              ),
            ),
            SwitchListTile(
              key: EditProfileFieldsKeys.genderShow,
              value: _show,
              title: Text(l10n.profileEditGenderShow),
              subtitle: Text(
                l10n.profileEditGenderShowHint,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
              onChanged: (v) => setState(() => _show = v),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: KButton(
                key: EditProfileFieldsKeys.genderSave,
                label: l10n.profileEditSave,
                onPressed: gender == null
                    ? null
                    : () => Navigator.of(context).pop((gender, _show)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category sheet: the owner's eleven categories and "No category".
/// A choice saves at once.
Future<void> editCategory(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final l10n = context.l10n;
  // `(null)` is "No category"; closing the sheet is no record at all.
  final picked = await showModalBottomSheet<(AccountCategory?,)>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (sheet, scroll) => SafeArea(
        child: RadioGroup<AccountCategory?>(
          groupValue: user.category,
          onChanged: (c) => Navigator.of(sheet).pop((c,)),
          child: ListView(
            controller: scroll,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  KSpacing.lg,
                  KSpacing.lg,
                  KSpacing.xs,
                ),
                child: Text(
                  l10n.profileEditCategory,
                  style: sheet.textStyles.title,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
                child: Text(
                  l10n.profileEditCategoryHint,
                  style: sheet.textStyles.caption.copyWith(
                    color: sheet.palette.textSecondary,
                  ),
                ),
              ),
              for (final c in AccountCategory.values)
                RadioListTile<AccountCategory?>(
                  key: EditProfileFieldsKeys.category(c),
                  value: c,
                  title: Text(categoryLabel(l10n, c)),
                ),
              RadioListTile<AccountCategory?>(
                key: EditProfileFieldsKeys.categoryNone,
                value: null,
                title: Text(l10n.profileEditCategoryNone),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final (category,) = picked;
  if (category == user.category) return;
  await _save(
    context,
    ref,
    category == null
        ? const ProfileFieldsChange(clearCategory: true)
        : ProfileFieldsChange(category: category),
  );
}

/// The links editor: up to 3 links (https) with an optional label each;
/// Save sends the whole set (`PATCH /me {links}`). The app checks what it
/// can before saving; the server's field errors show under the field.
class EditLinksScreen extends ConsumerStatefulWidget {
  const new({required this.initial, super.key});

  final List<ProfileLink> initial;

  @override
  ConsumerState<EditLinksScreen> createState() => _EditLinksScreenState();
}

class _LinkFields {
  new({String url = '', String label = ''})
    : url = TextEditingController(text: url),
      label = TextEditingController(text: label);

  final TextEditingController url;
  final TextEditingController label;
  String? urlError;
  String? labelError;

  void dispose() {
    url.dispose();
    label.dispose();
  }
}

class _EditLinksScreenState extends ConsumerState<EditLinksScreen> {
  late final List<_LinkFields> _links = [
    for (final l in widget.initial)
      _LinkFields(url: l.url, label: l.label ?? '')..url.addListener(_changed),
  ];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final l in _links) {
      l.label.addListener(_changed);
    }
  }

  void _changed() {
    for (final l in _links) {
      l
        ..urlError = null
        ..labelError = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final l in _links) {
      l.dispose();
    }
    super.dispose();
  }

  List<ProfileLinkInput> get _values => [
    for (final l in _links)
      if (l.url.text.trim().isNotEmpty)
        (url: l.url.text.trim(), label: l.label.text.trim()),
  ];

  bool get _dirty {
    final now = _values;
    if (now.length != widget.initial.length) return true;
    for (final (i, v) in now.indexed) {
      final was = widget.initial[i];
      if (v.url != was.url || (v.label ?? '') != (was.label ?? '')) return true;
    }
    return false;
  }

  String _issueText(AppLocalizations l10n, String issue, {bool label = false}) {
    if (label) {
      return l10n.profileEditLinkLabelTooLong(ProfileLinkRules.maxLabel);
    }
    return switch (issue) {
      'too_long' => l10n.profileEditLinkTooLong,
      'invalid_value' => l10n.profileEditLinkDuplicate,
      _ => l10n.profileEditLinkInvalid,
    };
  }

  /// Local checks; true when nothing is wrong.
  bool _check(AppLocalizations l10n) {
    var ok = true;
    final seen = <String>{};
    for (final l in _links) {
      final url = l.url.text.trim();
      if (url.isEmpty) continue;
      final issue = ProfileLinkRules.issue(url);
      if (issue != null) {
        l.urlError = _issueText(l10n, issue);
        ok = false;
      } else if (!seen.add(url.toLowerCase())) {
        l.urlError = l10n.profileEditLinkDuplicate;
        ok = false;
      }
      final label = l.label.text.trim();
      if (label.runes.length > ProfileLinkRules.maxLabel ||
          label.contains('\n')) {
        l.labelError = _issueText(l10n, 'too_long', label: true);
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_saving || !_dirty) return;
    if (!_check(l10n)) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    // The server's indexes are those of the non-empty fields.
    final sent = [
      for (final l in _links)
        if (l.url.text.trim().isNotEmpty) l,
    ];
    try {
      await ref.read(saveProfileFieldsProvider)(
        ProfileFieldsChange(links: _values),
      );
      if (!mounted) return;
      KSnack.success(context, l10n.profileEditSaved);
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      var shown = false;
      if (failure is ServerFailure) {
        for (final d in failure.details) {
          final m = RegExp(r'^links\.(\d+)\.(url|label)$').firstMatch(d.field);
          final i = int.tryParse(m?.group(1) ?? '');
          if (m == null || i == null || i >= sent.length) continue;
          shown = true;
          if (m.group(2) == 'label') {
            sent[i].labelError = _issueText(l10n, d.issue, label: true);
          } else {
            sent[i].urlError = _issueText(l10n, d.issue);
          }
        }
      }
      setState(() => _saving = false);
      if (!shown) KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.profileEditLinks),
        actions: [
          TextButton(
            key: EditProfileFieldsKeys.linksSave,
            onPressed: !_saving && _dirty ? _save : null,
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
          Text(
            l10n.profileEditLinksHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          for (final (i, l) in _links.indexed) ...[
            const SizedBox(height: KSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        key: EditProfileFieldsKeys.linkUrl(i),
                        controller: l.url,
                        enabled: !_saving,
                        keyboardType: TextInputType.url,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        maxLength: ProfileLinkRules.maxLength,
                        decoration: InputDecoration(
                          labelText: l10n.profileEditLinkUrl,
                          hintText: 'https://',
                          hintTextDirection: TextDirection.ltr,
                          errorText: l.urlError,
                          errorMaxLines: 3,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      TextField(
                        key: EditProfileFieldsKeys.linkLabel(i),
                        controller: l.label,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.profileEditLinkLabel,
                          errorText: l.labelError,
                          errorMaxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: EditProfileFieldsKeys.linkRemove(i),
                  tooltip: l10n.profileEditLinkRemove,
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _links.removeAt(i).dispose();
                        }),
                  icon: Icon(Icons.remove_circle_outline, color: p.error),
                ),
              ],
            ),
          ],
          if (_links.length < ProfileLinkRules.maxLinks) ...[
            const SizedBox(height: KSpacing.lg),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: EditProfileFieldsKeys.linkAdd,
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        final f = _LinkFields();
                        f.url.addListener(_changed);
                        f.label.addListener(_changed);
                        _links.add(f);
                      }),
                icon: const Icon(Icons.add_link_rounded),
                label: Text(l10n.profileEditLinkAdd),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
