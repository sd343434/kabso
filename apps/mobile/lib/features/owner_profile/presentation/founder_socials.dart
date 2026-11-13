// D357 (owner, 2026-11-10: «تحت البايو ضع اشارة السوشل ميديا مثل انستقرام
// وفيسبوك وواتساب وسناب شات لنضيف صفحاتنا عليها»; CONVENTIONS §10.153): the
// founder page's social row under his bio — one round button per platform
// he linked (Instagram, Facebook, WhatsApp, Snapchat, always in that order,
// in Arabic and English alike), drawn from his own profile links (§10.47,
// edited in «تعديل الملف» → «الروابط»; no second store). A platform he did
// not link has no button; none linked → no row.
//
// The marks: Simple Icons 15.9.0 (CC0), unaltered, in one colour (the
// theme's text colour) in a neutral circle — `assets/icons/social/README.md`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The founder's social row (see the file's note).
class FounderSocialRow extends ConsumerWidget {
  const new({required this.links, required this.reportable, super.key});

  /// All his profile links; the row takes the first of each platform.
  final List<ProfileLink> links;

  /// A visitor's view (a long press elsewhere can report a link).
  final bool reportable;

  static const rowKey = Key('founder.socials');
  static Key buttonKey(ProfileLinkPlatform p) =>
      Key('founder.social.${p.wire}');

  /// The circle (≥ 40 dp) and its 48 dp target; the mark inside it.
  static const double circle = 44;
  static const double target = 48;
  static const double mark = 22;
  static const double gap = KSpacing.md;

  /// The links the row shows, in its order: the first of each platform.
  static List<ProfileLink> shown(List<ProfileLink> links) => [
    for (final p in ProfileLinkRules.founderSocials)
      ?links.where((l) => l.platform == p).firstOrNull,
  ];

  /// The bundled mark of [p] (one of [ProfileLinkRules.founderSocials]).
  static String assetOf(ProfileLinkPlatform p) =>
      'assets/icons/social/${p.wire.toLowerCase()}.svg';

  static String labelOf(AppLocalizations l10n, ProfileLinkPlatform p) =>
      switch (p) {
        ProfileLinkPlatform.instagram => l10n.founderSocialInstagram,
        ProfileLinkPlatform.facebook => l10n.founderSocialFacebook,
        ProfileLinkPlatform.whatsapp => l10n.founderSocialWhatsApp,
        ProfileLinkPlatform.snapchat => l10n.founderSocialSnapchat,
        _ => p.wire,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = shown(links);
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    return Directionality(
      // The same order in Arabic and English (the owner's list).
      textDirection: TextDirection.ltr,
      child: Row(
        key: rowKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, link) in items.indexed) ...[
            if (i > 0) const SizedBox(width: gap),
            Tooltip(
              message: labelOf(l10n, link.platform),
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                link: true,
                label: labelOf(l10n, link.platform),
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: target,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkResponse(
                      key: buttonKey(link.platform),
                      radius: target / 2,
                      onTap: () => openProfileLink(
                        context,
                        ref,
                        link,
                        reportable: reportable,
                      ),
                      child: Center(
                        child: Container(
                          width: circle,
                          height: circle,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.surfaceRaised,
                            border: Border.all(color: p.border),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            assetOf(link.platform),
                            width: mark,
                            height: mark,
                            excludeFromSemantics: true,
                            colorFilter: ColorFilter.mode(
                              p.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
