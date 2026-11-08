import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D305 (owner: «هذا شريط الهدايا والآخر شريط الألعاب، يظهر في جميع الغرف من
/// الجانب الى المنتصف ويخرج من الجهة الأخرى، ويبقى في المنتصف ثانيتين»): the
/// global strip of [LiveGlobalStrips] on the owner's artwork
/// (`assets/global_strips/`, PROVENANCE) — «أرسل … إلى … هدية …» with the
/// gift's picture, or «فاز … بجائزة قيمتها … تذكرة» with the ticket and the
/// game's picture — written in code inside the art's glass bar.
///
/// It slides in from the reading start (Arabic: from the right) to the
/// middle in [LiveGlobalStrips.enterTime], stays [LiveGlobalStrips.holdTime]
/// and leaves by the other side; with reduced motion it fades in and out
/// on the same timeline (still 2 s in full). Only the strip takes taps: a
/// strip from another live opens it ([onOpenRoom], D178); otherwise the
/// sender's / winner's card ([onPerson]); neither: not a button.
///
/// The art is the owner's as drawn (its medallion at the left) in both
/// directions; the words follow the app's direction.
///
/// D305b (owner: «اجعل حجم الشريط اصغر وشريط الألعاب يكون موقعه فوق شريط
/// الهدايا»): 75 % of the first size (≤ 270 pt wide), one bar per [lane]
/// ([LiveGlobalStripLanes] puts the games lane above the gifts lane).
class LiveGlobalStripBar extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.lane,
    super.key,
    this.onOpenRoom,
    this.onPerson,
  });

  final String roomId;
  final StripLane lane;
  final ValueChanged<String>? onOpenRoom;
  final ValueChanged<UserSummary>? onPerson;

  /// The strip shown in [lane].
  static Key laneKey(StripLane lane) => Key('global.strip.${lane.name}');

  static Key keyOf(GlobalStrip strip) => ValueKey('globalStrip.${strip.key}');

  /// The art's widest (its 1x file is this wide; D305b: 75 % of 360).
  static const double maxWidth = 270;

  /// The words' size at text scale 1 (names and amount included).
  static const double fontSize = 11;

  /// Height / width of the trimmed art (1966 × 571 px of the 2000 × 667
  /// originals, both strips on one box).
  static const double aspect = 571 / 1966;

  /// The glass bar's text area as fractions of the art (left, top, right,
  /// bottom), measured on the trimmed originals: the glass spans x 0.317 –
  /// 0.897 and y 0.39 – 0.80 of both; inset so the words keep clear of the
  /// medallion's swoosh, the rounded ends, the crown's and the bottom
  /// diamonds.
  static const Rect glass = Rect.fromLTRB(0.351, 0.413, 0.865, 0.781);

  static const giftArt = 'assets/global_strips/gift_strip.webp';
  static const gameArt = 'assets/global_strips/game_strip.webp';

  /// The names' longest before an ellipsis.
  static const int maxNameChars = 14;

  static const Color gold = Color(0xFFFFD66B);
  static const Color outline = Color(0xFF2A0820);

  /// The strip's width on a screen [screenWidth] wide.
  static double widthFor(double screenWidth) =>
      math.min(maxWidth, screenWidth - 2 * KSpacing.sm);

  /// The strip's height on a screen [screenWidth] wide (crown and wings
  /// included).
  static double heightFor(double screenWidth) => widthFor(screenWidth) * aspect;

  /// Where the strip is at [t] of [LiveGlobalStrips.showTime]: its sideways
  /// shift as a fraction of the way off-screen (−1 … 1; 0 = the middle) and
  /// its opacity. [rtl]: it comes from the right. [still]: reduced motion.
  static ({double shift, double opacity}) at(
    Duration t, {
    required bool rtl,
    required bool still,
  }) {
    final enter = LiveGlobalStrips.enterTime.inMicroseconds;
    final holdEnd = enter + LiveGlobalStrips.holdTime.inMicroseconds;
    final exit = LiveGlobalStrips.exitTime.inMicroseconds;
    final us = t.inMicroseconds;
    final from = rtl ? 1.0 : -1.0;
    if (us < enter) {
      final p = Curves.easeOutCubic.transform(us / enter);
      return still
          ? (shift: 0, opacity: p)
          : (shift: from * (1 - p), opacity: 1);
    }
    if (us <= holdEnd) return (shift: 0, opacity: 1);
    final p = Curves.easeInCubic.transform(math.min(1, (us - holdEnd) / exit));
    return still ? (shift: 0, opacity: 1 - p) : (shift: -from * p, opacity: 1);
  }

  /// [name] cut to [maxNameChars] (by characters, not code units) with "…".
  static String shortName(String name) {
    final chars = name.characters;
    return chars.length <= maxNameChars
        ? name
        : '${chars.take(maxNameChars - 1)}…';
  }

  @override
  ConsumerState<LiveGlobalStripBar> createState() => _LiveGlobalStripBarState();
}

class _LiveGlobalStripBarState extends ConsumerState<LiveGlobalStripBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: LiveGlobalStrips.showTime,
  );
  String? _playing;

  @override
  void initState() {
    super.initState();
    // A new strip starts its timeline (enter → 2 s → exit) from 0.
    ref.listenManual(liveGlobalStripsProvider(widget.roomId), (_, lanes) {
      final strip = LiveGlobalStrips.of(lanes, widget.lane);
      if (strip == null) {
        _playing = null;
      } else if (strip.key != _playing) {
        _playing = strip.key;
        _clock.forward(from: 0);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps this person's strip switches loaded while the live is open.
    ref.watch(globalStripPrefsProvider);
    final strip = LiveGlobalStrips.of(
      ref.watch(liveGlobalStripsProvider(widget.roomId)),
      widget.lane,
    );
    if (strip == null) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context).width;
    final width = LiveGlobalStripBar.widthFor(screen);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final still = MediaQuery.disableAnimationsOf(context);
    final text = _text(context, strip);
    final open = widget.onOpenRoom;
    final person = widget.onPerson;
    final room = strip.room;
    final tap = room != null && room.id != widget.roomId && open != null
        ? () {
            ref
                .read(liveGlobalStripsProvider(widget.roomId).notifier)
                .dismiss(widget.lane);
            open(room.id);
          }
        : person != null
        ? () => person(strip.person)
        : null;
    final body = _StripBody(strip: strip, width: width, text: text.spans);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final pos = LiveGlobalStripBar.at(
          _clock.duration! * _clock.value,
          rtl: rtl,
          still: still,
        );
        // Off-screen: half the screen and half the strip away.
        final away = screen / 2 + width / 2;
        return Opacity(
          opacity: pos.opacity,
          child: Transform.translate(
            offset: Offset(pos.shift * away, 0),
            child: child,
          ),
        );
      },
      child: Semantics(
        key: LiveGlobalStripBar.keyOf(strip),
        container: true,
        liveRegion: true,
        button: tap != null,
        label: text.plain,
        excludeSemantics: true,
        onTap: tap,
        child: KeyedSubtree(
          key: LiveGlobalStripBar.laneKey(widget.lane),
          child: tap == null
              ? body
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: tap,
                  child: body,
                ),
        ),
      ),
    );
  }

  /// The strip's words: the plain sentence (semantics) and its spans (the
  /// names and the amount in gold, the ticket after the amount).
  ({String plain, List<_Part> spans}) _text(
    BuildContext context,
    GlobalStrip strip,
  ) {
    final l10n = context.l10n;
    const s = '\u0001S\u0001';
    const r = '\u0001R\u0001';
    const g = '\u0001G\u0001';
    const a = '\u0001A\u0001';
    final String template;
    Map<String, (String, bool)> values;
    switch (strip) {
      case GiftStrip(:final ticker):
        final gift = ticker.gift;
        final name =
            ref
                .watch(giftCatalogueProvider)
                .value
                ?.byCode(gift.giftCode)
                ?.name ??
            gift.giftCode;
        final first = gift.recipients.isEmpty
            ? ticker.room.host
            : gift.recipients.first;
        final more = gift.recipients.length - 1;
        final receiver = KFormat.bidiIsolate(
          LiveGlobalStripBar.shortName(first.displayName),
        );
        template = l10n.liveStripGift(s, r, g);
        values = {
          'S': (
            KFormat.bidiIsolate(
              LiveGlobalStripBar.shortName(gift.sender.displayName),
            ),
            false,
          ),
          'R': (more > 0 ? '$receiver +$more' : receiver, false),
          'G': (
            KFormat.bidiIsolate(
              gift.quantity > 1
                  ? '${LiveGlobalStripBar.shortName(name)} ×${gift.quantity}'
                  : LiveGlobalStripBar.shortName(name),
            ),
            false,
          ),
        };
      case GameWinStrip(:final ticker):
        template = l10n.liveStripGameWin(s, a);
        values = {
          'S': (
            KFormat.bidiIsolate(
              LiveGlobalStripBar.shortName(ticker.winner.displayName),
            ),
            false,
          ),
          'A': (KFormat.bidiIsolate(KFormat.grouped(ticker.tickets)), true),
        };
    }
    final parts = <_Part>[];
    final plain = StringBuffer();
    final marker = RegExp('\u0001([A-Z])\u0001');
    var at = 0;
    for (final m in marker.allMatches(template)) {
      if (m.start > at) {
        final t = template.substring(at, m.start);
        parts.add(_Part(t, gold: false));
        plain.write(t);
      }
      final v = values[m.group(1)]!;
      parts.add(_Part(v.$1, gold: true, ticket: v.$2));
      plain.write(v.$1);
      at = m.end;
    }
    if (at < template.length) {
      final t = template.substring(at);
      parts.add(_Part(t, gold: false));
      plain.write(t);
    }
    return (plain: plain.toString(), spans: parts);
  }
}

class _Part {
  const new(this.text, {required this.gold, this.ticket = false});

  final String text;
  final bool gold;

  /// The ticket icon follows this part (the prize's amount).
  final bool ticket;
}

/// The art with the words and the picture in its glass bar.
class _StripBody extends StatelessWidget {
  const new({required this.strip, required this.width, required this.text});

  final GlobalStrip strip;
  final double width;
  final List<_Part> text;

  @override
  Widget build(BuildContext context) {
    final height = width * LiveGlobalStripBar.aspect;
    const g = LiveGlobalStripBar.glass;
    final glassHeight = height * (g.bottom - g.top);
    final thumb = glassHeight * 0.86;
    final picture = switch (strip) {
      GiftStrip(:final ticker) => KGiftImage(
        ticker.gift.assetKey,
        imageUrl: ticker.gift.imageUrl,
        size: thumb,
      ),
      GameWinStrip(:final ticker) =>
        ticker.game.imageUrl == null
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(thumb * 0.22),
                child: Image.network(
                  ticker.game.imageUrl!,
                  width: thumb,
                  height: thumb,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => SizedBox.square(dimension: thumb),
                ),
              ),
    };
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              strip is GiftStrip
                  ? LiveGlobalStripBar.giftArt
                  : LiveGlobalStripBar.gameArt,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC2A0820),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * g.left,
            top: height * g.top,
            width: width * (g.right - g.left),
            height: glassHeight,
            // The picture at the glass's right end in both directions (the
            // medallion keeps the left end); the words fill the rest.
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: Center(
                    child: _Words(parts: text, box: glassHeight),
                  ),
                ),
                if (picture != null) ...[
                  const SizedBox(width: KSpacing.xs),
                  picture,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White words with gold names, a dark outline, at most 2 lines.
class _Words extends StatelessWidget {
  const new({required this.parts, required this.box});

  final List<_Part> parts;
  final double box;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: 1.15);
    // D305b: 11 pt at text scale 1 (two lines fill the smaller glass, up
    // to the 1.15 cap).
    const size = LiveGlobalStripBar.fontSize;
    final base = context.textStyles.label.copyWith(
      fontSize: size,
      height: 1.12,
      fontWeight: FontWeight.w800,
    );
    const icon = size * 1.1;
    TextSpan spans({required bool stroke}) => TextSpan(
      children: [
        for (final p in parts) ...[
          TextSpan(
            text: p.text,
            style: stroke
                ? base.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.2
                      ..strokeJoin = StrokeJoin.round
                      ..color = LiveGlobalStripBar.outline,
                  )
                : base.copyWith(
                    color: p.gold
                        ? LiveGlobalStripBar.gold
                        : const Color(0xFFFFFFFF),
                  ),
          ),
          if (p.ticket)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 2),
                child: stroke
                    ? const SizedBox.square(dimension: icon)
                    : const KabsoArtIcon(KabsoArt.ticket, size: icon),
              ),
            ),
        ],
      ],
    );
    Text words({required bool stroke}) => Text.rich(
      spans(stroke: stroke),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      textScaler: scaler,
    );
    return Stack(
      alignment: Alignment.center,
      children: [words(stroke: true), words(stroke: false)],
    );
  }
}

/// D305b (owner: «شريط الألعاب يكون موقعه فوق شريط الهدايا»): the two
/// lanes, one under the other — the games lane on top, the gifts lane
/// [gap] under it. Each lane keeps its height while empty, so a strip never
/// moves to the other lane's place; empty, they take no taps.
class LiveGlobalStripLanes extends StatelessWidget {
  const new({required this.roomId, super.key, this.onOpenRoom, this.onPerson});

  final String roomId;
  final ValueChanged<String>? onOpenRoom;
  final ValueChanged<UserSummary>? onPerson;

  /// Between the games lane and the gifts lane.
  static const double gap = 4;

  /// The top of [lane] below the lanes' own top.
  static double offsetOf(StripLane lane, double screenWidth) => switch (lane) {
    StripLane.games => 0,
    StripLane.gifts => LiveGlobalStripBar.heightFor(screenWidth) + gap,
  };

  @override
  Widget build(BuildContext context) {
    final height = LiveGlobalStripBar.heightFor(
      MediaQuery.sizeOf(context).width,
    );
    Widget lane(StripLane lane) => SizedBox(
      height: height,
      child: Center(
        child: LiveGlobalStripBar(
          roomId: roomId,
          lane: lane,
          onOpenRoom: onOpenRoom,
          onPerson: onPerson,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        lane(StripLane.games),
        const SizedBox(height: gap),
        lane(StripLane.gifts),
      ],
    );
  }
}
