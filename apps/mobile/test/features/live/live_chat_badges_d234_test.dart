// D234 (owner, on a live chat screenshot: «لماذا الأيقونة التي ليفيلها ٢٧
// بحجم مختلف؟ أريدهم بنفس الحجم. وتحت سطر أيقونات الليفيل تكون الميداليات حتى
// ٥ ميداليات، وتحتهم النص» + «أسود شفاف»; contract v1.52-live, CONVENTIONS
// §10.82): a chat line is the name / the role pills and level emblems at one
// height / up to five showcased medals / the message, on translucent black
// unless a chat bubble is worn.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The medal art of «10 live hours».
const _hoursArt = 'medal_live_hours_10';

const _six = [
  LiveChatAuthorMedal(code: 'm1', iconKey: 'medal_first_family'),
  LiveChatAuthorMedal(code: 'm2', iconKey: 'medal_first_cp'),
  LiveChatAuthorMedal(code: 'm3', iconKey: 'medal_charm_10'),
  LiveChatAuthorMedal(code: 'm4', iconKey: 'medal_first_live'),
  LiveChatAuthorMedal(code: 'm5', iconKey: _hoursArt),
  LiveChatAuthorMedal(code: 'm6', iconKey: 'medal_bullet_first'),
];

/// The owner's screenshot: charm 32, support 27, family «black» 7, newcomer.
LiveChatAuthorBadges _badges({List<LiveChatAuthorMedal> medals = const []}) =>
    LiveChatAuthorBadges(
      charmLevel: 32,
      supportLevel: 27,
      family: const LiveChatAuthorFamily(name: 'black', level: 7),
      newcomer: true,
      medals: medals,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double scale = 1,
}) async {
  setViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpScreen(
    tester,
    ColoredBox(
      color: const Color(0xFF22303F),
      child: Align(alignment: AlignmentDirectional.bottomStart, child: child),
    ),
    language: language,
  );
  await tester.pump();
}

Widget _inline({
  LiveChatAuthorBadges? badges,
  bool cp = false,
  double maxWidth = 318.5,
}) => LiveChatInlineRow(
  maxWidth: maxWidth,
  color: LiveRoomChatLines.messageBox,
  label: 'line',
  name: 'عبدالرحمن الكبير Star 2026',
  role: LiveChatRole.host,
  badges: badges ?? _badges(medals: _six),
  cp: cp,
  text: 'أهلاً بكم في البث',
);

Rect _imageIn(WidgetTester tester, Key key) => tester.getRect(
  find.descendant(of: find.byKey(key), matching: find.byType(Image)).first,
);

void main() {
  test('the wire: medals parse in order; a server without them reads as '
      'none', () {
    final badges = LiveChatAuthorBadges.fromJson({
      'charmLevel': 3,
      'supportLevel': null,
      'family': null,
      'newcomer': false,
      'medals': [
        {'code': 'a', 'iconKey': 'medal_first_cp'},
        {'code': 'b', 'iconKey': 'medal_first_live'},
      ],
    });
    expect(badges.medals.map((m) => m.code), ['a', 'b']);
    expect(badges.medals.first.iconKey, 'medal_first_cp');
    expect(
      LiveChatAuthorBadges.fromJson({'charmLevel': 1, 'newcomer': true}).medals,
      isEmpty,
    );
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    group('video row (${language.name})', () {
      testWidgets('every emblem of the badges line is one height; the pills '
          'match it', (tester) async {
        await _pump(tester, _inline(), language: language);
        const h = LiveChatInlineRow.badgeHeight;
        final charm = _imageIn(tester, LiveChatBadgeRow.charmKey);
        final support = _imageIn(tester, LiveChatBadgeRow.supportKey);
        // The «32» creature and the «27» art: the same height on screen.
        expect(charm.height, closeTo(h, 0.5));
        expect(support.height, closeTo(h, 0.5));
        expect((charm.center.dy - support.center.dy).abs(), lessThan(0.5));
        for (final key in [
          LiveChatBadgeRow.roleKey,
          LiveChatBadgeRow.newcomerKey,
          LiveChatBadgeRow.familyKey,
        ]) {
          expect(
            tester.getSize(find.byKey(key)).height,
            closeTo(LiveChatBadgeRow.pillHeight(h), 0.5),
            reason: '$key',
          );
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('the name, the badges, up to 5 medals in order, then the '
          'message — all at the reading start', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, _inline(), language: language);
        final name = tester.getRect(find.byKey(LiveChatInlineRow.nameKey));
        final badges = tester.getRect(find.byKey(LiveChatInlineRow.badgesKey));
        final medals = tester.getRect(find.byKey(LiveChatMedalRow.rowKey));
        final text = tester.getRect(find.byKey(LiveChatInlineRow.textKey));
        expect(badges.top, greaterThanOrEqualTo(name.bottom - 0.5));
        expect(medals.top, greaterThanOrEqualTo(badges.bottom - 0.5));
        expect(text.top, greaterThanOrEqualTo(medals.bottom - 0.5));
        expect(medals.height, closeTo(LiveChatInlineRow.medalSize, 0.5));
        // Five of the six, in the server's order, from the reading start.
        expect(find.byType(MedalIcon), findsNWidgets(5));
        expect(find.byKey(LiveChatMedalRow.medalKey('m6')), findsNothing);
        final xs = [
          for (final c in ['m1', 'm2', 'm3', 'm4', 'm5'])
            tester.getRect(find.byKey(LiveChatMedalRow.medalKey(c))).center.dx,
        ];
        for (var i = 1; i < xs.length; i++) {
          expect(ar ? xs[i] < xs[i - 1] : xs[i] > xs[i - 1], isTrue);
        }
        final row = tester.getRect(find.byKey(LiveChatInlineRow.rowKey));
        final pad = LiveChatInlineRow.padding.start;
        for (final r in [name, badges, medals, text]) {
          if (ar) {
            expect(r.right, closeTo(row.right - pad, 0.5));
          } else {
            expect(r.left, closeTo(row.left + pad, 0.5));
          }
        }
        // The line says how many medals.
        final l10n = l10nFor(language);
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(l10n.liveChatMedalsLabel(5))),
          ),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets('no medals: no row and no placeholder', (tester) async {
        await _pump(tester, _inline(badges: _badges()), language: language);
        expect(find.byKey(LiveChatMedalRow.rowKey), findsNothing);
        expect(find.byType(MedalIcon), findsNothing);
      });

      testWidgets('translucent black without a bubble; the worn bubble '
          'instead', (tester) async {
        await _pump(tester, _inline(), language: language);
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(LiveChatInlineRow.rowKey),
                matching: find.byType(Container),
              )
              .first,
        );
        final deco = box.decoration! as BoxDecoration;
        expect(deco.color, LiveRoomChatLines.messageBox);
        expect(deco.color!.a, inInclusiveRange(0.35, 0.45));
        expect(deco.border, isNull);
        await _pump(tester, _inline(cp: true), language: language);
        expect(find.byKey(LiveCpChatBubble.bubbleKey), findsOneWidget);
      });

      for (final (viewport, scale) in [
        (GoldenViewport.phone, 1.0),
        (GoldenViewport.android, 1.3),
      ]) {
        testWidgets('${viewport.name} ×$scale: everything at once, no '
            'overflow', (tester) async {
          await _pump(
            tester,
            Builder(
              builder: (context) =>
                  _inline(maxWidth: LiveChatInlineRow.chatMaxWidth(context)),
            ),
            language: language,
            viewport: viewport,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          final row = tester.getRect(find.byKey(LiveChatInlineRow.rowKey));
          final medals = tester.getRect(find.byKey(LiveChatMedalRow.rowKey));
          expect(medals.width, lessThanOrEqualTo(row.width));
        });
      }
    });

    testWidgets('audio/podcast box (${language.name}): the medals under the '
        'badges, one emblem height, translucent black', (tester) async {
      await _pump(
        tester,
        LiveChatAuthoredLine(
          name: 'Huda',
          avatarUrl: null,
          label: 'line',
          message: const Text('لحظة'),
          maxWidth: 314,
          color: LiveRoomChatLines.messageBox,
          role: LiveChatRole.host,
          badges: _badges(medals: _six.take(3).toList()),
        ),
        language: language,
      );
      expect(find.byType(MedalIcon), findsNWidgets(3));
      final badges = tester.getRect(find.byType(LiveChatBadgeRow));
      final medals = tester.getRect(find.byKey(LiveChatMedalRow.rowKey));
      final message = tester.getRect(
        find.byKey(LiveChatAuthoredLine.bubbleKey),
      );
      expect(medals.top, greaterThanOrEqualTo(badges.bottom - 0.5));
      expect(message.top, greaterThanOrEqualTo(medals.bottom - 0.5));
      const h = LiveChatAuthoredLine.badgeRowHeight;
      expect(
        _imageIn(tester, LiveChatBadgeRow.charmKey).height,
        closeTo(h, 0.5),
      );
      expect(
        _imageIn(tester, LiveChatBadgeRow.supportKey).height,
        closeTo(h, 0.5),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(LiveChatAuthoredLine.boxKey),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        LiveRoomChatLines.messageBox,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
