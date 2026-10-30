import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// D175 (owner, contract v1.47-social, CONVENTIONS §10.47): how the profile
/// fields read and behave — the gender and category names, the gender
/// choice of Register and Edit profile, the line under the name, the links
/// row and opening a link (known platforms directly; any other link only
/// after «أنت تغادر Kabso» with the full URL).

String genderLabel(AppLocalizations l10n, Gender gender) => switch (gender) {
  Gender.male => l10n.genderMale,
  Gender.female => l10n.genderFemale,
  Gender.undisclosed => l10n.genderUndisclosed,
};

String categoryLabel(AppLocalizations l10n, AccountCategory category) =>
    switch (category) {
      AccountCategory.singer => l10n.categorySinger,
      AccountCategory.musician => l10n.categoryMusician,
      AccountCategory.poet => l10n.categoryPoet,
      AccountCategory.presenter => l10n.categoryPresenter,
      AccountCategory.gamer => l10n.categoryGamer,
      AccountCategory.contentCreator => l10n.categoryContentCreator,
      AccountCategory.athlete => l10n.categoryAthlete,
      AccountCategory.artist => l10n.categoryArtist,
      AccountCategory.blogger => l10n.categoryBlogger,
      AccountCategory.publicFigure => l10n.categoryPublicFigure,
      AccountCategory.other => l10n.categoryOther,
    };

/// The three gender choices as chips (one selectable), with a label, a
/// helper line and an error (Register: required).
class GenderChoice extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.optionKey,
    super.key,
    this.helper,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final String? helper;
  final Gender? value;
  final ValueChanged<Gender> onChanged;
  final Key Function(Gender) optionKey;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodyStrong.copyWith(color: p.textPrimary)),
        const SizedBox(height: KSpacing.xs),
        Wrap(
          spacing: KSpacing.sm,
          children: [
            for (final g in Gender.values)
              KChip(
                key: optionKey(g),
                label: genderLabel(l10n, g),
                selected: value == g,
                onSelected: enabled ? () => onChanged(g) : null,
              ),
          ],
        ),
        if (error != null)
          Text(error, style: t.caption.copyWith(color: p.error))
        else if (helper != null)
          Text(helper!, style: t.caption.copyWith(color: p.textSecondary)),
      ],
    );
  }
}

/// The line under the name: the account category (and the gender when the
/// user shows it), e.g. «شاعر · أنثى».
class ProfileFieldsLine extends StatelessWidget {
  const new({super.key, this.category, this.gender});

  final AccountCategory? category;

  /// Already filtered: only a gender the user shows (MALE / FEMALE).
  final Gender? gender;

  static const lineKey = Key('profile.fieldsLine');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final parts = [
      if (category case final c?) categoryLabel(l10n, c),
      if (gender case final g? when g != Gender.undisclosed)
        genderLabel(l10n, g),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.xxs),
      child: Text(
        parts.join(' · '),
        key: lineKey,
        style: context.textStyles.body.copyWith(color: p.textSecondary),
      ),
    );
  }
}

/// Opens a URL outside the app (the system browser or the platform's
/// app). A fake in tests.
abstract interface class ExternalLinkOpener {
  /// Whether the system opened [url].
  Future<bool> open(Uri url);
}

class UrlLauncherLinkOpener implements ExternalLinkOpener {
  const new();

  @override
  Future<bool> open(Uri url) =>
      launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
}

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => const UrlLauncherLinkOpener(),
);

/// Keys of the link UI (tests).
abstract final class ProfileLinkKeys {
  static Key chip(int index) => Key('profile.link.$index');
  static const leavingSheet = Key('profile.link.leaving');
  static const leavingUrl = Key('profile.link.leaving.url');
  static const leavingOpen = Key('profile.link.leaving.open');
  static const report = Key('profile.link.report');
  static const copy = Key('profile.link.copy');
}

/// The profile's links as tappable chips (wrapping). A tap opens the link
/// ([openProfileLink]); a long press offers Copy and, on another person's
/// profile, Report.
class ProfileLinksRow extends ConsumerWidget {
  const new({required this.links, required this.reportable, super.key});

  final List<ProfileLink> links;

  /// Another person's profile: the links can be reported.
  final bool reportable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (links.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.xs),
      child: Wrap(
        spacing: KSpacing.md,
        runSpacing: KSpacing.xxs,
        children: [
          for (final (i, link) in links.indexed)
            Semantics(
              link: true,
              label: l10n.linkSemantics(link.display),
              excludeSemantics: true,
              child: InkWell(
                key: ProfileLinkKeys.chip(i),
                borderRadius: BorderRadius.circular(KRadius.sm),
                onTap: () =>
                    openProfileLink(context, ref, link, reportable: reportable),
                onLongPress: () =>
                    showLinkActions(context, ref, link, reportable: reportable),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KSizes.minTouchTarget,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(AppIcons.link, size: 16, color: p.primary),
                      const SizedBox(width: KSpacing.xxs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          link.display,
                          // Addresses read left to right in Arabic too.
                          textDirection: link.label == null
                              ? TextDirection.ltr
                              : null,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: p.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens [link]: a known platform (Instagram, TikTok, YouTube, Facebook, X)
/// at once; any other link only after «أنت تغادر Kabso» shows the full URL
/// and the person confirms (owner, D175).
Future<void> openProfileLink(
  BuildContext context,
  WidgetRef ref,
  ProfileLink link, {
  required bool reportable,
}) async {
  final l10n = context.l10n;
  if (!link.platform.known) {
    final choice = await showModalBottomSheet<_Leaving>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _LeavingSheet(url: link.url, reportable: reportable),
    );
    if (!context.mounted) return;
    if (choice == _Leaving.report) {
      await reportProfileLink(context, ref, link);
      return;
    }
    if (choice != _Leaving.open) return;
  }
  final uri = Uri.tryParse(link.url);
  var opened = false;
  if (uri != null && uri.scheme == 'https') {
    try {
      opened = await ref.read(externalLinkOpenerProvider).open(uri);
    } on PlatformException {
      opened = false;
    }
  }
  if (!opened && context.mounted) KSnack.error(context, l10n.linkOpenFailed);
}

enum _Leaving { open, report }

/// D175's «أنت تغادر Kabso» before opening [url] outside the app (D185: the
/// recharge directory's «تواصل» opens WhatsApp, which is not one of the
/// platforms opened directly). True when the person chose to open it.
Future<bool> confirmLeavingKabso(BuildContext context, String url) async {
  final choice = await showModalBottomSheet<_Leaving>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _LeavingSheet(url: url, reportable: false),
  );
  return choice == _Leaving.open;
}

class _LeavingSheet extends StatelessWidget {
  const new({required this.url, required this.reportable});

  final String url;
  final bool reportable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return SafeArea(
      child: Padding(
        key: ProfileLinkKeys.leavingSheet,
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.open_in_new_rounded, color: p.primary, size: 32),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.linkLeavingTitle,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.linkLeavingBody,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            // The whole address, never shortened: the person decides.
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: p.surfaceOverlay,
                borderRadius: BorderRadius.circular(KRadius.sm),
              ),
              child: SelectableText(
                url,
                key: ProfileLinkKeys.leavingUrl,
                textDirection: TextDirection.ltr,
                style: t.body.copyWith(color: p.textPrimary),
              ),
            ),
            const SizedBox(height: KSpacing.lg),
            KButton(
              key: ProfileLinkKeys.leavingOpen,
              label: l10n.linkLeavingOpen,
              onPressed: () => Navigator.of(context).pop(_Leaving.open),
            ),
            const SizedBox(height: KSpacing.xs),
            KButton(
              label: l10n.actionCancel,
              variant: KButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (reportable)
              TextButton.icon(
                key: ProfileLinkKeys.report,
                onPressed: () => Navigator.of(context).pop(_Leaving.report),
                icon: Icon(Icons.flag_outlined, color: p.error),
                label: Text(l10n.linkReport, style: TextStyle(color: p.error)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Long press on a link: Copy, and Report on another person's profile.
Future<void> showLinkActions(
  BuildContext context,
  WidgetRef ref,
  ProfileLink link, {
  required bool reportable,
}) async {
  final l10n = context.l10n;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) {
      final p = sheet.palette;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                link.url,
                textDirection: TextDirection.ltr,
                style: sheet.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
            ListTile(
              key: ProfileLinkKeys.copy,
              leading: Icon(Icons.copy_rounded, color: p.textPrimary),
              title: Text(l10n.linkCopy),
              onTap: () => Navigator.of(sheet).pop('copy'),
            ),
            if (reportable)
              ListTile(
                key: ProfileLinkKeys.report,
                leading: Icon(Icons.flag_outlined, color: p.error),
                title: Text(l10n.linkReport, style: TextStyle(color: p.error)),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
          ],
        ),
      );
    },
  );
  if (!context.mounted) return;
  switch (action) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: link.url));
      if (context.mounted) KSnack.success(context, l10n.linkCopied);
    case 'report':
      await reportProfileLink(context, ref, link);
  }
}

/// Asks why, then reports the link (`targetType: PROFILE_LINK`, §11.7).
Future<void> reportProfileLink(
  BuildContext context,
  WidgetRef ref,
  ProfileLink link,
) async {
  final l10n = context.l10n;
  final reason = await pickReportReason(context, l10n.linkReportTitle);
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(safetyRepositoryProvider).reportProfileLink(link.id, reason);
    if (context.mounted) KSnack.success(context, l10n.feedPostReported);
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}
