import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountries, rechargeCountryName;
import 'package:kabso_live/features/recruits/data/recruits_repository.dart'
    show CreatorCategory;
import 'package:kabso_live/features/recruits/presentation/creator_apply_screen.dart'
    show CreatorApplyScreen, creatorCategoryName;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.82-live (D295, owner, CONVENTIONS §10.108.6): the agency owner
/// activates one of the agency's members as «مضيف» or «صانع محتوى».
///
/// The sheet shows the two choices. «صانع محتوى» needs the creator
/// programme's fields (country, content type, 1–5 links, an optional bio),
/// shows the note «نسبة صانع المحتوى 72%» and the owner's warning «إن قمت
/// بتفعيل شخص على أنه صانع محتوى ولم يكن كذلك، سيتم حظر الوكالة وخسارة
/// أرباحك.», which must be ticked before the button works. The server
/// answers with the member's row (popped to the caller).
Future<AgencyHostRow?> showAgencyActivationSheet(
  BuildContext context,
  AgencyHostRow member,
) => showModalBottomSheet<AgencyHostRow>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => AgencyActivationSheet(member: member),
);

class AgencyActivationSheet extends ConsumerStatefulWidget {
  const new({required this.member, super.key});

  final AgencyHostRow member;

  static const hostChoiceKey = Key('agencyActivate.host');
  static const creatorChoiceKey = Key('agencyActivate.creator');
  static const noteKey = Key('agencyActivate.note');
  static const warningKey = Key('agencyActivate.warning');
  static const confirmKey = Key('agencyActivate.confirm');
  static const submitKey = Key('agencyActivate.submit');
  static const countryKey = Key('agencyActivate.country');
  static Key linkKey(int i) => Key('agencyActivate.link.$i');
  static Key categoryKey(CreatorCategory c) =>
      Key('agencyActivate.cat.${c.wire}');

  @override
  ConsumerState<AgencyActivationSheet> createState() =>
      _AgencyActivationSheetState();
}

class _AgencyActivationSheetState extends ConsumerState<AgencyActivationSheet> {
  /// null: nothing chosen yet; false: host; true: creator.
  bool? _creator;
  String? _country;
  CreatorCategory? _category;
  final List<TextEditingController> _links = [TextEditingController()];
  final TextEditingController _bio = TextEditingController();
  bool _confirmed = false;
  bool _tried = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _links) {
      c.dispose();
    }
    _bio.dispose();
    super.dispose();
  }

  static bool _linkOk(String v) =>
      RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(v.trim());

  List<String> get _filledLinks => [
    for (final c in _links)
      if (c.text.trim().isNotEmpty) c.text.trim(),
  ];

  bool get _creatorValid =>
      _country != null &&
      _category != null &&
      _filledLinks.isNotEmpty &&
      _links.every((c) => c.text.trim().isEmpty || _linkOk(c.text));

  String _refusal(AppLocalizations l10n, AppFailure failure) {
    if (failure is ServerFailure &&
        failure.code == ErrorCode.agencyActivationNotAllowed) {
      return switch (failure.details.firstOrNull?.issue) {
        'HOST' => l10n.agencyActivationRefusedHost,
        'CREATOR' => l10n.agencyActivationRefusedCreator,
        'AGENCY_SUSPENDED' => l10n.agencyActivationRefusedSuspended,
        _ => failureMessage(l10n, failure),
      };
    }
    return failureMessage(l10n, failure);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final creator = _creator;
    if (creator == null) return;
    setState(() {
      _tried = true;
      _error = null;
    });
    if (creator && (!_creatorValid || !_confirmed)) return;
    setState(() => _busy = true);
    try {
      final draft = creator
          ? AgencyActivationDraft.creator(
              country: _country!,
              category: _category!.wire,
              links: _filledLinks,
              bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
              confirmCreator: _confirmed,
            )
          : const AgencyActivationDraft.host();
      final row = await ref
          .read(agencyRepositoryProvider)
          .activateMember(widget.member.user.id, draft);
      if (mounted) Navigator.of(context).pop(row);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = _refusal(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final creator = _creator;
    final name = widget.member.user.displayName;

    Widget choice({
      required Key key,
      required bool value,
      required IconData icon,
      required String title,
      required String body,
      Widget? trailing,
    }) {
      final selected = creator == value;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(KRadius.lg),
          onTap: _busy
              ? null
              : () => setState(() {
                  _creator = value;
                  _error = null;
                }),
          child: Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? (value ? CreatorLiveBadge.purple : p.primary).withValues(
                      alpha: 0.10,
                    )
                  : p.surface,
              borderRadius: BorderRadius.circular(KRadius.lg),
              border: Border.all(
                color: selected
                    ? (value ? CreatorLiveBadge.purple : p.primary)
                    : p.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: value ? CreatorLiveBadge.purple : p.primary),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: KSpacing.xs),
                            trailing,
                          ],
                        ],
                      ),
                      const SizedBox(height: KSpacing.xxs),
                      Text(
                        body,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? (value ? CreatorLiveBadge.purple : p.primary)
                      : p.textTertiary,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.agencyActivateTitle(name),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.agencyActivateIntro,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            choice(
              key: AgencyActivationSheet.hostChoiceKey,
              value: false,
              icon: Icons.videocam_rounded,
              title: l10n.agencyActivateAsHost,
              body: l10n.agencyActivateAsHostBody,
            ),
            const SizedBox(height: KSpacing.sm),
            choice(
              key: AgencyActivationSheet.creatorChoiceKey,
              value: true,
              icon: Icons.auto_awesome_rounded,
              title: l10n.agencyActivateAsCreator,
              body: l10n.agencyActivateAsCreatorBody,
              trailing: const CreatorLiveBadge(compact: true),
            ),
            if (creator ?? false) ...[
              const SizedBox(height: KSpacing.md),
              Container(
                key: AgencyActivationSheet.noteKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: CreatorLiveBadge.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.percent_rounded,
                      size: 18,
                      color: CreatorLiveBadge.purple,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.agencyCreatorShareNote,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.md),
              DropdownButtonFormField<String>(
                key: AgencyActivationSheet.countryKey,
                initialValue: _country,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.creatorProgrammeCountry,
                  errorText: _tried && _country == null
                      ? l10n.hostApplyCountryError
                      : null,
                ),
                items: [
                  for (final c in rechargeCountries)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        rechargeCountryName(context, c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (c) => setState(() => _country = c),
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.creatorProgrammeCategory,
                style: t.bodyStrong.copyWith(
                  color: _tried && _category == null ? p.error : p.textPrimary,
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final c in CreatorCategory.values)
                    ChoiceChip(
                      key: AgencyActivationSheet.categoryKey(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                      label: Text(creatorCategoryName(l10n, c)),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.creatorProgrammeLinks,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: KSpacing.xs),
              for (final (i, c) in _links.indexed) ...[
                KTextField(
                  fieldKey: AgencyActivationSheet.linkKey(i),
                  label: 'https://',
                  controller: c,
                  maxLength: 200,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  errorText:
                      _tried &&
                          ((i == 0 && _filledLinks.isEmpty) ||
                              (c.text.trim().isNotEmpty && !_linkOk(c.text)))
                      ? l10n.creatorProgrammeLinkError
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: KSpacing.xs),
              ],
              if (_links.length < CreatorApplyScreen.maxLinks)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _links.add(TextEditingController())),
                    icon: const Icon(Icons.add_link_rounded),
                    label: Text(l10n.creatorProgrammeAddLink),
                  ),
                ),
              const SizedBox(height: KSpacing.sm),
              KTextField(
                label: l10n.creatorProgrammeBio,
                controller: _bio,
                maxLength: 300,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: KSpacing.md),
              Container(
                key: AgencyActivationSheet.warningKey,
                padding: const EdgeInsets.all(KSpacing.md),
                decoration: BoxDecoration(
                  color: p.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(KRadius.md),
                  border: Border.all(color: p.error.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: p.error),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.agencyCreatorWarning,
                            style: t.bodyStrong.copyWith(color: p.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpacing.xs),
                    // Its own Material: the warning's tinted box would hide the
                    // tile's ink.
                    Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        key: AgencyActivationSheet.confirmKey,
                        value: _confirmed,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _confirmed = v ?? false),
                        title: Text(
                          l10n.agencyCreatorConfirm,
                          style: t.body.copyWith(color: p.textPrimary),
                        ),
                        subtitle: _tried && !_confirmed
                            ? Text(
                                l10n.agencyCreatorConfirmError,
                                style: t.caption.copyWith(color: p.error),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: KSpacing.sm),
              Text(e, style: t.caption.copyWith(color: p.error)),
            ],
            const SizedBox(height: KSpacing.lg),
            KButton(
              key: AgencyActivationSheet.submitKey,
              label: (creator ?? false)
                  ? l10n.agencyActivateCreatorButton
                  : l10n.agencyActivateHostButton,
              onPressed: creator == null || _busy || (creator && !_confirmed)
                  ? null
                  : () => unawaited(_submit()),
            ),
          ],
        ),
      ),
    );
  }
}
