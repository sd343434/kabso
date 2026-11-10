// D362 (owner: «ايقونة تكون ببطاقة البث من الخارج حسب نوع البث بخط صغير
// جداً لكي لا تأخذ مساحة»): every hub card shows its room type as the
// owner's small animated glyph and a tiny English tag. The mapping from
// the room's real state, the still frame with reduce motion, animation only
// for cards on screen, no overflow at 360×800 ×1.3, the corner in RTL and
// LTR, and the card's height unchanged. ar and en.
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_live_icon.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/component_harness.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

LiveRoomSummary _summary(String mode, {bool inPk = false}) =>
    LiveRoomSummary.fromJson({
      'id': 'r-$mode',
      'title': 'room',
      'topic': null,
      'mode': mode,
      'host': {
        'id': 'h1',
        'username': 'host0001',
        'displayName': 'Host',
        'avatarUrl': null,
      },
      'category': null,
      'viewerCount': 3,
      'startedAt': '2026-11-02T12:00:00.000Z',
      'score': 0,
      'coverUrl': null,
      'inPk': inPk,
    });

/// One room of every kind the data carries, in [LiveCardKind] order.
const _rooms = [
  LiveRoomCardData(hostName: 'A', title: 'pk', viewerCount: 3, inPk: true),
  LiveRoomCardData(
    hostName: 'B',
    title: 'streamer',
    viewerCount: 3,
    isStreamer: true,
  ),
  LiveRoomCardData(
    hostName: 'C',
    title: 'podcast',
    viewerCount: 3,
    isAudio: true,
    isPodcast: true,
  ),
  LiveRoomCardData(
    hostName: 'D',
    title: 'audio',
    viewerCount: 3,
    isAudio: true,
  ),
  LiveRoomCardData(
    hostName: 'E',
    title: 'multi',
    viewerCount: 3,
    isMulti: true,
  ),
  LiveRoomCardData(hostName: 'F', title: 'live', viewerCount: 1234567),
];

Widget _grid(List<LiveRoomCardData> rooms, {double? cacheExtent}) =>
    CustomScrollView(
      scrollCacheExtent: cacheExtent == null
          ? null
          : ScrollCacheExtent.pixels(cacheExtent),
      slivers: [LiveHubGrid.sliver(rooms: rooms, onOpenRoom: (_) {})],
    );

void main() {
  group('the mapping from the room data', () {
    test("every wire mode and inPk map to one kind and the owner's glyph", () {
      final cases = {
        _summary('SOLO'): (LiveCardKind.live, KabsoLiveType.cam),
        _summary('SOLO', inPk: true): (LiveCardKind.pk, KabsoLiveType.pkBolt),
        _summary('PK'): (LiveCardKind.pk, KabsoLiveType.pkBolt),
        _summary('MULTI'): (LiveCardKind.multi, KabsoLiveType.cam),
        _summary('AUDIO'): (LiveCardKind.audio, KabsoLiveType.voice),
        _summary('PODCAST'): (LiveCardKind.podcast, KabsoLiveType.podcastVoice),
        _summary('STREAMER'): (LiveCardKind.streamer, KabsoLiveType.streamer),
        // An unknown mode from a newer server reads as SOLO.
        _summary('FUTURE'): (LiveCardKind.live, KabsoLiveType.cam),
      };
      for (final MapEntry(key: summary, value: (kind, glyph))
          in cases.entries) {
        final room = LiveRoomCardData.fromSummary(summary);
        expect(LiveCardKind.of(room), kind, reason: summary.mode.name);
        expect(kind.glyph, glyph);
      }
      // The party list shows «PK» in its own pill: its mark keeps the kind.
      final audioPk = LiveRoomCardData.fromSummary(
        _summary('AUDIO', inPk: true),
      );
      expect(LiveCardKind.of(audioPk), LiveCardKind.pk);
      expect(LiveCardKind.of(audioPk, withPk: false), LiveCardKind.audio);
      for (final party in PartyKind.values) {
        expect(party.cardKind.name, party.name);
      }
      // Glyphs no room state backs (no team PK, PK penalty or video
      // podcast on the wire) are never drawn on a card.
      expect(
        {for (final k in LiveCardKind.values) k.glyph},
        isNot(
          anyOf(
            contains(KabsoLiveType.pk),
            contains(KabsoLiveType.pkGroup),
            contains(KabsoLiveType.pkJudge),
            contains(KabsoLiveType.podcastCam),
          ),
        ),
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('each card draws its glyph and tag; screen readers hear '
          'the full type (${language.name})', (tester) async {
        final l10n = l10nFor(language);
        setViewport(tester, GoldenViewport.phone);
        await pumpComponent(tester, _grid(_rooms), language: language);
        for (final (i, kind) in LiveCardKind.values.indexed) {
          final card = find.byKey(LiveHubGrid.cardKey(i));
          final tag = find.descendant(
            of: card,
            matching: find.byKey(KLiveGridCard.typeKey),
          );
          expect(tester.widget<LiveTypeTag>(tag).kind, kind);
          expect(
            tester
                .widget<KabsoLiveIcon>(
                  find.descendant(
                    of: tag,
                    matching: find.byType(KabsoLiveIcon),
                  ),
                )
                .type,
            kind.glyph,
          );
          final text = tester
              .widget<Text>(
                find.descendant(
                  of: tag,
                  matching: find.byKey(LiveTypeTag.textKey),
                ),
              )
              .data;
          expect(text, kind.tag(l10n));
          // The owner's English tags, the same in both languages.
          expect(text, kind.tag(l10nFor(AppLanguage.en)));
          expect(
            tester.getSemantics(card).label,
            contains(kind.semanticLabel(l10n)),
          );
        }
        expect(LiveCardKind.audio.semanticLabel(l10n), l10n.liveCategoryAudio);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('motion', () {
    setUp(() => KabsoLiveIcon.animationsEnabled = true);
    tearDown(() => KabsoLiveIcon.animationsEnabled = false);

    Future<void> pumpIcon(
      WidgetTester tester, {
      bool reduceMotion = false,
      bool animate = true,
      bool tickers = true,
    }) async {
      await pumpComponent(
        tester,
        TickerMode(
          enabled: tickers,
          child: Center(
            child: KabsoLiveIcon(type: KabsoLiveType.voice, animate: animate),
          ),
        ),
        disableAnimations: reduceMotion,
      );
    }

    testWidgets('it loops on screen; reduce motion, animate: false and a '
        'muted TickerMode draw one still frame', (tester) async {
      // Incidental transitions of the harness end within a second; only a
      // looping glyph still has a ticker after that.
      Future<int> tickers() async {
        await tester.pump(const Duration(seconds: 1));
        return tester.binding.transientCallbackCount;
      }

      await pumpIcon(tester);
      expect(await tickers(), 1);
      await pumpIcon(tester, reduceMotion: true);
      expect(await tickers(), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await pumpIcon(tester);
      expect(await tickers(), 1);
      await pumpIcon(tester, animate: false);
      expect(await tickers(), 0);
      await pumpIcon(tester, tickers: false);
      expect(await tickers(), 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a long grid animates only the cards on screen, and the '
        'ones scrolled into view take over', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final rooms = [for (var i = 0; i < 40; i++) _rooms[i % _rooms.length]];
      // A wide cache, so cards are built well off screen.
      await pumpComponent(
        tester,
        _grid(rooms, cacheExtent: 1000),
        disableAnimations: false,
      );
      await tester.pump();
      await tester.pump();

      // The tags (not just their cards) at least partly on screen.
      int visibleCards() {
        final screen = Offset.zero & tester.view.physicalSize / 3;
        var n = 0;
        for (var i = 0; i < rooms.length; i++) {
          final tag = find.descendant(
            of: find.byKey(LiveHubGrid.cardKey(i)),
            matching: find.byKey(KLiveGridCard.typeKey),
          );
          if (tag.evaluate().isEmpty) continue;
          final r = tester.getRect(tag).intersect(screen);
          if (r.width > 0 && r.height > 0) n++;
        }
        return n;
      }

      final built = find
          .byType(KabsoLiveIcon, skipOffstage: false)
          .evaluate()
          .length;
      final visible = visibleCards();
      expect(visible, greaterThan(0));
      // Cards built off screen (the grid's cache) stay still.
      expect(built, greaterThan(visible));
      expect(tester.binding.transientCallbackCount, visible);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(LiveHubGrid.cardKey(0)), findsNothing);
      expect(tester.binding.transientCallbackCount, visibleCards());
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final language in AppLanguage.values) {
    final rtl = language == AppLanguage.ar;
    testWidgets('360×800 at text ×1.3 (real fonts): no overflow; the tag in '
        'the top start corner, clear of the count, the card no taller '
        '(${language.name})', (tester) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.android);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpComponent(tester, _grid(_rooms), language: language);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < _rooms.length; i++) {
        final cardFinder = find.byKey(LiveHubGrid.cardKey(i));
        final card = tester.getRect(cardFinder);
        // The grid's fixed aspect: the tag never grows the card.
        expect(card.width / card.height, closeTo(KLiveGrid.cardAspect, 0.01));
        final tag = tester.getRect(
          find.descendant(
            of: cardFinder,
            matching: find.byKey(KLiveGridCard.typeKey),
          ),
        );
        final count = tester.getRect(
          find.descendant(
            of: cardFinder,
            matching: find.byKey(KLiveGridCard.viewersKey),
          ),
        );
        final glyph = tester.getRect(
          find.descendant(of: cardFinder, matching: find.byType(KabsoLiveIcon)),
        );
        final text = tester.getRect(
          find.descendant(
            of: cardFinder,
            matching: find.byKey(LiveTypeTag.textKey),
          ),
        );
        expect(tag.height, lessThanOrEqualTo(LiveTypeTag.maxHeight));
        expect(glyph.height, lessThanOrEqualTo(13));
        expect(tag.top - card.top, lessThan(14));
        expect(
          card.contains(tag.topLeft) && card.contains(tag.bottomRight),
          isTrue,
        );
        expect(tag.overlaps(count), isFalse, reason: 'card $i');
        if (rtl) {
          // The start is the right: the tag right of centre, the count at
          // the left, the glyph before (right of) its tag.
          expect(tag.center.dx, greaterThan(card.center.dx));
          expect(count.right, lessThan(tag.left));
          expect(glyph.left, greaterThanOrEqualTo(text.right - 0.5));
        } else {
          expect(tag.center.dx, lessThan(card.center.dx));
          expect(count.left, greaterThan(tag.right));
          expect(glyph.right, lessThanOrEqualTo(text.left + 0.5));
        }
      }
    });
  }
}
