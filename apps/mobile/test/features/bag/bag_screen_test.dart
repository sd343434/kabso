// CP-019 / D171 / D180: the bag screen (owner: only wearable owned items,
// never live gifts; «الأدوات» = in use, «الحقيبة» = the full list) — only
// owned items (never the catalogue),
// grouped by category (an unknown category still shows), each with its
// preview, where it came from, the time left («متبقٍ …», «ينتهي اليوم»,
// «دائم»), «ارتداء» / «إزالة» and «إرسال» (off with the reason for free
// items and level rewards); the send sheet (some days or all, the people
// search, the confirmation, an error); an item that runs out on screen
// leaves it; Arabic RTL and English at 360×800, text scale 1.3 and 2.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/presentation/bag_labels.dart';
import 'package:kabso_live/features/bag/presentation/bag_screen.dart';
import 'package:kabso_live/features/bag/presentation/bag_send_sheet.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bag_repository.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';

/// "Now" in these tests: 09:00 local.
final DateTime _now = DateTime(2026, 10, 30, 9);

const Map<String, Object?> _sara = {
  'id': '0192e4a0-7c1d-7000-8000-000000000002',
  'username': 'sara_22',
  'displayName': 'Sara',
  'avatarUrl': null,
};

/// A free card (worn), an admin item with 6 days 4 hours left, a gift from
/// @sara_22 that ends at 14:00 today, a permanent level reward and an item
/// of a category this app does not know yet (an entrance).
List<Map<String, Object?>> _items({bool ar = false}) => [
  bagItemJson('bunny_royal', ar: ar, source: 'FREE_SIGNUP'),
  bagItemJson(
    'golden_stags',
    ar: ar,
    expiresAt: _now.add(const Duration(days: 6, hours: 4)),
  ),
  bagItemJson(
    'emerald_wings',
    ar: ar,
    source: 'GIFT',
    giftedBy: _sara,
    expiresAt: _now.add(const Duration(hours: 5)),
  ),
  bagItemJson(
    'kabi_royal',
    ar: ar,
    source: 'LEVEL_REWARD',
    transferable: false,
  ),
  bagItemJson(
    'fire_frame',
    ar: ar,
    category: 'ENTRANCE',
    source: 'LEVEL_REWARD',
    transferable: false,
  ),
];

typedef _Fakes = ({
  FakeBagRepository bag,
  FakeProfileRepository profiles,
  FakePostsRepository posts,
  FakeLiveGiftRepository gifts,
});

Future<_Fakes> _pump(
  WidgetTester tester, {
  List<Map<String, Object?>>? items,
  String? worn = 'bunny_royal',
  AppLanguage language = AppLanguage.en,
  Map<String, int> gifts = const {},
}) async {
  setViewport(tester, GoldenViewport.android);
  final ar = language == AppLanguage.ar;
  final bag = FakeBagRepository(
    items: items ?? _items(ar: ar),
    worn: worn,
    ar: ar,
  );
  final profiles = FakeProfileRepository(apiProfile(isSelf: true));
  final posts = FakePostsRepository()..people = [UserSummary.fromJson(_sara)];
  final giftRepo = FakeLiveGiftRepository(held: gifts, ar: ar);
  await pumpBonds(
    tester,
    const BagScreen(),
    language: language,
    overrides: [
      bagRepositoryProvider.overrideWithValue(bag),
      profileRepositoryProvider.overrideWithValue(profiles),
      postsRepositoryProvider.overrideWithValue(posts),
      liveGiftRepositoryProvider.overrideWithValue(giftRepo),
    ],
  );
  return (bag: bag, profiles: profiles, posts: posts, gifts: giftRepo);
}

/// The Tools list (not the tab pages or the in-use row).
Finder get _list => find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

Text _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key));

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  ButtonStyleButton button(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key));

  Future<void> tab(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Selects [code] on «الحقيبة» (the full list).
  Future<void> select(WidgetTester tester, String code) async {
    if (find.byKey(BagScreen.itemKey(code)).evaluate().isEmpty &&
        find.byKey(BagScreen.sectionKey('PROFILE_CARD')).evaluate().isEmpty) {
      await tab(tester, BagScreen.itemsTabKey);
    }
    await tester.scrollUntilVisible(
      find.byKey(BagScreen.itemKey(code)),
      200,
      scrollable: _list,
    );
    await tester.ensureVisible(find.byKey(BagScreen.itemKey(code)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BagScreen.itemKey(code)));
    await tester.pumpAndSettle();
  }

  testWidgets('Tools: in use per category, all tools by category, times', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      // The user holds live gifts too: the bag never shows or asks for them.
      final f = await _pump(tester, gifts: const {'rose': 3});
      // Only the owned items (and, D186, the host-frame state) are asked
      // for; the catalogue never.
      expect(f.bag.calls, unorderedEquals(['myBag', 'hostFrame']));
      expect(find.byKey(BagScreen.toolsTabKey), findsOneWidget);
      expect(find.byKey(BagScreen.itemsTabKey), findsOneWidget);
      // «الأدوات»: what is worn, never the full list (that is «الحقيبة»).
      expect(find.text(en.bagInUse), findsOneWidget);
      expect(find.text(en.bagAllTools), findsNothing);
      expect(find.byKey(BagScreen.itemKey('golden_stags')), findsNothing);
      // In use: the worn profile card; the frame category (D186: known now)
      // has an empty slot.
      expect(
        find.descendant(
          of: find.byKey(BagScreen.slotKey('PROFILE_CARD')),
          matching: find.text('Royal Bunny'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(BagScreen.emptySlotKey('AVATAR_FRAME')),
        findsOneWidget,
      );
      // «الحقيبة»: every owned item by category (an unknown one as «Other
      // items»); still no live gifts.
      await tab(tester, BagScreen.itemsTabKey);
      expect(find.text(en.bagAllTools), findsOneWidget);
      expect(find.text(en.bagInUse), findsNothing);
      expect(f.gifts.calls, isEmpty);
      expect(find.byKey(BagScreen.sectionKey('PROFILE_CARD')), findsOneWidget);
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsOneWidget);
      expect(
        _text(tester, BagScreen.timeKey('bunny_royal')).data,
        en.bagPermanent,
      );
      expect(_text(tester, BagScreen.timeKey('golden_stags')).data, '6 days');
      expect(_text(tester, BagScreen.timeKey('emerald_wings')).data, '5 hours');
      await tester.scrollUntilVisible(
        find.byKey(BagScreen.itemKey('fire_frame')),
        200,
        scrollable: _list,
      );
      expect(find.byKey(BagScreen.sectionKey('ENTRANCE')), findsOneWidget);
      expect(find.text(en.bagCategoryOther), findsWidgets);
      // Nothing selected: Use and Send are off, nothing named.
      expect(button(tester, BagScreen.useKey).onPressed, isNull);
      expect(button(tester, BagScreen.sendKey).onPressed, isNull);
      expect(find.byKey(BagScreen.selectedNameKey), findsNothing);
    });
  });

  test('time left in Arabic and English', () {
    final now = DateTime(2026, 10, 30, 9);
    String left(Duration d, {bool arabic = true}) =>
        bagTimeLeft(arabic ? ar : en, now.add(d), now);
    expect(left(const Duration(days: 6, hours: 4)), 'متبقٍ 6 أيام 4 ساعات');
    expect(left(const Duration(hours: 5)), 'ينتهي اليوم');
    expect(left(const Duration(hours: 16)), 'متبقٍ 16 ساعة');
    expect(bagTimeLeft(ar, null, now), 'دائم');
    expect(left(const Duration(minutes: 1), arabic: false), '1 minute left');
    // The tiles: whole days, else hours / minutes; «دائم».
    expect(
      bagTileTime(ar, now.add(const Duration(days: 31, hours: 3)), now),
      '31 يوماً',
    );
    expect(bagTileTime(en, now.add(const Duration(days: 31)), now), '31 days');
    expect(bagTileTime(ar, now.add(const Duration(hours: 5)), now), '5 ساعات');
    expect(bagTileTime(ar, null, now), 'دائم');
  });

  testWidgets('select, Use: PUT the code, Remove appears, in use updates', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BagScreen)),
      );
      final sub = container.listen(profileStatsProvider('host0'), (_, _) {});
      addTearDown(sub.close);
      await tester.pumpAndSettle();
      final gets = f.profiles.calls.length;
      await select(tester, 'golden_stags');
      expect(_text(tester, BagScreen.selectedNameKey).data, 'Golden Stags');
      expect(_text(tester, BagScreen.selectedSourceKey).data, en.bagFromKabso);
      expect(button(tester, BagScreen.useKey).onPressed, isNotNull);
      expect(button(tester, BagScreen.sendKey).onPressed, isNotNull);
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('setEquipped:golden_stags'));
      expect(find.byKey(BagScreen.takeOffKey), findsOneWidget);
      expect(find.text(en.bagTakeOff), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
      // The user's own profile (their card) reloads too.
      expect(f.profiles.calls.length, greaterThan(gets));
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsNothing);
      expect(find.byKey(BagScreen.wornKey('golden_stags')), findsOneWidget);
      // «الأدوات» shows it in use, and the selection stays across tabs.
      await tab(tester, BagScreen.toolsTabKey);
      expect(
        find.descendant(
          of: find.byKey(BagScreen.slotKey('PROFILE_CARD')),
          matching: find.text('Golden Stags'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(BagScreen.takeOffKey), findsOneWidget);
      // Tapping the selected tile again clears the selection.
      await select(tester, 'golden_stags');
      expect(find.byKey(BagScreen.selectedNameKey), findsNothing);
    });
  });

  testWidgets('Remove («إزالة») the worn one: PUT null, the slot empties', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      await select(tester, 'bunny_royal');
      await tester.tap(find.byKey(BagScreen.takeOffKey));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('setEquipped:null'));
      expect(f.bag.worn, isNull);
      expect(find.byKey(BagScreen.useKey), findsOneWidget);
      await tab(tester, BagScreen.toolsTabKey);
      expect(
        find.byKey(BagScreen.emptySlotKey('PROFILE_CARD')),
        findsOneWidget,
      );
    });
  });

  testWidgets('not sendable: free items and level rewards say why', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(tester);
      await select(tester, 'bunny_royal');
      expect(button(tester, BagScreen.sendKey).onPressed, isNull);
      expect(_text(tester, BagScreen.noSendKey).data, en.bagNoSendFree);
      await select(tester, 'kabi_royal');
      expect(button(tester, BagScreen.sendKey).onPressed, isNull);
      expect(_text(tester, BagScreen.selectedSourceKey).data, en.bagFromLevel);
      expect(_text(tester, BagScreen.noSendKey).data, en.bagNoSendLevel);
      // Still wearable.
      expect(button(tester, BagScreen.useKey).onPressed, isNotNull);
      await select(tester, 'emerald_wings');
      expect(
        _text(tester, BagScreen.selectedSourceKey).data,
        'Gift from @sara_22',
      );
    });
  });

  testWidgets('BAG_ITEM_NOT_OWNED: its message, the bag reloads', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      f.bag.failNext['setEquipped'] = bondFailure(ErrorCode.bagItemNotOwned);
      await select(tester, 'golden_stags');
      await tester.tap(find.byKey(BagScreen.useKey));
      await tester.pumpAndSettle();
      expect(find.text(en.errorBagItemNotOwned), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
    });
  });

  testWidgets('Send from the bar: some days, the person, the confirmation', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      await select(tester, 'golden_stags');
      await tester.tap(find.byKey(BagScreen.sendKey));
      await tester.pumpAndSettle();
      expect(find.byType(BagSendSheet), findsOneWidget);
      expect(
        _text(tester, BagSendSheet.haveKey).data,
        'You have: 6 days 4 hours',
      );
      for (final d in [1, 3, 6]) {
        expect(find.byKey(BagSendSheet.daysKey(d)), findsOneWidget);
      }
      await tester.tap(find.byKey(BagSendSheet.daysKey(3)));
      await tester.pump();
      expect(
        _text(tester, BagSendSheet.noteKey).data,
        'You keep: 3 days 4 hours',
      );
      await tester.enterText(find.byKey(BagSendSheet.fieldKey), '@sa');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.personKey('sara_22')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      expect(
        find.text(
          en.bagSendConfirmBody(
            KFormat.bidiIsolate('Golden Stags'),
            '3 days',
            '@sara_22',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(BagSendSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('send:golden_stags:sara_22:3'));
      expect(find.text('Sent to @sara_22'), findsOneWidget);
      // A partial send keeps the selection.
      expect(find.byKey(BagScreen.selectedNameKey), findsOneWidget);
    });
  });

  testWidgets('Send all: the item leaves; a refused send keeps the sheet', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      f.bag.failNext['send'] = bondFailure(ErrorCode.bagRecipientHasPermanent);
      await select(tester, 'emerald_wings');
      await tester.tap(find.byKey(BagScreen.sendKey));
      await tester.pumpAndSettle();
      // 5 hours left: only «All».
      expect(find.byKey(BagSendSheet.daysKey(1)), findsNothing);
      await tester.enterText(find.byKey(BagSendSheet.fieldKey), 'sa');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.personKey('sara_22')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(
        _text(tester, BagSendSheet.errorKey).data,
        en.errorBagRecipientHasPermanent,
      );
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('send:emerald_wings:sara_22:all'));
      expect(find.byKey(BagScreen.itemKey('emerald_wings')), findsNothing);
      expect(find.byKey(BagScreen.selectedNameKey), findsNothing);
    });
  });

  testWidgets('an item that runs out on screen leaves it; the bag reloads', (
    tester,
  ) async {
    var now = _now;
    await withClock(Clock(() => now), () async {
      final f = await _pump(
        tester,
        items: [
          bagItemJson('bunny_royal', ar: false, source: 'FREE_SIGNUP'),
          bagItemJson(
            'golden_stags',
            ar: false,
            expiresAt: _now.add(const Duration(minutes: 1, seconds: 30)),
          ),
        ],
      );
      await tab(tester, BagScreen.itemsTabKey);
      expect(
        _text(tester, BagScreen.timeKey('golden_stags')).data,
        '2 minutes',
      );
      now = _now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(BagScreen.itemKey('golden_stags')), findsNothing);
      expect(find.byKey(BagScreen.itemKey('bunny_royal')), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
    });
  });

  testWidgets('a failed load shows the error with retry', (tester) async {
    setViewport(tester, GoldenViewport.android);
    final bag = FakeBagRepository()
      ..failNext['myBag'] = bondFailure(ErrorCode.internalError, status: 500);
    await pumpBonds(
      tester,
      const BagScreen(),
      overrides: [bagRepositoryProvider.overrideWithValue(bag)],
    );
    expect(find.text(en.bagLoadError), findsOneWidget);
    await tester.tap(find.text(en.actionRetry));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(BagScreen.slotKey('PROFILE_CARD')),
        matching: find.text('Royal Bunny'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('owning nothing: the empty state and an empty slot', (
    tester,
  ) async {
    final f = await _pump(tester, items: const [], worn: null);
    expect(find.byKey(BagScreen.emptyKey), findsOneWidget);
    expect(find.byKey(BagScreen.emptySlotKey('PROFILE_CARD')), findsOneWidget);
    await tab(tester, BagScreen.itemsTabKey);
    expect(find.byKey(BagScreen.emptyKey), findsOneWidget);
    expect(f.bag.calls, unorderedEquals(['myBag', 'hostFrame']));
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('Arabic (RTL) and English at 360×800, text scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await withClock(Clock.fixed(_now), () async {
        for (final language in AppLanguage.values) {
          await tester.pumpWidget(const SizedBox.shrink());
          await _pump(tester, language: language);
          expect(tester.takeException(), isNull, reason: language.name);
          final isAr = language == AppLanguage.ar;
          final l10n = isAr ? ar : en;
          expect(find.text(l10n.bagTabTools), findsOneWidget);
          if (isAr) {
            expect(find.text('قيد الاستخدام'), findsOneWidget);
            expect(find.text('استخدام'), findsOneWidget);
          }
          await tab(tester, BagScreen.itemsTabKey);
          expect(tester.takeException(), isNull, reason: language.name);
          if (isAr) expect(find.text('كل الأدوات'), findsOneWidget);
          // The first tile at the reading start: right in Arabic.
          final first = tester.getCenter(
            find.byKey(BagScreen.itemKey('bunny_royal')),
          );
          final second = tester.getCenter(
            find.byKey(BagScreen.itemKey('golden_stags')),
          );
          expect(first.dx > second.dx, isAr, reason: language.name);
          // The pills at the end: Use / Remove after Send.
          final send = tester.getCenter(find.byKey(BagScreen.sendKey));
          final use = tester.getCenter(find.byKey(BagScreen.useKey));
          expect(use.dx > send.dx, !isAr, reason: language.name);
          await select(tester, 'kabi_royal');
          expect(tester.takeException(), isNull, reason: language.name);
          await tester.scrollUntilVisible(
            find.byKey(BagScreen.itemKey('fire_frame')),
            200,
            scrollable: _list,
          );
          expect(tester.takeException(), isNull, reason: language.name);
          await tab(tester, BagScreen.toolsTabKey);
          expect(tester.takeException(), isNull, reason: language.name);
          await select(tester, 'golden_stags');
          await tester.tap(find.byKey(BagScreen.sendKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: language.name);
          expect(find.byType(BagSendSheet), findsOneWidget);
        }
      });
    });
  }

  testWidgets('your own profile opens the bag; nobody else has the tile', (
    tester,
  ) async {
    setViewport(tester, GoldenViewport.android);
    final fakes = await pumpBonds(
      tester,
      Scaffold(
        body: ProfileBondsBlock(
          levels: const SizedBox.shrink(),
          profile: apiProfile(isSelf: true),
        ),
      ),
    );
    expect(find.text(en.bagTitle), findsOneWidget);
    expect(find.text(en.bagTileValue), findsOneWidget);
    await tester.tap(find.byKey(ProfileBondsBlock.bagKey));
    await tester.pumpAndSettle();
    expect(fakes.visited, ['/bag']);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBonds(
      tester,
      Scaffold(
        body: ProfileBondsBlock(
          levels: const SizedBox.shrink(),
          profile: apiProfile(),
        ),
      ),
    );
    expect(find.byKey(ProfileBondsBlock.bagKey), findsNothing);
  });
}
