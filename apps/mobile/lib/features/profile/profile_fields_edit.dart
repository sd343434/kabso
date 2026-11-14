import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/profile/application/profile_edit_controller.dart';
import 'package:kabso_live/features/profile/category/category_picker.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_tag_icons.dart';
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
  static Key category(AccountCategory c) => CategoryPickerSheet.option(c);
  static const Key categoryNone = CategoryPickerSheet.none;
  static Key linkUrl(int i) => Key('profile.edit.link.$i.url');
  static Key linkLabel(int i) => Key('profile.edit.link.$i.label');
  static Key linkRemove(int i) => Key('profile.edit.link.$i.remove');
  static const linkAdd = Key('profile.edit.link.add');
  static const linksSave = Key('profile.edit.links.save');
  static const tagField = Key('profile.edit.tag.field');
  static const tagAdd = Key('profile.edit.tag.add');
  static Key tagChip(int i) => Key('profile.edit.tag.$i');

  /// D292: the new tag's icon button (beside the field).
  static const tagNewIcon = Key('profile.edit.tag.newIcon');
  static const tagsSave = Key('profile.edit.tags.save');
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

/// The category sheet: D386 — the 24 categories grouped by family, «بدون
/// فئة» and the verification on top ([CategoryPickerSheet]). A choice
/// saves at once; changing the category clears its verification (server).
Future<void> editCategory(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  // `(null)` is "No category"; closing the sheet is no record at all.
  final picked = await showModalBottomSheet<(AccountCategory?,)>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (sheet, scroll) => SafeArea(
        child: CategoryPickerSheet(
          current: user.category,
          verified: user.categoryVerified,
          locked: user.categoryLocked,
          scroll: scroll,
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
          // D357: the app owner keeps up to 7 (his page's social row).
          if (_links.length <
              (ref.watch(isKabsoOwnerProvider)
                  ? ProfileLinkRules.maxFounderLinks
                  : ProfileLinkRules.maxLinks)) ...[
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

/// D278b (owner: «منشنات يضعها الشخص معاه لغاية ١٠», §10.99): the tags
/// editor — up to 10 short tags (one line, 24 characters each, no
/// duplicates ignoring case), shown as chips on the profile cover. Save
/// sends the whole set (`PATCH /me {tags}`).
///
/// D292 (§10.106): each tag has an icon the person picks — the button
/// beside the field for a new tag, a tap on a tag's chip for one already
/// added ([showProfileTagIconPicker]); Save sends `tagIcons` with `tags`.
class EditTagsScreen extends ConsumerStatefulWidget {
  const new({required this.initial, super.key, this.initialIcons = const []});

  final List<String> initial;

  /// `Me.tagIcons` (one per tag; missing entries are `default`).
  final List<String> initialIcons;

  static const int maxTags = 10;
  static const int maxLength = 24;

  @override
  ConsumerState<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends ConsumerState<EditTagsScreen> {
  late final List<String> _tags = [...widget.initial];
  late final List<ProfileTagIcon> _initialIcons = ProfileTagIcon.listFor(
    widget.initial,
    widget.initialIcons,
  );
  late final List<ProfileTagIcon> _icons = [..._initialIcons];
  ProfileTagIcon _newIcon = ProfileTagIcon.none;
  final _field = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _tags.length != widget.initial.length ||
      _tags.indexed.any((e) => e.$2 != widget.initial[e.$1]) ||
      _icons.indexed.any((e) => e.$2 != _initialIcons[e.$1]);

  Future<void> _pickNewIcon() async {
    final icon = await showProfileTagIconPicker(context, current: _newIcon);
    if (icon != null && mounted) setState(() => _newIcon = icon);
  }

  Future<void> _pickIcon(int i) async {
    final icon = await showProfileTagIconPicker(context, current: _icons[i]);
    if (icon != null && mounted && i < _icons.length) {
      setState(() => _icons[i] = icon);
    }
  }

  /// The app's copy of the server's rule (§10.99); null when [tag] is fine.
  String? _issue(AppLocalizations l10n, String tag) {
    if (tag.runes.length > EditTagsScreen.maxLength) {
      return l10n.profileEditTagTooLong(EditTagsScreen.maxLength);
    }
    if (RegExp(r'[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2066-\u2069]')
        .hasMatch(tag)) {
      return l10n.profileEditTagInvalid;
    }
    final key = tag.toLowerCase();
    if (_tags.any((t) => t.toLowerCase() == key)) {
      return l10n.profileEditTagDuplicate;
    }
    return null;
  }

  void _add() {
    final l10n = context.l10n;
    final tag = _field.text.trim();
    if (tag.isEmpty || _tags.length >= EditTagsScreen.maxTags) return;
    final issue = _issue(l10n, tag);
    setState(() {
      _error = issue;
      if (issue == null) {
        _tags.add(tag);
        _icons.add(_newIcon);
        _newIcon = ProfileTagIcon.none;
        _field.clear();
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref.read(saveProfileFieldsProvider)(
        ProfileFieldsChange(
          tags: [..._tags],
          tagIcons: [for (final icon in _icons) icon.wire],
        ),
      );
      if (!mounted) return;
      KSnack.success(context, l10n.profileEditSaved);
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      String? shown;
      if (failure is ServerFailure) {
        for (final d in failure.details) {
          if (!d.field.startsWith('tags') && !d.field.startsWith('tagIcons')) {
            continue;
          }
          shown = switch (d.issue) {
            'too_long' => l10n.profileEditTagTooLong(EditTagsScreen.maxLength),
            'invalid_value' => l10n.profileEditTagDuplicate,
            'too_many' => l10n.profileEditTagsFull,
            _ => l10n.profileEditTagInvalid,
          };
          break;
        }
      }
      setState(() {
        _saving = false;
        _error = shown;
      });
      if (shown == null) KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final full = _tags.length >= EditTagsScreen.maxTags;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.profileEditTags),
        actions: [
          TextButton(
            key: EditProfileFieldsKeys.tagsSave,
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
            '${l10n.profileEditTagsHint} ${l10n.profileEditTagsIconHint}',
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // D292: the new tag's icon.
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.xs),
                child: IconButton.outlined(
                  key: EditProfileFieldsKeys.tagNewIcon,
                  tooltip: l10n.profileTagIconNew(
                    _newIcon.label(l10n, arabic: arabic),
                  ),
                  onPressed: _saving || full ? null : _pickNewIcon,
                  icon: ProfileTagIconView(
                    icon: _newIcon,
                    size: 22,
                    noneIcon: true,
                  ),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: TextField(
                  key: EditProfileFieldsKeys.tagField,
                  controller: _field,
                  enabled: !_saving && !full,
                  maxLength: EditTagsScreen.maxLength,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    labelText: l10n.profileEditTagField,
                    errorText:
                        _error ?? (full ? l10n.profileEditTagsFull : null),
                    errorMaxLines: 2,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.xs),
                child: FilledButton(
                  key: EditProfileFieldsKeys.tagAdd,
                  onPressed: _saving || full ? null : _add,
                  child: Text(l10n.profileEditTagAdd),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.lg),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final (i, tag) in _tags.indexed)
                InputChip(
                  key: EditProfileFieldsKeys.tagChip(i),
                  shape: const StadiumBorder(),
                  // D292: the tag's icon; a tap on the chip changes it.
                  avatar: ProfileTagIconView(
                    icon: _icons[i],
                    size: 18,
                    noneIcon: true,
                  ),
                  label: Text(tag),
                  tooltip: l10n.profileTagIconChange(tag),
                  onPressed: _saving ? null : () => _pickIcon(i),
                  deleteButtonTooltipMessage: l10n.profileEditTagRemove(tag),
                  onDeleted: _saving
                      ? null
                      : () => setState(() {
                          _tags.removeAt(i);
                          _icons.removeAt(i);
                          _error = null;
                        }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
