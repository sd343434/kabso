// D362 (owner: «ايقونة تكون ببطاقة البث من الخارج حسب نوع البث بخط صغير
// جداً لكي لا تأخذ مساحة», then 2026-11-10: «لا ازل الايقونات فقط جنبي موجة
// الكلمة بتصنيف لايف»): every hub card shows its room type as a tiny English
// tag right beside the teal live wave, with no glyph. The mapping from the
// room's real state, no overflow at 360×800 ×1.3, the placement in RTL and
// LTR, and the card's aspect unchanged. ar and en.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
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
  LiveRoomCardData(hostName: 'F', title: 'live', viewerCount: 1234567),
];

Widget _grid(List<LiveRoomCardData> rooms) => CustomScrollView(
  slivers: [LiveHubGrid.sliver(rooms: rooms, onOpenRoom: (_) {})],
);

void main() {
  group('the mapping from the room data', () {
    test('every wire mode and inPk map to one kind and its tag', () {
      final en = l10nFor(AppLanguage.en);
      final cases = {
        _summary('SOLO'): (LiveCardKind.live, en.liveTypeTagCam),
        _summary('SOLO', inPk: true): (LiveCardKind.pk, en.pkBadge),
        _summary('PK'): (LiveCardKind.pk, en.pkBadge),
        // D369: the multi-guest live is retired; a legacy MULTI room is a
        // camera live on its card.
        _summary('MULTI'): (LiveCardKind.live, en.liveTypeTagCam),
        _summary('AUDIO'): (LiveCardKind.audio, en.liveTypeTagVoice),
        _summary('PODCAST'): (LiveCardKind.podcast, en.liveTypeTagPodcast),
        _summary('STREAMER'): (LiveCardKind.streamer, en.liveTypeTagStreamer),
        // An unknown mode from a newer server reads as SOLO.
        _summary('FUTURE'): (LiveCardKind.live, en.liveTypeTagCam),
      };
      for (final MapEntry(key: summary, value: (kind, tag)) in cases.entries) {
        final room = LiveRoomCardData.fromSummary(summary);
        expect(LiveCardKind.of(room), kind, reason: summary.mode.name);
        expect(kind.tag(en), tag);
      }
      // The words the owner listed (D369: «Multi» is gone with the mode).
      expect(
        [for (final k in LiveCardKind.values) k.tag(en)],
        ['PK', 'Streamer', 'Podcast', 'Voice', 'Live Cam'],
      );
      // The party list shows «PK» in its own pill: its mark keeps the kind.
      final audioPk = LiveRoomCardData.fromSummary(
        _summary('AUDIO', inPk: true),
      );
      expect(LiveCardKind.of(audioPk), LiveCardKind.pk);
      expect(LiveCardKind.of(audioPk, withPk: false), LiveCardKind.audio);
      for (final party in PartyKind.values) {
        expect(party.cardKind.name, party.name);
      }
    });

    for (final language in AppLanguage.values) {
      testWidgets('each card draws only its tag (no glyph); screen readers '
          'hear the full type (${language.name})', (tester) async {
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
          // The word alone: nothing painted or iconic beside it.
          for (final type in [CustomPaint, Icon, Row]) {
            expect(
              find.descendant(of: tag, matching: find.byType(type)),
              findsNothing,
              reason: '$type in $kind',
            );
          }
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

      testWidgets(
        'D368: the card of a video podcast shows the «Podcast» tag with '
        'no camera after it; «Video» is only spoken (${language.name})',
        (tester) async {
          final l10n = l10nFor(language);
          setViewport(tester, GoldenViewport.phone);
          await pumpComponent(
            tester,
            _grid(const [
              LiveRoomCardData(
                hostName: 'V',
                title: 'video podcast',
                viewerCount: 3,
                isAudio: true,
                isPodcast: true,
                podcast: LivePodcast(
                  episodeNumber: 1,
                  topic: PodcastTopic.business,
                  video: true,
                ),
              ),
            ]),
            language: language,
          );
          final card = find.byKey(LiveHubGrid.cardKey(0));
          final tag = find.descendant(
            of: card,
            matching: find.byKey(KLiveGridCard.typeKey),
          );
          expect(tester.widget<LiveTypeTag>(tag).kind, LiveCardKind.podcast);
          expect(tester.widget<LiveTypeTag>(tag).video, isTrue);
          for (final type in [Icon, Row, CustomPaint]) {
            expect(
              find.descendant(of: tag, matching: find.byType(type)),
              findsNothing,
              reason: '$type',
            );
          }
          expect(
            find.descendant(
              of: card,
              matching: find.byIcon(Icons.videocam_rounded),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: tag,
              matching: find.text(l10n.liveTypeTagPodcast),
            ),
            findsOneWidget,
          );
          expect(
            tester
                .getSemantics(
                  find.byKey(LiveTypeTag.keyOf(LiveCardKind.podcast)),
                )
                .label,
            '${l10n.liveCategoryPodcast} · ${l10n.podcastVideoBadge}',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  for (final language in AppLanguage.values) {
    final rtl = language == AppLanguage.ar;
    testWidgets('360×800 at text ×1.3 (real fonts): no overflow; the tag '
        'right beside the live wave at the top start, clear of the count, '
        'the card aspect unchanged (${language.name})', (tester) async {
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
        final wave = tester.getRect(
          find.descendant(
            of: cardFinder,
            matching: find.byType(KLiveEqualizer),
          ),
        );
        final text = tester.getRect(
          find.descendant(
            of: cardFinder,
            matching: find.byKey(LiveTypeTag.textKey),
          ),
        );
        expect(tag.height, lessThanOrEqualTo(LiveTypeTag.maxHeight));
        // Beside the wave: the same row, the small token gap.
        expect((text.center.dy - wave.center.dy).abs(), lessThan(1.5));
        expect(tag.top - card.top, lessThan(14));
        expect(
          card.contains(tag.topLeft) && card.contains(tag.bottomRight),
          isTrue,
        );
        expect(tag.overlaps(count), isFalse, reason: 'card $i');
        if (rtl) {
          // The start is the right: the tag right of centre, the count at
          // the left, the wave before (right of) the word.
          expect(tag.center.dx, greaterThan(card.center.dx));
          expect(count.right, lessThan(tag.left));
          expect(wave.left - text.right, closeTo(KSpacing.xs, 0.5));
        } else {
          expect(tag.center.dx, lessThan(card.center.dx));
          expect(count.left, greaterThan(tag.right));
          expect(text.left - wave.right, closeTo(KSpacing.xs, 0.5));
        }
      }
    });
  }
}
