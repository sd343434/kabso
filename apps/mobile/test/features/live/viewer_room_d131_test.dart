// D131 (owner, refs 158–160): the video live as a viewer sees it — the
// host pill's lines (this live's points with the cherry, then its taps),
// the follow capsule, the chat rows, the quick replies, the tap lane over
// the gift button and the leave prompt — on a 393 × 852 phone with its safe
// areas, in English and Arabic.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/emoji/unicode_emoji.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _rateLimited = ServerFailure(
  code: ErrorCode.rateLimited,
  rawCode: 'RATE_LIMITED',
  debugMessage: 'x',
  statusCode: 429,
);

Future<(FakeLiveRepository, FakeProfileRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  PublicProfile? profile,
  bool signedIn = true,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3
    ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
  final repo = FakeLiveRepository(
    room: (id) => apiRoom(id: id).copyWith(
      score: 1956007,
      roomNumber: 1234,
      scoreParts: const LiveScore(
        total: 1956007,
        tapPoints: 532,
        supportPoints: 1955475,
      ),
    ),
  );
  final profiles = FakeProfileRepository(profile ?? apiProfile());
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(profiles),
      currentUserProvider.overrideWithValue(signedIn ? testUser() : null),
    ],
  );
  await tester.pumpAndSettle();
  return (repo, profiles, engine);
}

void main() {
  final en = l10nFor(AppLanguage.en);

  testWidgets("host pill: 31 pt, the cherry and this live's points, then "
      'its taps every 3 s; the cyan "+" capsule', (tester) async {
    await _pump(tester);
    final pill = find.descendant(
      of: find.byType(KHostPill),
      matching: find.byType(Material),
    );
    expect(tester.getSize(pill.first).height, closeTo(31, 0.5));
    expect(
      find.descendant(
        of: find.byKey(LiveRoomScreen.scoreKey),
        matching: find.byType(KCherryIcon),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1,956,007'), findsOneWidget);
    expect(find.byKey(LiveRoomScreen.tapsKey), findsNothing);
    await tester.pump(KHostPill.lineTime);
    await tester.pumpAndSettle();
    expect(find.byKey(LiveRoomScreen.tapsKey), findsOneWidget);
    expect(find.textContaining('532'), findsOneWidget);
    await tester.pump(KHostPill.lineTime);
    await tester.pumpAndSettle();
    expect(find.byKey(LiveRoomScreen.scoreKey), findsOneWidget);
    // The follow capsule (announced "Follow").
    final follow = find.bySemanticsLabel(en.liveFollow);
    expect(follow, findsOneWidget);
    expect(tester.getSize(follow).width, greaterThanOrEqualTo(48));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the tap lane: 30 pt characters 5 pt from the right edge, '
      'over the gift button, starting above the bar', (tester) async {
    await _pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 420));
      await tester.pump(const Duration(milliseconds: 30));
    }
    final chars = find.byType(LiveTapCharacter);
    expect(chars, findsNWidgets(3));
    final gift = tester.getRect(find.byKey(LiveRoomScreen.giftKey));
    for (final c in chars.evaluate()) {
      final r = tester.getRect(find.byWidget(c.widget));
      expect(r.width, inInclusiveRange(28, 33));
      expect(r.right, lessThanOrEqualTo(393 - 5 + 0.5));
      expect(r.left, greaterThanOrEqualTo(393 - 5 - 36 - 0.5));
      expect(r.bottom, lessThan(gift.top));
      expect((r.center.dx - gift.center.dx).abs(), lessThan(10));
    }
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('quick replies send ordinary text messages', (tester) async {
    final (repo, _, _) = await _pump(tester);
    expect(find.text(en.liveQuickHello), findsOneWidget);
    await tester.tap(find.byKey(KQuickReplies.chipKey(2)));
    await tester.pumpAndSettle();
    expect(repo.chatCalls, contains('send:${en.liveQuickNiceMood}'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no quick replies for a guest (no account)', (tester) async {
    await _pump(tester, signedIn: false);
    expect(find.byType(KQuickReplies), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('leave prompt (ref 160)', () {
    testWidgets('not following: ✕ asks; outside keeps watching; "Exit live '
        'room" leaves without following', (tester) async {
      final (_, profiles, _) = await _pump(tester);
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsOneWidget);
      expect(find.text(en.liveLeaveTitle), findsOneWidget);
      // Measured: 18.3 pt from the sides, 43.9 pt buttons.
      final card = tester.getRect(find.byKey(KLeavePrompt.cardKey));
      expect(card.left, closeTo(18.3, 0.5));
      expect(card.right, closeTo(393 - 18.3, 0.5));
      expect(
        tester.getSize(find.byKey(KLeavePrompt.followKey)).height,
        closeTo(43.9, 0.5),
      );
      await tester.tapAt(const Offset(200, 150));
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsNothing);
      expect(find.byType(LiveRoomScreen), findsOneWidget);
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLeavePrompt.exitKey));
      await tester.pumpAndSettle();
      expect(profiles.calls.where((c) => c.startsWith('PUT')), isEmpty);
    });

    testWidgets('"Follow and exit" follows; a failed follow says why and '
        'stays', (tester) async {
      final (_, profiles, _) = await _pump(tester);
      profiles.followFailure = _rateLimited;
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLeavePrompt.followKey));
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'PUT host0');
      expect(find.text(en.errorRateLimited), findsOneWidget);
      expect(find.byType(LiveRoomScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The follow was rolled back: ✕ still asks.
      expect(find.byType(KLeavePrompt), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('already following, or a guest: ✕ leaves at once', (
      tester,
    ) async {
      await _pump(tester, profile: apiProfile(isFollowing: true));
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsNothing);
      await _pump(tester, signedIn: false);
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsNothing);
    });

    testWidgets('Arabic: the card and its buttons, no overflow', (
      tester,
    ) async {
      final ar = l10nFor(AppLanguage.ar);
      await _pump(tester, language: AppLanguage.ar);
      await tester.tap(find.byKey(KLiveRoomScaffold.closeKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.liveLeaveFollow), findsOneWidget);
      expect(find.text(ar.liveLeaveExit), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('emoji panel (ref 162, D138)', () {
    // The owner's pack emojis loop in the grid: pump, never settle.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(find.byKey(KViewerBar.emojiKey));
      await frames(tester);
      expect(find.byKey(LiveChatComposer.emojiPanelKey), findsOneWidget);
    }

    testWidgets('😊 opens the box on the emoji panel with no keyboard; the '
        "owner's nine packs first (each tab one of its emojis), then the "
        'Unicode groups; 5 columns; a tap puts the emoji in the field; the '
        'field brings the keyboard back', (tester) async {
      final (repo, _, _) = await _pump(tester);
      await openPanel(tester);
      final field = tester.widget<TextField>(
        find.byKey(LiveChatComposer.fieldKey),
      );
      expect(field.focusNode!.hasFocus, isFalse);
      // The strip: the packs, then the groups, in reading order (LTR).
      final tabs = [
        for (final p in EmojiPack.values) LiveChatComposer.packTabKey(p),
        for (final g in UnicodeEmojiGroup.values) LiveChatComposer.groupKey(g),
      ];
      expect(tabs, hasLength(18));
      // The strip in reading order: its list's children, start to end.
      final stripFinder = find
          .descendant(
            of: find.byKey(LiveChatComposer.emojiPanelKey),
            matching: find.byType(ListView),
          )
          .first;
      final delegate =
          tester.widget<ListView>(stripFinder).childrenDelegate
              as SliverChildListDelegate;
      final order = [
        for (final child in delegate.children) (child as Semantics).child!.key,
      ];
      expect(order, tabs);
      // Kabi, the first pack, sits at the start (left in English).
      expect(
        tester.getCenter(find.byKey(tabs.first)).dx,
        lessThan(tester.getCenter(find.byKey(tabs[1])).dx),
      );
      final strip = find
          .descendant(of: stripFinder, matching: find.byType(Scrollable))
          .first;
      // Each pack's tab shows one of its emojis (still), and says its name.
      for (final p in EmojiPack.values.reversed) {
        await tester.scrollUntilVisible(
          find.byKey(LiveChatComposer.packTabKey(p)),
          -40,
          scrollable: strip,
        );
        final icon = find.descendant(
          of: find.byKey(LiveChatComposer.packTabKey(p)),
          matching: find.byType(KabiEmoji),
        );
        expect(tester.widget<KabiEmoji>(icon).emoji, p.icon);
        expect(tester.widget<KabiEmoji>(icon).animate, isFalse);
        expect(
          tester.getSemantics(find.byKey(LiveChatComposer.packTabKey(p))),
          matchesSemantics(
            label: p.label(en),
            isButton: true,
            hasSelectedState: true,
            isSelected: p == EmojiPack.values.first,
          ),
        );
      }
      // Opens on the first pack: its emojis animate, five to a row, at
      // the grid pitch, each named for screen readers.
      final kabi = EmojiPack.kabi.emojis;
      final y = tester
          .getCenter(find.byKey(LiveChatComposer.packKey(kabi[0])))
          .dy;
      for (final e in kabi.take(5)) {
        final cell = find.byKey(LiveChatComposer.packKey(e));
        expect(tester.getCenter(cell).dy, y);
        final emoji = tester.widget<KabiEmoji>(
          find.descendant(of: cell, matching: find.byType(KabiEmoji)),
        );
        expect(emoji.animate, isTrue);
        expect(emoji.size, EmojiPanel.packCell);
        expect(
          tester.getSemantics(cell),
          matchesSemantics(
            label: e.label(en),
            isButton: true,
            hasTapAction: true,
          ),
        );
      }
      expect(
        tester.getCenter(find.byKey(LiveChatComposer.packKey(kabi[5]))).dy - y,
        moreOrLessEquals(EmojiPanel.gridRow, epsilon: 0.01),
      );
      // Only the chosen tab is built: no other pack's emojis yet.
      expect(
        find.byKey(LiveChatComposer.packKey(EmojiPack.kiki.emojis.first)),
        findsNothing,
      );
      // A pack emoji goes in as its token; Unicode as itself.
      await tester.tap(
        find.byKey(LiveChatComposer.packKey(KabsoEmoji.kabi('love'))),
      );
      await tester.pump();
      expect(field.controller!.text, ':kabi_love:');
      await tester.scrollUntilVisible(
        find.byKey(LiveChatComposer.groupKey(UnicodeEmojiGroup.smileys)),
        40,
        scrollable: strip,
      );
      await tester.ensureVisible(
        find.byKey(LiveChatComposer.groupKey(UnicodeEmojiGroup.smileys)),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(LiveChatComposer.groupKey(UnicodeEmojiGroup.smileys)),
      );
      await frames(tester);
      final first = UnicodeEmojiGroup.smileys.emojis;
      final uy = tester
          .getCenter(find.byKey(LiveChatComposer.unicodeKey(first[0])))
          .dy;
      for (final e in first.take(5)) {
        expect(
          tester.getCenter(find.byKey(LiveChatComposer.unicodeKey(e))).dy,
          uy,
        );
      }
      await tester.tap(find.byKey(LiveChatComposer.unicodeKey('😂')));
      await tester.pump();
      expect(field.controller!.text, ':kabi_love:😂');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await frames(tester);
      expect(repo.chatCalls, contains('send::kabi_love:😂'));
      // The keyboard key switches back to typing.
      await tester.tap(find.byKey(LiveChatComposer.modeKey));
      await frames(tester);
      expect(find.byKey(LiveChatComposer.emojiPanelKey), findsNothing);
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a pack emoji sent shows animated, inline, in the chat row', (
      tester,
    ) async {
      final (repo, _, _) = await _pump(tester);
      await openPanel(tester);
      await tester.tap(
        find.byKey(LiveChatComposer.packKey(KabsoEmoji.kabi('love'))),
      );
      await tester.pump();
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await frames(tester);
      expect(repo.chatCalls, contains('send::kabi_love:'));
      // Close the box: what is left is the room.
      await tester.tap(find.byKey(LiveChatComposer.modeKey));
      await frames(tester);
      final row = find.byType(LiveChatInlineRow);
      final inline = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is KabiEmoji && w.emoji == KabsoEmoji.kabi('love'),
        ),
      );
      expect(inline, findsOneWidget);
      expect(tester.widget<KabiEmoji>(inline).animate, isTrue);
      expect(
        tester
            .widget<Lottie>(
              find.descendant(of: inline, matching: find.byType(Lottie)),
            )
            .animate,
        isTrue,
      );
      expect(find.text(':kabi_love:', findRichText: true), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reduced motion: the pack emojis stay on their first frame', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester);
      await tester.tap(find.byKey(KViewerBar.emojiKey));
      await tester.pumpAndSettle();
      final lotties = tester.widgetList<Lottie>(
        find.descendant(
          of: find.byKey(LiveChatComposer.emojiPanelKey),
          matching: find.byType(Lottie),
        ),
      );
      expect(lotties, isNotEmpty);
      expect(lotties.where((l) => l.animate), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Arabic RTL: the packs start at the right; no overflow at '
        '393 and at 360 pt, text scale 1.3', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      await openPanel(tester);
      final kabi = tester.getCenter(
        find.byKey(LiveChatComposer.packTabKey(EmojiPack.kabi)),
      );
      final kiki = tester.getCenter(
        find.byKey(LiveChatComposer.packTabKey(EmojiPack.kiki)),
      );
      expect(kabi.dx, greaterThan(kiki.dx));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(360, 800) * 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LiveChatComposer(
              controller: TextEditingController(),
              focusNode: FocusNode(),
              hint: 'x',
              sendLabel: 'send',
              onSend: () {},
              onEmoji: (_) {},
              startWithEmoji: true,
            ),
          ),
        ),
        language: AppLanguage.ar,
      );
      await frames(tester);
      expect(find.byKey(LiveChatComposer.emojiPanelKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
