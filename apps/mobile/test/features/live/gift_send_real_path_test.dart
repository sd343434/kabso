// D131 (owner bug, staging: "Send in the gift panel does nothing"): the
// panel through the real viewer room on a 393 × 852 phone with its safe
// areas (59 top, 34 bottom), opened from the bottom bar's gift button, as
// the staging catalogue had it (one FUN gift). Send answers to a tap by
// its key and to a raw tap at its visual centre, and a picked gift is sent.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveGiftRepository> _openPanel(
  WidgetTester tester, {
  required Size size,
  required double top,
  required double bottom,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3
    ..padding = FakeViewPadding(top: top * 3, bottom: bottom * 3)
    ..viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  addTearDown(tester.view.reset);
  // As on staging: the catalogue lists three categories, one FUN gift.
  final gifts = FakeLiveGiftRepository(codes: const ['confetti']);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    liveGiftRepository: gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  final l10n = l10nFor(AppLanguage.en);
  await tester.tap(find.bySemanticsLabel(l10n.liveGifts));
  await tester.pumpAndSettle();
  expect(find.byType(KLiveGiftSheet), findsOneWidget);
  return gifts;
}

void main() {
  final l10n = l10nFor(AppLanguage.en);

  for (final (name, size, top, bottom) in [
    ('iPhone 393×852', const Size(393, 852), 59.0, 34.0),
    ('Android 360×740, 3-button nav', const Size(360, 740), 24.0, 48.0),
  ]) {
    testWidgets('$name: Send is inside the panel, on top, and answers', (
      tester,
    ) async {
      final gifts = await _openPanel(
        tester,
        size: size,
        top: top,
        bottom: bottom,
      );
      final send = find.byKey(KLiveGiftSheet.sendKey);
      final rect = tester.getRect(send);
      final sheet = tester.getRect(find.byKey(KLiveGiftSheet.sheetKey));
      // Fully on screen, inside the panel and above the bottom inset.
      expect(sheet.contains(rect.topLeft), isTrue);
      expect(rect.bottom, lessThanOrEqualTo(size.height - bottom));
      // Nothing covers it: a hit at its centre reaches its detector.
      final hit = HitTestResult();
      tester.binding.hitTestInView(hit, rect.center, tester.view.viewId);
      expect(
        hit.path.any(
          (e) =>
              e.target is RenderObject &&
              (e.target as RenderObject).debugCreator.toString().contains(
                "'gift.send'",
              ),
        ),
        isTrue,
      );

      // D131: the panel opens on the first tab with gifts (FUN here), not
      // on an empty Popular.
      expect(find.byKey(KLiveGiftSheet.cellKey('confetti')), findsOneWidget);
      expect(find.byKey(KLiveGiftSheet.emptyKey), findsNothing);

      // Nothing picked: a raw tap at the centre says why.
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(KLiveGiftSheet.toastKey),
          matching: find.text(l10n.liveGiftPickGift),
        ),
        findsOneWidget,
      );
      final toast = tester.getRect(find.byKey(KLiveGiftSheet.toastKey));
      expect(sheet.contains(toast.topLeft), isTrue);
      expect(sheet.contains(toast.bottomRight), isTrue);
      await tester.pump(KLiveGiftSheet.toastTime);

      // Pick the gift, Send by key: it is sent to the host and its banner
      // shows above the panel.
      await tester.tap(find.byKey(KLiveGiftSheet.cellKey('confetti')));
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(gifts.sends, hasLength(1));
      expect(gifts.sends.single.recipients, ['host0']);
      expect(gifts.sends.single.giftCode, 'confetti');
      final banner = tester.getRect(find.byType(LiveGiftBanner));
      expect(banner.bottom, lessThanOrEqualTo(sheet.top));
      // A second raw tap sends again (nothing stays stuck).
      await tester.tapAt(tester.getRect(send).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(gifts.sends, hasLength(2));
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the host gifts themself in their audio room: an old '
      "server's 400 on recipients is shown, then a send goes through", (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3)
      ..viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    final gifts = FakeLiveGiftRepository(codes: const ['confetti']);
    await pumpScreen(
      tester,
      const GoLiveScreen(),
      liveGiftRepository: gifts,
      overrides: [
        liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
        currentUserProvider.overrideWithValue(
          testUser().copyWith(canHost: true),
        ),
        liveBlockedWordsRepositoryProvider.overrideWithValue(
          FakeLiveBlockedWordsRepository(),
        ),
        liveScheduleRepositoryProvider.overrideWithValue(
          FakeLiveScheduleRepository(),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(apiProfile()),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
    await tester.tap(find.byKey(GoLiveScreen.startKey));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoLiveScreen.audioGiftKey));
    await tester.pumpAndSettle();
    expect(find.byType(KLiveGiftSheet), findsOneWidget);
    // D131 (ref 161): the host alone is the recipient (no row shown).
    expect(find.byKey(KLiveGiftSheet.recipientKey('host0')), findsNothing);
    await tester.tap(find.byKey(KLiveGiftSheet.cellKey('confetti')));
    await tester.pump();

    // A server without D128 refuses the host as a recipient.
    gifts.failNext['send'] = const ServerFailure(
      code: ErrorCode.validationFailed,
      rawCode: 'VALIDATION_FAILED',
      debugMessage: 'recipients invalid_value',
      statusCode: 400,
      details: [FieldIssue(field: 'recipients', issue: 'invalid_value')],
    );
    final send = find.byKey(KLiveGiftSheet.sendKey);
    await tester.tapAt(tester.getRect(send).center);
    await tester.pump();
    await tester.pump();
    expect(gifts.sends, hasLength(1));
    expect(gifts.sends.single.recipients, ['host0']);
    final sheet = tester.getRect(find.byKey(KLiveGiftSheet.sheetKey));
    // Said twice: over the grid and on the line above the bar, both on
    // screen inside the panel.
    final toast = tester.getRect(find.byKey(KLiveGiftSheet.toastKey));
    final line = tester.getRect(find.byKey(KLiveGiftSheet.reasonKey));
    for (final r in [toast, line]) {
      expect(
        sheet.contains(r.topLeft) && sheet.contains(r.bottomRight),
        isTrue,
      );
    }
    expect(line.bottom, lessThanOrEqualTo(tester.getRect(send).top));
    expect(
      tester.widget<Text>(find.byKey(KLiveGiftSheet.reasonKey)).data,
      l10n.liveGiftRecipientRefused,
    );
    await tester.pump(KLiveGiftSheet.toastTime);

    // The next tap is a new attempt and goes through.
    await tester.tap(send);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gifts.sends, hasLength(2));
    expect(find.byKey(KLiveGiftSheet.reasonKey), findsNothing);
    expect(find.byType(LiveGiftBanner), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
