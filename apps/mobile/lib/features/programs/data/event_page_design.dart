// v1.115-social (D354, CONVENTIONS §10.150): `EventDetail.design` — the page
// design the team chose for a gift event in the panel. Null = today's page.
//
// Parsing is forgiving the way the contract asks: an unknown version or
// layout means «draw today's page» (null); an unknown value of any other
// choice falls back to that choice's default, so a newer server never breaks
// an older app.

import 'package:flutter/foundation.dart';

/// `EventPageLayout`.
enum EventPageLayout {
  heroPodium('HERO_PODIUM'),
  stage('STAGE'),
  deck('DECK');

  new(this.wire);

  final String wire;
}

/// `EventLeaderboardStyle`.
enum EventBoardStyle {
  throne('THRONE'),
  podium('PODIUM'),
  cardsRow('CARDS_ROW'),
  spotlight('SPOTLIGHT'),
  shieldCrest('SHIELD_CREST');

  new(this.wire);

  final String wire;
}

/// `EventCountdownStyle`: [classic] is today's small pill.
enum EventCountdownKind {
  classic('CLASSIC'),
  flip('FLIP'),
  ring('RING'),
  coins('COINS'),
  neon('NEON'),
  ribbon('RIBBON');

  new(this.wire);

  final String wire;
}

/// `EventCardPreset`: [classic] is today's cards.
enum EventCardPreset {
  classic('CLASSIC'),
  luxuryGold('LUXURY_GOLD'),
  glass('GLASS'),
  darkMinimal('DARK_MINIMAL'),
  neon('NEON'),
  kabsoRed('KABSO_RED');

  new(this.wire);

  final String wire;
}

/// `EventRulesButton.style`.
enum EventRulesStyle {
  edgeRibbon('EDGE_RIBBON'),
  roundIcon('ROUND_ICON'),
  goldPill('GOLD_PILL'),
  glassChip('GLASS_CHIP'),
  sideTab('SIDE_TAB'),
  appBarLink('APP_BAR_LINK');

  new(this.wire);

  final String wire;
}

/// `EventPageSection.id`.
enum EventPageSectionId {
  gifts('GIFTS'),
  rules('RULES'),
  boards('BOARDS'),
  rewards('REWARDS'),
  milestones('MILESTONES');

  new(this.wire);

  final String wire;
}

/// `EventPageMotion.entrance`.
enum EventEntrance {
  fade('FADE'),
  slide('SLIDE'),
  scale('SCALE'),
  none('NONE');

  new(this.wire);

  final String wire;
}

T? _byWire<T extends Enum>(List<T> values, Object? wire, String Function(T) w) {
  for (final v in values) {
    if (w(v) == wire) return v;
  }
  return null;
}

/// `EventRulesButton`.
@immutable
final class EventRulesButtonSpec {
  const new({required this.style, this.atStart = false});

  final EventRulesStyle style;

  /// `edge: START` (right in Arabic); END otherwise.
  final bool atStart;
}

/// `EventPageMotion`.
@immutable
final class EventDesignMotion {
  const new({
    this.entrance = EventEntrance.fade,
    this.durationMs = 450,
    this.shimmer = true,
    this.pulseFirst = true,
    this.overlaySpeed = 1,
    this.overlayOpacity = 1,
  });

  factory fromJson(Object? json) {
    if (json is! Map) return const EventDesignMotion();
    double num01(Object? v, double min, double max, double d) =>
        v is num ? v.toDouble().clamp(min, max) : d;
    return EventDesignMotion(
      entrance:
          _byWire(EventEntrance.values, json['entrance'], (e) => e.wire) ??
          EventEntrance.fade,
      durationMs: json['durationMs'] is int
          ? (json['durationMs'] as int).clamp(0, 1500)
          : 450,
      shimmer: json['shimmer'] as bool? ?? true,
      pulseFirst: json['pulseFirst'] as bool? ?? true,
      overlaySpeed: num01(json['overlaySpeed'], 0.25, 2, 1),
      overlayOpacity: num01(json['overlayOpacity'], 0, 1, 1),
    );
  }

  final EventEntrance entrance;
  final int durationMs;
  final bool shimmer;
  final bool pulseFirst;
  final double overlaySpeed;
  final double overlayOpacity;
}

/// `EventRewardTier`: a rank range of one board; its prizes are the board's
/// prize line covering it (never copied into the design).
@immutable
final class EventRewardTierSpec {
  const new({
    required this.board,
    required this.from,
    required this.to,
    this.labelAr,
    this.labelEn,
    this.featured = const [],
  });

  /// The board's wire kind (`SENDERS` …).
  final String board;
  final int from;
  final int to;
  final String? labelAr;
  final String? labelEn;

  /// Indexes into the items of the covering prize line.
  final List<int> featured;

  String? label(String languageCode) =>
      languageCode == 'ar' ? labelAr ?? labelEn : labelEn ?? labelAr;
}

/// `EventPageDesign` (version 1).
@immutable
final class EventPageDesign {
  const new({
    required this.layout,
    this.leaderboard = EventBoardStyle.throne,
    this.countdown = EventCountdownKind.classic,
    this.preset = EventCardPreset.classic,
    this.rulesButton,
    this.sections = defaultSections,
    this.leaderboardBackgroundUrl,
    this.tiers,
    this.motion = const EventDesignMotion(),
  });

  static const version = 1;

  static const List<({EventPageSectionId id, bool visible})> defaultSections = [
    (id: EventPageSectionId.gifts, visible: true),
    (id: EventPageSectionId.rules, visible: true),
    (id: EventPageSectionId.boards, visible: true),
    (id: EventPageSectionId.rewards, visible: true),
    (id: EventPageSectionId.milestones, visible: true),
  ];

  /// Null for none, another version, an unknown layout or a malformed value:
  /// the app then draws today's page.
  static EventPageDesign? fromJson(Object? json) {
    if (json is! Map) return null;
    if (json['v'] != version) return null;
    final layout = _byWire(
      EventPageLayout.values,
      json['layout'],
      (l) => l.wire,
    );
    if (layout == null) return null;
    final rules = json['rulesButton'];
    final rulesStyle = rules is Map
        ? _byWire(EventRulesStyle.values, rules['style'], (s) => s.wire)
        : null;
    final rewards = json['rewards'];
    final tiers = rewards is Map && rewards['tiers'] is List
        ? [
            for (final t in rewards['tiers'] as List)
              if (t is Map &&
                  t['board'] is String &&
                  t['from'] is int &&
                  t['to'] is int)
                EventRewardTierSpec(
                  board: t['board'] as String,
                  from: t['from'] as int,
                  to: t['to'] as int,
                  labelAr: t['labelAr'] as String?,
                  labelEn: t['labelEn'] as String?,
                  featured: [
                    for (final f in (t['featured'] as List?) ?? const [])
                      if (f is int) f,
                  ],
                ),
          ]
        : null;
    return EventPageDesign(
      layout: layout,
      leaderboard:
          _byWire(EventBoardStyle.values, json['leaderboard'], (s) => s.wire) ??
          EventBoardStyle.throne,
      countdown:
          _byWire(
            EventCountdownKind.values,
            json['countdown'],
            (c) => c.wire,
          ) ??
          EventCountdownKind.classic,
      preset:
          _byWire(EventCardPreset.values, json['preset'], (p) => p.wire) ??
          EventCardPreset.classic,
      rulesButton: rulesStyle == null
          ? null
          : EventRulesButtonSpec(
              style: rulesStyle,
              atStart: (rules as Map)['edge'] == 'START',
            ),
      sections: _sections(json['sections']),
      leaderboardBackgroundUrl: json['leaderboardBackgroundUrl'] as String?,
      tiers: tiers == null || tiers.isEmpty ? null : tiers,
      motion: EventDesignMotion.fromJson(json['motion']),
    );
  }

  /// The sections in order, each once; a known one missing is added at the
  /// end (visible), unknown ones are dropped.
  static List<({EventPageSectionId id, bool visible})> _sections(Object? v) {
    if (v is! List) return defaultSections;
    final out = <({EventPageSectionId id, bool visible})>[];
    for (final s in v) {
      if (s is! Map) continue;
      final id = _byWire(EventPageSectionId.values, s['id'], (i) => i.wire);
      if (id == null || out.any((o) => o.id == id)) continue;
      out.add((id: id, visible: s['visible'] as bool? ?? true));
    }
    for (final d in defaultSections) {
      if (!out.any((o) => o.id == d.id)) out.add(d);
    }
    return out;
  }

  final EventPageLayout layout;
  final EventBoardStyle leaderboard;
  final EventCountdownKind countdown;
  final EventCardPreset preset;

  /// Null: no rules button (the rules section shows the rules).
  final EventRulesButtonSpec? rulesButton;
  final List<({EventPageSectionId id, bool visible})> sections;
  final String? leaderboardBackgroundUrl;

  /// Null: one tier per prize line of each board.
  final List<EventRewardTierSpec>? tiers;
  final EventDesignMotion motion;

  bool isVisible(EventPageSectionId id) =>
      sections.firstWhere((s) => s.id == id).visible;

  /// The visible sections in order.
  List<EventPageSectionId> get visibleSections => [
    for (final s in sections)
      if (s.visible) s.id,
  ];
}
