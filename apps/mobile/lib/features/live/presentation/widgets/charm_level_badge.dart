import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D101: the owner's ten charm tiers (the charm pack). Every 10 levels a new
/// Kabi creature: 1–10 sprout, 11–20 bunny … 91–100 King Kabi; a level above
/// 100 keeps the last tier (CONVENTIONS §10.18).
enum CharmTier {
  sprout(Color(0xFF2FA35A), Color(0xFF8BE07A)),
  bunny(Color(0xFFE8508F), Color(0xFFFF9CC6)),
  kitty(Color(0xFFE0702A), Color(0xFFFFB36B)),
  butterfly(Color(0xFF7B4FE0), Color(0xFFB993FF)),
  fox(Color(0xFFE2560A), Color(0xFFFFA43A)),
  owl(Color(0xFF2459D6), Color(0xFF63A6FF)),
  unicorn(Color(0xFFB048E0), Color(0xFFF08CD8)),
  dragon(Color(0xFFB30D1A), Color(0xFFFF5040)),
  phoenix(Color(0xFFE06A00), Color(0xFFFFC93A)),
  royal(Color(0xFF5A22B8), Color(0xFFC15CFF));

  new(this.pillStart, this.pillEnd);

  /// The pill's gradient, from the owner's pack.
  final Color pillStart;
  final Color pillEnd;

  /// 1–10.
  int get number => index + 1;

  /// The tier of [level] (1 … 100; outside it, the nearest end).
  static CharmTier of(int level) => values[(level.clamp(1, 100) - 1) ~/ 10];

  String get _file => 'charm_${number.toString().padLeft(2, '0')}_$name';

  /// The tight-cropped creature for the level pill (`assets/charm/`).
  String get icon => 'assets/charm/${_file}_icon.png';

  /// The tap character of this tier (`assets/taps/`).
  String get tap =>
      'assets/taps/tap_${number.toString().padLeft(2, '0')}_$name.png';
}

/// D101 (owner's charm pack): the room level next to the room name — the
/// tier's creature overlapping the start of a gradient pill with the level
/// number. Laid out [height] tall; the creature overflows it (1.55 ×) without
/// taking room from the line, so it fits inside a one-line title row.
class CharmLevelBadge extends StatelessWidget {
  const new({required this.level, super.key, this.height = 14});

  final int level;
  final double height;

  /// D135 (owner: "the charm badge in the chat is bigger than the room
  /// level's"): the one size of the badge in a line of text — the chat
  /// rows and the room's level chip — so its creature (1.55 ×, 15.5 pt)
  /// matches the other badges of the row (14–16 pt).
  static const double lineHeight = 10;

  static const badgeKey = Key('live.roomLevel');

  @override
  Widget build(BuildContext context) {
    final tier = CharmTier.of(level);
    final h = height;
    final icon = h * 1.55;
    final gold = tier.number >= 8;
    final number = TextStyle(
      fontSize: h * 0.78,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      letterSpacing: -0.3,
    );
    return Semantics(
      key: badgeKey,
      label: context.l10n.liveRoomLevelBadge(level),
      excludeSemantics: true,
      // The number reads left to right in both languages; the creature
      // stays at the pill's left, as in the owner's pack.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          // The creature's left edge at 0; it covers the pill's first 0.62 h.
          padding: EdgeInsets.only(left: icon - h * 0.62),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: h,
                padding: EdgeInsets.only(left: h * 0.72, right: h * 0.4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h),
                  gradient: LinearGradient(
                    colors: [tier.pillStart, tier.pillEnd],
                  ),
                  border: Border.all(
                    color: gold
                        ? const Color(0xFFFFD24A)
                        : Colors.white.withValues(alpha: 0.55),
                    width: h * (gold ? 0.07 : 0.05),
                  ),
                ),
                child: Text(
                  '$level',
                  style: number.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: tier.pillStart,
                        offset: Offset(0, h * 0.05),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: -(icon - h * 0.62),
                top: -(icon - h) / 2,
                child: Image.asset(
                  tier.icon,
                  width: icon,
                  height: icon,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
