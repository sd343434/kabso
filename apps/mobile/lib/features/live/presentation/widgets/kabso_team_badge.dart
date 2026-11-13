import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D260 (owner: staff who watch a live are shown, so the host knows the live
/// is watched): the Kabso Team's colours — a calm blue, unlike any level,
/// VIP or agent badge.
abstract final class KabsoTeamColors {
  static const start = Color(0xFF0EA5E9);
  static const end = Color(0xFF2563EB);
  static const gradient = LinearGradient(colors: [start, end]);
}

/// D282 (owner: «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه
/// عربي وانجليزي لمن هاتفه انجليزي»): THE «فريق كابسو» badge — the owner's
/// crest and banner ([asset]; D282c: the red-and-gold crest with Kabi in a
/// headset, replacing the green one), the team's name written in the banner
/// in the app's language («فريق كابسو» / "Kabso Team"). Drawn [height] tall
/// at the art's own [aspectRatio] wherever the team is shown: before a staff
/// line's name in every chat mode (D269's team tag), the viewer list's staff
/// group (D260), the person card and profile of a staff account, the staff
/// tools sheet and the shift page (D273).
///
/// Right-to-left: the art is NOT mirrored — the crest stays on the left as
/// drawn (a mirrored crown and laurels would read as a different emblem) —
/// and the Arabic name is centred in the banner like the English one.
class KabsoTeamBadge extends StatelessWidget {
  const new({super.key, this.height = 18});

  static const badgeKey = Key('live.kabsoTeam.badge');

  /// The team's name inside the banner.
  static const labelKey = Key('live.kabsoTeam.badge.label');

  /// The owner's art (assets/staff/PROVENANCE.md), trimmed to its bounds.
  static const asset = 'assets/staff/kabso_team_badge.png';

  /// The art's width ÷ height (720 × 328 px).
  static const double aspectRatio = 720 / 328;

  /// The banner's inner (green) area, as fractions of the art's width and
  /// height, so the name scales with the badge.
  static const banner = Rect.fromLTRB(0.555, 0.449, 0.875, 0.727);

  /// D282b (owner: «نكبّرها في الدردشة»): in a chat line the badge is
  /// taller than the line's other emblems so its name reads — 24 pt in the
  /// boxed, inline and VIP rows (the smallest height where «فريق كابسو» /
  /// "Kabso Team" reads clearly) …
  static const double chatHeight = 24;

  /// … and 22 pt on the host's compact flat line (still readable).
  static const double flatChatHeight = 22;

  /// D292 (owner, on the profile: «شارة فريق كابسو صغيرة وغير واضحة»):
  /// beside the name on the profile header and the Me hub (was 20 / 22,
  /// where the banner's name was ≈ 3.5 pt). D299i (owner: «ميدالية مشرفين
  /// يجب ان تكون الايقونة بحجم اكبر ليكون كلام مكتوب بداخلها واضح»): 44 pt
  /// (was 30, a ≈ 5 pt name) — the banner's name is now ≈ 7.5 pt; in a
  /// tight row the badge wraps to its own line, never shrinks.
  static const double profileHeight = 44;

  /// D299i: the live person card, after the name (was 24, the name's line).
  static const double cardHeight = 32;

  /// D299i: before «إعلان رسمي — فريق كابسو» in the composer (was 22).
  static const double announcementHeight = 28;

  /// D282c (owner: «ولون الخط في داخلها ذهبي مناسب»): the name in a warm
  /// gold matching the banner's frame, bold, over a thin dark shadow so it
  /// reads on the red.
  static const ink = Color(0xFFFFD36A);

  final double height;

  double get width => height * aspectRatio;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final bannerW = banner.width * w;
    final bannerH = banner.height * height;
    return Semantics(
      label: context.l10n.liveKabsoTeam,
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          key: badgeKey,
          width: w,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  asset,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              // Absolute (never directional) offsets: the banner is where
              // the art draws it, in either direction.
              Positioned(
                left: banner.left * w,
                top: banner.top * height,
                width: bannerW,
                height: bannerH,
                // D299i: thinner insets and a larger name, so the name
                // fills the banner (still scaled down to fit, never cut).
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: bannerW * 0.035,
                    vertical: bannerH * 0.06,
                  ),
                  child: Center(
                    // Auto-fit: a long name (or a small badge) scales down,
                    // never overflows the banner.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.liveKabsoTeam,
                        key: labelKey,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: context.textStyles.caption.copyWith(
                          fontSize: bannerH * 0.70,
                          height: 1.15,
                          color: ink,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: const Color(0xE6400000),
                              offset: Offset(0, bannerH * 0.04),
                              blurRadius: bannerH * 0.05,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D260: the team's shield by the top viewers while staff watch the live —
/// never a face among the supporters, never ranked, not counted.
class KabsoTeamShield extends StatelessWidget {
  const new({required this.size, super.key});

  static const shieldKey = Key('live.kabsoTeam.shield');

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.liveKabsoTeamHere,
    child: Container(
      key: shieldKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: KabsoTeamColors.gradient,
        border: Border.all(color: const Color(0xCCFFFFFF)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.verified_user_rounded,
        size: size * 0.6,
        color: const Color(0xFFFFFFFF),
      ),
    ),
  );
}

/// D260: what a tap on a staff entry shows — who the Kabso Team is (no
/// person card, no actions).
Future<void> showKabsoTeamInfo(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialog) => AlertDialog(
    icon: const KabsoTeamShield(size: 44),
    title: Text(dialog.l10n.liveKabsoTeamInfoTitle),
    content: Text(dialog.l10n.liveKabsoTeamInfo, textAlign: TextAlign.center),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialog).pop(),
        child: Text(MaterialLocalizations.of(dialog).okButtonLabel),
      ),
    ],
  ),
);
