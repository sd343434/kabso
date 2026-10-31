// Kabso Live — PK power activation: data + per-tier visual configuration.
//
// The banner never owns business logic. Map your existing PK state (team ids,
// multiplier, expiry)
// to [PkPowerActivation] and pass it in. Countdown is derived from [endsAt], so
// rebuilds never restart it.
//
// Every tier = artwork + geometry + colours + [PkPowerFx]. Shared
// widgets/painters read only this config,
// so adding a tier never duplicates animation code.

import 'package:clock/clock.dart';
import 'package:material_ui/material_ui.dart';

/// Which half of the PK screen the activating team owns.
enum PkPowerSide { left, right }

/// Power tiers, weakest → strongest. Each tier must look stronger than the one
/// before it.
enum PkPowerTier { doublePower, doubleTurbo, triple, tripleTurbo }

/// Landmarks inside one banner artwork (fractions of width / height).
@immutable
class PkBannerGeometry {
  const new({
    required this.aspect,
    required this.mascot,
    required this.mascotR,
    required this.textLeft,
    required this.textRight,
    required this.bar,
  });

  final double aspect; // height / width of the artwork
  final Offset mascot; // centre of the mascot
  final double mascotR; // radius as a fraction of width
  final Rect textLeft; // left panel text area
  final Rect textRight; // right panel text area
  final Rect bar; // outer bar outline (border light path)

  Rect scale(Rect f, Size s) => Rect.fromLTRB(
    f.left * s.width,
    f.top * s.height,
    f.right * s.width,
    f.bottom * s.height,
  );
  Offset at(Offset f, Size s) => Offset(f.dx * s.width, f.dy * s.height);
}

/// Motion / intensity knobs. Higher tiers raise these; painters never branch on
/// the tier itself.
@immutable
class PkPowerFx {
  const new({
    required this.entranceMs,
    required this.startScale,
    required this.slideIn,
    required this.shake,
    required this.impactStart,
    required this.impactEnd,
    required this.flash,
    required this.ringWidth,
    required this.streaks,
    required this.speedLines,
    required this.crystals,
    required this.aura,
    required this.trails,
    required this.trailPeriodMs,
    required this.trailAlpha,
    required this.trailWidth,
    required this.borderPulse,
    required this.pulsePeriodMs,
    required this.particles,
    required this.spawnEveryMs,
    required this.burstShare,
    required this.embersRise,
    required this.edgeSparkEveryMs,
    required this.sweepPeriodMs,
    required this.sweepMs,
    required this.sweepAlpha,
    required this.exitMs,
    required this.exitSweep,
    required this.particleSize,
    required this.spread,
    required this.ambientGlow,
    required this.flames,
    this.lightning = 0,
    this.idleArcEveryMs = 0,
    this.rings = 0,
    this.impactRings = 1,
    this.edgePulse = 0,
    this.electric = false,
    this.rainbow = false,
    this.hueSpeed = 0,
    this.finalShockwave = false,
    this.impactAlpha = 1,
  });

  final double entranceMs;
  final double startScale;
  // horizontal entrance distance, fraction of banner width (from the team's
  // side)
  final double slideIn;
  final double
  shake; // impact shake amplitude, fraction of banner height (banner only)
  final double impactStart;
  final double impactEnd;
  final double flash;
  final double ringWidth;
  final int streaks; // short streaks from the ring
  final int speedLines; // fast directional lines during impact
  final int crystals; // crystal fragments scattering on entrance
  final double aura; // mascot energy aura strength during impact
  final int trails; // energy/flame trails behind the bar
  final double trailPeriodMs;
  final double trailAlpha;
  final double trailWidth;
  final double borderPulse;
  final double pulsePeriodMs;
  final int particles; // bounded pool size
  final double spawnEveryMs;
  final double burstShare;
  final bool embersRise; // embers drift upward and fade
  final double edgeSparkEveryMs; // 0 = none
  final double sweepPeriodMs;
  final double sweepMs;
  final double sweepAlpha;
  final double exitMs;
  final bool exitSweep; // horizontal energy sweep on exit
  final double particleSize; // particle unit, fraction of banner height
  // how far particles float outside the banner (fraction of height, above &
  // below)
  final double spread;
  final double ambientGlow; // always-on soft glow behind the banner
  final int
  flames; // flickering flame tongues licking out from behind the bar (0 = none)
  // lightning arcs fired from the mascot during the impact (0 = none)
  final int lightning;
  // random lightning arcs while active (0 = none); arcs also run along the bar
  // edges
  final double idleArcEveryMs;
  final int rings; // rotating energy rings around the mascot while active
  final int impactRings; // expanding rings during the impact
  // strength of the brief screen-edge pulse on the activating team's side (0 =
  // none)
  final double edgePulse;
  final bool
  electric; // particles become sparks / lightning branches / rotating crystals
  // full-spectrum colouring that moves over time (border, trails, flames,
  // lightning, particles)
  final bool rainbow;
  final double hueSpeed; // degrees per ms the spectrum travels
  final bool finalShockwave; // multicolour shockwave on expiry
  // scales additive impact layers so many overlapping colours don't burn to
  // white
  final double impactAlpha;

  static const doublePower = PkPowerFx(
    entranceMs: 450,
    startScale: .82,
    slideIn: 0,
    shake: 0,
    impactStart: 200,
    impactEnd: 650,
    flash: .9,
    ringWidth: .05,
    streaks: 12,
    speedLines: 0,
    crystals: 0,
    aura: 0,
    trails: 5,
    trailPeriodMs: 2400,
    trailAlpha: .65,
    trailWidth: .03,
    borderPulse: .35,
    pulsePeriodMs: 650,
    particles: 40,
    spawnEveryMs: 90,
    burstShare: .5,
    embersRise: false,
    edgeSparkEveryMs: 0,
    sweepPeriodMs: 3000,
    sweepMs: 900,
    sweepAlpha: .8,
    exitMs: 420,
    exitSweep: false,
    particleSize: .03,
    spread: .35,
    ambientGlow: .35,
    flames: 0,
  );

  static const doubleTurbo = PkPowerFx(
    entranceMs: 500,
    startScale: .78,
    slideIn: .35,
    shake: .035,
    impactStart: 150,
    impactEnd: 700,
    flash: 1,
    ringWidth: .08,
    streaks: 18,
    speedLines: 16,
    crystals: 12,
    aura: 1,
    trails: 8,
    trailPeriodMs: 1200,
    trailAlpha: .95,
    trailWidth: .045,
    borderPulse: .6,
    pulsePeriodMs: 380,
    particles: 90,
    spawnEveryMs: 35,
    burstShare: .45,
    embersRise: true,
    edgeSparkEveryMs: 450,
    sweepPeriodMs: 2100,
    sweepMs: 650,
    sweepAlpha: 1,
    exitMs: 380,
    exitSweep: true,
    particleSize: .04,
    spread: .55,
    ambientGlow: .6,
    flames: 10,
  );

  static const triple = PkPowerFx(
    entranceMs: 500,
    startScale: .75,
    slideIn: .2,
    shake: .045,
    impactStart: 150,
    impactEnd: 800,
    flash: 1,
    ringWidth: .07,
    streaks: 14,
    speedLines: 8,
    crystals: 14,
    aura: 1,
    trails: 6,
    trailPeriodMs: 1500,
    trailAlpha: .85,
    trailWidth: .05,
    borderPulse: .75,
    pulsePeriodMs: 300,
    particles: 120,
    spawnEveryMs: 28,
    burstShare: .4,
    embersRise: false,
    edgeSparkEveryMs: 380,
    sweepPeriodMs: 1600,
    sweepMs: 550,
    sweepAlpha: 1,
    exitMs: 450,
    exitSweep: true,
    particleSize: .04,
    spread: .6,
    ambientGlow: .7,
    flames: 0,
    lightning: 7,
    idleArcEveryMs: 520,
    rings: 2,
    impactRings: 3,
    edgePulse: 1,
    electric: true,
  );

  static const tripleTurbo = PkPowerFx(
    entranceMs: 800,
    startScale: .7,
    slideIn: .12,
    shake: .06,
    // flash capped so it never washes out face/text
    impactStart: 120,
    impactEnd: 900,
    flash: .45,
    ringWidth: .09,
    streaks: 20,
    speedLines: 18,
    crystals: 18,
    aura: 1,
    trails: 10,
    trailPeriodMs: 1100,
    trailAlpha: 1,
    trailWidth: .055,
    borderPulse: .9,
    pulsePeriodMs: 260,
    particles: 170,
    spawnEveryMs: 18,
    // small centre burst: keeps the face readable; density comes from the idle
    // pool
    burstShare: .18,
    embersRise: true,
    edgeSparkEveryMs: 300,
    sweepPeriodMs: 1250,
    sweepMs: 480,
    sweepAlpha: 1,
    exitMs: 560,
    exitSweep: true,
    particleSize: .042,
    spread: .65,
    ambientGlow: .8,
    flames: 12,
    lightning: 10,
    idleArcEveryMs: 380,
    rings: 3,
    impactRings: 4,
    edgePulse: 1,
    electric: true,
    rainbow: true,
    hueSpeed: .12,
    finalShockwave: true,
    impactAlpha: .5,
  );
}

@immutable
class PkPowerTheme {
  const new({
    required this.asset,
    required this.label,
    required this.geometry,
    required this.fx,
    required this.gold,
    required this.amber,
    required this.orange,
    required this.highlight,
    required this.ember,
    required this.crystal,
  });

  final String asset;
  final String label;
  final PkBannerGeometry geometry;
  final PkPowerFx fx;
  final Color gold;
  final Color amber;
  final Color orange;
  final Color highlight;
  final Color ember;
  final Color crystal;

  static const doublePower = PkPowerTheme(
    asset: 'assets/pk/pk_power_double.png',
    label: 'DOUBLE',
    geometry: PkBannerGeometry(
      aspect: 371 / 1440,
      mascot: Offset(.501, .47),
      mascotR: .062,
      textLeft: Rect.fromLTRB(.205, .371, .343, .652),
      textRight: Rect.fromLTRB(.655, .371, .793, .652),
      bar: Rect.fromLTRB(.11, .30, .89, .76),
    ),
    fx: PkPowerFx.doublePower,
    gold: Color(0xFFFFC83A),
    amber: Color(0xFFFFA81E),
    orange: Color(0xFFFF7A12),
    highlight: Color(0xFFFFF6D6),
    ember: Color(0xFFFFB02E),
    crystal: Color(0xFFFFC83A),
  );

  static const doubleTurbo = PkPowerTheme(
    asset: 'assets/pk/pk_power_double_turbo.png',
    label: 'TURBO',
    geometry: PkBannerGeometry(
      aspect: 427 / 1440,
      mascot: Offset(.496, .453),
      mascotR: .06,
      textLeft: Rect.fromLTRB(.209, .39, .347, .633),
      textRight: Rect.fromLTRB(.628, .39, .778, .633),
      bar: Rect.fromLTRB(.10, .34, .90, .70),
    ),
    fx: PkPowerFx.doubleTurbo,
    gold: Color(0xFFFFB21E),
    amber: Color(0xFFFF7A1A),
    orange: Color(0xFFFF3D12),
    highlight: Color(0xFFFFE9B8),
    ember: Color(0xFFFF4A14),
    crystal: Color(0xFFE8102A),
  );

  static const triple = PkPowerTheme(
    asset: 'assets/pk/pk_power_triple.png',
    label: 'TRIPLE',
    geometry: PkBannerGeometry(
      aspect: 468 / 1440,
      mascot: Offset(.4986, .388),
      mascotR: .069,
      textLeft: Rect.fromLTRB(.214, .375, .345, .58),
      textRight: Rect.fromLTRB(.650, .375, .785, .58),
      bar: Rect.fromLTRB(.09, .31, .91, .62),
    ),
    fx: PkPowerFx.triple,
    gold: Color(
      0xFFE66BFF,
    ), // magenta highlight (the "primary" accent of this tier)
    amber: Color(0xFF9B4DFF), // violet
    orange: Color(0xFF4B6BFF), // electric blue
    highlight: Color(0xFFF6EEFF), // blue-white
    ember: Color(0xFFFF4FD8), // magenta
    crystal: Color(0xFFB57BFF),
  );

  static const tripleTurbo = PkPowerTheme(
    asset: 'assets/pk/pk_power_triple_turbo.webp',
    label: 'TRIPLE TURBO',
    geometry: PkBannerGeometry(
      aspect: 478 / 1440,
      mascot: Offset(.4986, .40),
      mascotR: .07,
      textLeft: Rect.fromLTRB(.236, .41, .352, .58),
      textRight: Rect.fromLTRB(.656, .41, .772, .58),
      bar: Rect.fromLTRB(.10, .33, .90, .64),
    ),
    fx: PkPowerFx.tripleTurbo,
    // base colours; with fx.rainbow most effects take their hue from the moving
    // spectrum instead
    gold: Color(0xFFFFD84A),
    amber: Color(0xFFFF4FD8),
    orange: Color(0xFF2EE6FF),
    highlight: Color(0xFFFFFFFF),
    ember: Color(0xFFFF5A1F),
    crystal: Color(0xFF9B7BFF),
  );

  static PkPowerTheme of(PkPowerTier t) => switch (t) {
    PkPowerTier.doublePower => doublePower,
    PkPowerTier.doubleTurbo => doubleTurbo,
    PkPowerTier.triple => triple,
    PkPowerTier.tripleTurbo => tripleTurbo,
  };
}

/// One active power for one team. Build it from your existing source of truth.
@immutable
class PkPowerActivation {
  const new({
    required this.id,
    required this.teamId,
    required this.side,
    required this.endsAt,
    required this.multiplier,
    this.tier = PkPowerTier.doublePower,
    this.label,
  });

  /// Kabso (D199): the booster's name in the app's language («تربل»); null
  /// shows the theme's English label.
  final String? label;

  /// Unique per activation (e.g. server event id). A new id = a new entrance
  /// animation;
  /// the same id across rebuilds keeps the running animation and countdown.
  final String id;

  /// Your existing team identifier — kept so the banner can never be attached
  /// to the wrong team.
  final Object teamId;
  final PkPowerSide side;
  final PkPowerTier tier;

  /// Read from your PK state — the banner only displays it.
  final int multiplier;

  /// Server time when the power expires (converted to the local clock before
  /// passing it in).
  final DateTime endsAt;

  Duration remaining([DateTime? now]) {
    final r = endsAt.difference(now ?? clock.now());
    return r.isNegative ? Duration.zero : r;
  }

  bool get isExpired => remaining() == Duration.zero;

  @override
  bool operator ==(Object other) =>
      other is PkPowerActivation &&
      other.id == id &&
      other.teamId == teamId &&
      other.side == side &&
      other.tier == tier &&
      other.multiplier == multiplier &&
      other.endsAt == endsAt &&
      other.label == label;

  @override
  int get hashCode =>
      Object.hash(id, teamId, side, tier, multiplier, endsAt, label);
}

/// `Color.withOpacity` is deprecated: the owner's opacities as alpha.
extension PkPowerAlpha on Color {
  Color pkAlpha(double opacity) => withValues(alpha: opacity.clamp(0.0, 1.0));
}
