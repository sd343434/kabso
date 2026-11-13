// D282 (owner: «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه
// عربي وانجليزي لمن هاتفه انجليزي»): the owner's art is THE Kabso Team badge,
// at its own aspect ratio and never mirrored, before a staff line's name in
// every chat mode at the line's emblem height. D388 (owner: «فريق كابسو
// يأخذون شارة لكن الشارة لها شريط ازله»): the banner is gone — the badge is
// the crest alone, with no name written on it; the name is its spoken label.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_role_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _team = LiveChatAuthorBadges(kabsoTeam: true);

Widget _badge(double height) => Center(child: KabsoTeamBadge(height: height));

/// A staff member's lines in the chat's three looks: the host's flat line,
/// the boxed authored line and the video live's inline row.
Widget _lines(String name) => ProviderScope(
  child: Align(
    alignment: AlignmentDirectional.topStart,
    child: ColoredBox(
      color: const Color(0xFF2A1F3D),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiveChatFlatLine(
              name: name,
              text: 'Hello',
              label: 'line',
              role: LiveChatRole.viewer,
              badges: _team,
            ),
            const SizedBox(height: 12),
            LiveChatAuthoredLine(
              name: name,
              avatarUrl: null,
              label: 'line',
              message: const Text('Hello'),
              maxWidth: 300,
              color: LiveRoomChatLines.messageBox,
              role: LiveChatRole.viewer,
              badges: _team,
            ),
            const SizedBox(height: 12),
            LiveChatInlineRow(
              maxWidth: 300,
              color: LiveRoomChatLines.messageBox,
              name: name,
              text: 'Hello',
              label: 'line',
              role: LiveChatRole.viewer,
              badges: _team,
            ),
          ],
        ),
      ),
    ),
  ),
);

/// A golden at the phone's @3x: the app at the root (as the D273 goldens).
Future<void> _shot(
  WidgetTester tester,
  Widget child, {
  required AppLanguage language,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
    language: language,
  );
  await precacheImages(tester);
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  test('the art is the crest aspect ratio (398 × 328) and in the bundle', () {
    expect(KabsoTeamBadge.aspectRatio, closeTo(1.2134, 0.001));
    expect(const KabsoTeamBadge(height: 21).width, closeTo(25.48, 0.01));
    // D388: the crest alone (the banner made it 2.2 × its height).
    expect(KabsoTeamBadge.aspectRatio, lessThan(1.5));
  });

  testWidgets('the asset decodes at the declared aspect ratio', (tester) async {
    final size = await tester.runAsync(() async {
      final data = await rootBundle.load(KabsoTeamBadge.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    });
    expect(size!.width / size.height, closeTo(KabsoTeamBadge.aspectRatio, .01));
    // ≥ 3× the largest drawn height (40 pt on the shift page).
    expect(size.height, greaterThanOrEqualTo(40 * 3));
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: the crest alone — no name written on '
        'it, the name spoken, the art unmirrored (D388)', (tester) async {
      await pumpGolden(tester, _badge(40), language: language, bare: true);
      final l = l10nFor(language);
      expect(
        l.liveKabsoTeam,
        language == AppLanguage.ar ? 'فريق كابسو' : 'Kabso Team',
      );
      // The crest's natural aspect ratio.
      final badge = _rect(tester, KabsoTeamBadge.badgeKey);
      expect(badge.height, 40);
      expect(badge.width, closeTo(40 * KabsoTeamBadge.aspectRatio, .01));
      // D388: no text drawn on the badge (the banner and its name are gone).
      expect(
        find.descendant(
          of: find.byKey(KabsoTeamBadge.badgeKey),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.text(l.liveKabsoTeam), findsNothing);
      // Never mirrored: the art is not flipped in Arabic.
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(KabsoTeamBadge.badgeKey),
          matching: find.byType(Image),
        ),
      );
      expect(image.matchTextDirection, isFalse);
      // Read once, as the team's name.
      expect(find.bySemanticsLabel(l.liveKabsoTeam), findsOneWidget);
    });
  }

  testWidgets('a large text scale never changes the crest (no overflow)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final h in [12.0, 16.0, 21.0, 36.0]) {
      await pumpGolden(tester, _badge(h), language: AppLanguage.ar, bare: true);
      expect(tester.takeException(), isNull);
      expect(_rect(tester, KabsoTeamBadge.badgeKey).height, h);
    }
  });

  testWidgets("every chat look: the team's badge before the name, taller "
      'than the emblems (D282b)', (tester) async {
    await pumpGolden(tester, _lines('Omar'), language: AppLanguage.en);
    final badges = find.byKey(KabsoTeamBadge.badgeKey);
    expect(badges, findsNWidgets(3));
    final heights = [
      for (final e in badges.evaluate())
        tester.getSize(find.byWidget(e.widget)),
    ];
    // D282b: taller than the lines' other emblems, so the name reads.
    expect(heights.map((s) => s.height), [
      KabsoTeamBadge.flatChatHeight,
      KabsoTeamBadge.chatHeight,
      KabsoTeamBadge.chatHeight,
    ]);
    expect(KabsoTeamBadge.flatChatHeight, greaterThan(KFlatChat.emblemHeight));
    expect(
      KabsoTeamBadge.chatHeight,
      greaterThan(LiveChatInlineRow.badgeHeight),
    );
    for (final s in heights) {
      expect(s.width / s.height, closeTo(KabsoTeamBadge.aspectRatio, .01));
    }
    // The old blue pill is gone: each is a team tag drawing the badge.
    for (final tag in tester.widgetList<LiveChatRoleTag>(
      find.byType(LiveChatRoleTag),
    )) {
      expect(tag.kind, LiveChatTagKind.team);
    }
  });

  for (final viewport in GoldenViewport.values) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('${viewport.name} ×$scale: the staff lines never overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final language in AppLanguage.values) {
          await pumpGolden(
            tester,
            _lines(
              language == AppLanguage.ar
                  ? 'سارة عبد الرحمن الهاشمية من الإسكندرية'
                  : 'Sara Abdulrahman Al-Hashimi of Alexandria',
            ),
            language: language,
            viewport: viewport,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('kabso_team_badge (${language.name})', (tester) async {
        await _shot(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final h in [16.0, 20.0, 24.0, 40.0, 80.0]) ...[
                KabsoTeamBadge(height: h),
                const SizedBox(height: 12),
              ],
            ],
          ),
          language: language,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/kabso_team_badge_d282.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);

      testWidgets('kabso_team_chat_lines (${language.name})', (tester) async {
        await _shot(
          tester,
          _lines(language == AppLanguage.ar ? 'عمر' : 'Omar'),
          language: language,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/kabso_team_chat_d282.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}
