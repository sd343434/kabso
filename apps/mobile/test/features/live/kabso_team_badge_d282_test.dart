// D282 (owner: «اجعلها شارة فريق كابسو بحيث سوف تضع الاسم بالعربي لمن هاتفه
// عربي وانجليزي لمن هاتفه انجليزي»): the owner's crest-and-banner art is THE
// Kabso Team badge — the name in its banner in the phone's language, the
// art at its own aspect ratio and never mirrored, before a staff line's
// name in every chat mode at the line's emblem height.

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
  test('the art is the badge aspect ratio (600 × 258) and in the bundle', () {
    expect(KabsoTeamBadge.aspectRatio, closeTo(2.3256, 0.001));
    expect(const KabsoTeamBadge(height: 21).width, closeTo(48.84, 0.01));
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
    testWidgets('${language.name}: the team name in the banner, the art '
        'unmirrored', (tester) async {
      await pumpGolden(tester, _badge(40), language: language, bare: true);
      final l = l10nFor(language);
      expect(
        l.liveKabsoTeam,
        language == AppLanguage.ar ? 'فريق كابسو' : 'Kabso Team',
      );
      final label = find.byKey(KabsoTeamBadge.labelKey);
      expect(tester.widget<Text>(label).data, l.liveKabsoTeam);
      // The art's natural aspect ratio.
      final badge = _rect(tester, KabsoTeamBadge.badgeKey);
      expect(badge.height, 40);
      expect(badge.width, closeTo(40 * KabsoTeamBadge.aspectRatio, .01));
      // Never mirrored: the art is not flipped in Arabic …
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(KabsoTeamBadge.badgeKey),
          matching: find.byType(Image),
        ),
      );
      expect(image.matchTextDirection, isFalse);
      // … and the name sits centred in the banner (right of the crest) in
      // both languages, inside it.
      const b = KabsoTeamBadge.banner;
      final banner = Rect.fromLTRB(
        badge.left + b.left * badge.width,
        badge.top + b.top * badge.height,
        badge.left + b.right * badge.width,
        badge.top + b.bottom * badge.height,
      );
      final text = tester.getRect(label);
      expect(text.center.dx, closeTo(banner.center.dx, 0.5));
      expect(text.center.dy, closeTo(banner.center.dy, 0.5));
      expect(text.left, greaterThanOrEqualTo(banner.left));
      expect(text.right, lessThanOrEqualTo(banner.right));
      expect(text.top, greaterThanOrEqualTo(banner.top - 0.01));
      expect(text.bottom, lessThanOrEqualTo(banner.bottom + 0.01));
      // Read once, as the team's name.
      expect(find.bySemanticsLabel(l.liveKabsoTeam), findsOneWidget);
    });
  }

  testWidgets('a long name scales down inside a tiny banner (no overflow)', (
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

  testWidgets("every chat look: the team's badge before the name at the "
      "line's emblem height", (tester) async {
    await pumpGolden(tester, _lines('Omar'), language: AppLanguage.en);
    final badges = find.byKey(KabsoTeamBadge.badgeKey);
    expect(badges, findsNWidgets(3));
    final heights = [
      for (final e in badges.evaluate())
        tester.getSize(find.byWidget(e.widget)),
    ];
    expect(heights.map((s) => s.height), [
      KFlatChat.tagHeight,
      LiveChatAuthoredLine.badgeRowHeight,
      LiveChatInlineRow.badgeHeight,
    ]);
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
