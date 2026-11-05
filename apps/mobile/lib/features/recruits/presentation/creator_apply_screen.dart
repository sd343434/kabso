import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountries, rechargeCountryName;
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/features/recruits/presentation/recruiter_field.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The category's name in the app's language.
String creatorCategoryName(AppLocalizations l10n, CreatorCategory c) =>
    switch (c) {
      CreatorCategory.video => l10n.creatorCatVideo,
      CreatorCategory.photo => l10n.creatorCatPhoto,
      CreatorCategory.music => l10n.creatorCatMusic,
      CreatorCategory.gaming => l10n.creatorCatGaming,
      CreatorCategory.comedy => l10n.creatorCatComedy,
      CreatorCategory.education => l10n.creatorCatEducation,
      CreatorCategory.lifestyle => l10n.creatorCatLifestyle,
      CreatorCategory.other => l10n.creatorCatOther,
    };

/// v1.75-live (D285): «انضم كصانع محتوى» — the creator programme's
/// application (from the creator centre): country, content type, 1–5 links,
/// an optional bio and the optional recruiter field; then its status.
class CreatorApplyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const submitKey = Key('creatorApply.submit');
  static const statusKey = Key('creatorApply.status');
  static Key linkKey(int i) => Key('creatorApply.link.$i');
  static Key categoryKey(CreatorCategory c) =>
      Key('creatorApply.cat.${c.wire}');
  static const maxLinks = 5;

  @override
  ConsumerState<CreatorApplyScreen> createState() => _CreatorApplyScreenState();
}

class _CreatorApplyScreenState extends ConsumerState<CreatorApplyScreen> {
  late String? _country = switch (ref
      .read(currentUserProvider)
      ?.country
      ?.toUpperCase()) {
    final String c when rechargeCountries.contains(c) => c,
    _ => null,
  };
  CreatorCategory _category = CreatorCategory.video;
  final List<TextEditingController> _links = [TextEditingController()];
  final _bio = TextEditingController();
  RecruiterCheck _recruiter = RecruiterCheck.empty;
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

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _tried = true;
      _error = null;
    });
    final country = _country;
    if (country == null ||
        !_links.every((c) => _linkOk(c.text)) ||
        !_recruiter.ok) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(recruitsRepositoryProvider)
          .applyCreator(
            CreatorApplicationDraft(
              country: country,
              category: _category,
              links: [for (final c in _links) c.text.trim()],
              bio: _bio.text.trim(),
              recruiter: _recruiter.value,
            ),
          );
      if (!mounted) return;
      ref.invalidate(myCreatorApplicationProvider);
      KSnack.success(context, l10n.creatorProgrammeSent);
      setState(() => _busy = false);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() {
        _busy = false;
        _error = failure.code == ErrorCode.validationFailed
            ? l10n.recruiterFixError
            : failureMessage(l10n, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myCreatorApplicationProvider);
    final status = mine.value;
    Widget? banner;
    if (status != null && !status.canApply) {
      final text = status.member
          ? l10n.creatorProgrammeMember
          : status.refusal == 'STAFF'
          ? l10n.creatorProgrammeStaff
          : l10n.creatorProgrammePending;
      banner = Container(
        key: CreatorApplyScreen.statusKey,
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              status.member
                  ? Icons.auto_awesome_rounded
                  : Icons.hourglass_top_rounded,
              color: p.primary,
              size: 40,
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            if (status.status == 'PENDING') ...[
              const SizedBox(height: KSpacing.md),
              TextButton(
                onPressed: () async {
                  await ref.read(recruitsRepositoryProvider).cancelCreator();
                  ref.invalidate(myCreatorApplicationProvider);
                },
                child: Text(l10n.creatorProgrammeCancel),
              ),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.creatorProgrammeTitle),
        leading: context.canPop() ? null : const SizedBox.shrink(),
      ),
      body: switch (mine) {
        AsyncError(:final error) => Center(
          child: Text(failureMessage(l10n, toAppFailure(error))),
        ),
        AsyncData() when banner != null => Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: banner,
        ),
        AsyncData() => ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: [
            Text(
              l10n.creatorProgrammeIntro,
              style: t.body.copyWith(color: p.textSecondary),
            ),
            if (status?.status == 'REJECTED' && status?.rejectReason != null)
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.sm),
                child: Text(
                  l10n.creatorProgrammeRejected(status!.rejectReason!),
                  style: t.caption.copyWith(color: p.error),
                ),
              ),
            const SizedBox(height: KSpacing.md),
            DropdownButtonFormField<String>(
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
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Wrap(
              spacing: KSpacing.xs,
              runSpacing: KSpacing.xs,
              children: [
                for (final c in CreatorCategory.values)
                  ChoiceChip(
                    key: CreatorApplyScreen.categoryKey(c),
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
                fieldKey: CreatorApplyScreen.linkKey(i),
                label: 'https://',
                controller: c,
                maxLength: 200,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                errorText: _tried && !_linkOk(c.text)
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
            const SizedBox(height: KSpacing.sm),
            RecruiterField(
              showError: _tried,
              onChanged: (c) => setState(() => _recruiter = c),
            ),
            if (_error case final e?) ...[
              const SizedBox(height: KSpacing.sm),
              Text(e, style: t.caption.copyWith(color: p.error)),
            ],
            const SizedBox(height: KSpacing.lg),
            FilledButton(
              key: CreatorApplyScreen.submitKey,
              onPressed: _busy ? null : () => unawaited(_submit()),
              child: Text(l10n.creatorProgrammeSubmit),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
