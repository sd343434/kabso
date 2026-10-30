// CP-019 / D171: the bag screen — only owned items (never the catalogue),
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
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bag_repository.dart';
import '../../helpers/fake_bonds_repositories.dart';
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
/// @sara_22 that ends at 14:00 today, a permanent level reward and a frame
/// of a category this app does not know yet (D169's AVATAR_FRAME).
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
    category: 'AVATAR_FRAME',
    source: 'LEVEL_REWARD',
    transferable: false,
  ),
];

typedef _Fakes = ({
  FakeBagRepository bag,
  FakeProfileRepository profiles,
  FakePostsRepository posts,
});

Future<_Fakes> _pump(
  WidgetTester tester, {
  List<Map<String, Object?>>? items,
  String? worn = 'bunny_royal',
  AppLanguage language = AppLanguage.en,
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
  await pumpBonds(
    tester,
    const BagScreen(),
    language: language,
    overrides: [
      bagRepositoryProvider.overrideWithValue(bag),
      profileRepositoryProvider.overrideWithValue(profiles),
      postsRepositoryProvider.overrideWithValue(posts),
    ],
  );
  return (bag: bag, profiles: profiles, posts: posts);
}

Finder _in(String code, Finder finder) =>
    find.descendant(of: find.byKey(BagScreen.itemKey(code)), matching: finder);

Finder get _list => find.byType(Scrollable).first;

Text _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key));

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('only owned items, by category, with source and time left', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      // The catalogue is never asked: items not owned are not shown.
      expect(f.bag.calls, ['myBag']);
      expect(find.text(en.bagTitle), findsOneWidget);
      expect(find.byKey(BagScreen.sectionKey('PROFILE_CARD')), findsOneWidget);
      expect(find.text(en.bagCategoryProfileCard), findsOneWidget);

      // The free card: «Gift from Kabso», permanent, worn, not sendable.
      expect(_in('bunny_royal', find.text('Royal Bunny')), findsOneWidget);
      expect(
        _in('bunny_royal', find.byType(KabsoProfileHeaderArt)),
        findsOneWidget,
      );
      expect(
        _text(tester, BagScreen.sourceKey('bunny_royal')).data,
        en.bagFromKabso,
      );
      expect(
        _text(tester, BagScreen.timeKey('bunny_royal')).data,
        en.bagPermanent,
      );
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsOneWidget);
      expect(find.byKey(BagScreen.takeOffKey('bunny_royal')), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(BagScreen.sendKey('bunny_royal')),
            )
            .onPressed,
        isNull,
      );
      expect(
        _text(tester, BagScreen.noSendKey('bunny_royal')).data,
        en.bagNoSendFree,
      );

      // 6 days 4 hours left; sendable.
      expect(
        _text(tester, BagScreen.timeKey('golden_stags')).data,
        '6 days 4 hours left',
      );
      expect(find.byKey(BagScreen.wearKey('golden_stags')), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(BagScreen.sendKey('golden_stags')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.byKey(BagScreen.noSendKey('golden_stags')), findsNothing);

      // A gift from @sara_22 that ends at 14:00 today.
      expect(
        _text(tester, BagScreen.sourceKey('emerald_wings')).data,
        'Gift from @sara_22',
      );
      expect(
        _text(tester, BagScreen.timeKey('emerald_wings')).data,
        en.bagEndsToday,
      );

      // A level reward: permanent, wearable, not sendable (with why).
      await tester.scrollUntilVisible(
        find.byKey(BagScreen.itemKey('fire_frame')),
        200,
        scrollable: _list,
      );
      expect(
        _text(tester, BagScreen.sourceKey('kabi_royal')).data,
        en.bagFromLevel,
      );
      expect(
        _text(tester, BagScreen.noSendKey('kabi_royal')).data,
        en.bagNoSendLevel,
      );
      expect(find.byKey(BagScreen.wearKey('kabi_royal')), findsOneWidget);

      // A category this app does not know yet still shows, as «Other items».
      expect(find.byKey(BagScreen.sectionKey('AVATAR_FRAME')), findsOneWidget);
      expect(find.text(en.bagCategoryOther), findsOneWidget);
      expect(find.byKey(BagScreen.wearKey('fire_frame')), findsOneWidget);
      expect(
        _text(tester, BagScreen.noSendKey('fire_frame')).data,
        en.bagNoSendLevel,
      );
    });
  });

  test('time left in Arabic and English', () {
    final now = DateTime(2026, 10, 30, 9);
    String left(Duration d, {bool arabic = true}) =>
        bagTimeLeft(arabic ? ar : en, now.add(d), now);
    expect(left(const Duration(days: 6, hours: 4)), 'متبقٍ 6 أيام 4 ساعات');
    expect(left(const Duration(days: 1)), 'متبقٍ يوم واحد');
    expect(left(const Duration(days: 2, hours: 1)), 'متبقٍ يومان ساعة واحدة');
    expect(left(const Duration(hours: 5)), 'ينتهي اليوم');
    // After midnight: hours, not «today».
    expect(left(const Duration(hours: 16)), 'متبقٍ 16 ساعة');
    expect(left(const Duration(minutes: 12)), 'متبقٍ 12 دقيقة');
    expect(bagTimeLeft(ar, null, now), 'دائم');
    expect(left(const Duration(hours: 3), arabic: false), 'Ends today');
    expect(left(const Duration(minutes: 1), arabic: false), '1 minute left');
  });

  testWidgets('Wear: PUT the code, the badge moves, the profile reloads', (
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

      await tester.tap(find.byKey(BagScreen.wearKey('golden_stags')));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('setEquipped:golden_stags'));
      expect(find.byKey(BagScreen.wornKey('golden_stags')), findsOneWidget);
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsNothing);
      expect(find.byKey(BagScreen.wearKey('bunny_royal')), findsOneWidget);
      expect(find.byKey(BagScreen.takeOffKey('golden_stags')), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
      expect(f.profiles.calls.length, greaterThan(gets));
    });
  });

  testWidgets('Remove («إزالة»): PUT null, nothing worn', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      expect(find.text(en.bagTakeOff), findsOneWidget);
      await tester.tap(find.byKey(BagScreen.takeOffKey('bunny_royal')));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('setEquipped:null'));
      expect(f.bag.worn, isNull);
      expect(find.text(en.bagWorn), findsNothing);
      expect(find.byKey(BagScreen.wearKey('bunny_royal')), findsOneWidget);
    });
  });

  testWidgets('BAG_ITEM_NOT_OWNED: its message, the bag reloads', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      f.bag.failNext['setEquipped'] = bondFailure(ErrorCode.bagItemNotOwned);
      await tester.tap(find.byKey(BagScreen.wearKey('golden_stags')));
      await tester.pumpAndSettle();
      expect(find.text(en.errorBagItemNotOwned), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
      expect(find.byKey(BagScreen.wornKey('bunny_royal')), findsOneWidget);
    });
  });

  testWidgets('send some days: the sheet, the person, the confirmation', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      await tester.tap(find.byKey(BagScreen.sendKey('golden_stags')));
      await tester.pumpAndSettle();
      expect(find.byType(BagSendSheet), findsOneWidget);
      expect(
        _text(tester, BagSendSheet.haveKey).data,
        'You have: 6 days 4 hours',
      );
      // Whole days below what is left, and «All».
      for (final d in [1, 3, 6]) {
        expect(find.byKey(BagSendSheet.daysKey(d)), findsOneWidget);
      }
      expect(find.byKey(BagSendSheet.daysKey(7)), findsNothing);
      expect(find.byKey(BagSendSheet.allKey), findsOneWidget);
      expect(_text(tester, BagSendSheet.noteKey).data, en.bagSendWholeNote);
      await tester.tap(find.byKey(BagSendSheet.daysKey(3)));
      await tester.pump();
      expect(
        _text(tester, BagSendSheet.noteKey).data,
        'You keep: 3 days 4 hours',
      );
      // Nobody chosen yet: Send is off.
      expect(
        tester
            .widget<FilledButton>(find.byKey(BagSendSheet.submitKey))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(BagSendSheet.fieldKey), '@sa');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(f.posts.calls, contains('searchUsers:sa'));
      await tester.tap(find.byKey(BagSendSheet.personKey('sara_22')));
      await tester.pumpAndSettle();
      expect(find.byKey(BagSendSheet.changeKey), findsOneWidget);
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      // The confirmation names the item, the amount and the person.
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
      expect(find.byType(BagSendSheet), findsNothing);
      expect(find.text('Sent to @sara_22'), findsOneWidget);
      expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
    });
  });

  testWidgets('send all; cancelling the confirmation sends nothing', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      await tester.tap(find.byKey(BagScreen.sendKey('emerald_wings')));
      await tester.pumpAndSettle();
      // 5 hours left: no whole day to split, only «All».
      expect(find.byKey(BagSendSheet.daysKey(1)), findsNothing);
      await tester.enterText(find.byKey(BagSendSheet.fieldKey), 'sara');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.personKey('sara_22')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.actionCancel));
      await tester.pumpAndSettle();
      expect(f.bag.calls.where((c) => c.startsWith('send')), isEmpty);
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(f.bag.calls, contains('send:emerald_wings:sara_22:all'));
      expect(find.byKey(BagScreen.itemKey('emerald_wings')), findsNothing);
    });
  });

  testWidgets('a refused send stays in the sheet with the reason', (
    tester,
  ) async {
    await withClock(Clock.fixed(_now), () async {
      final f = await _pump(tester);
      f.bag.failNext['send'] = bondFailure(ErrorCode.bagRecipientHasPermanent);
      await tester.tap(find.byKey(BagScreen.sendKey('golden_stags')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(BagSendSheet.fieldKey), 'sa');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.personKey('sara_22')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BagSendSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(find.byType(BagSendSheet), findsOneWidget);
      expect(
        _text(tester, BagSendSheet.errorKey).data,
        en.errorBagRecipientHasPermanent,
      );
    });
  });

  testWidgets('a permanent sendable item goes whole only', (tester) async {
    await withClock(Clock.fixed(_now), () async {
      await _pump(
        tester,
        items: [bagItemJson('golden_stags', ar: false)],
        worn: null,
      );
      await tester.tap(find.byKey(BagScreen.sendKey('golden_stags')));
      await tester.pumpAndSettle();
      expect(_text(tester, BagSendSheet.haveKey).data, 'You have: Permanent');
      expect(find.byKey(BagSendSheet.daysKey(1)), findsNothing);
      expect(find.byKey(BagSendSheet.allKey), findsOneWidget);
      expect(_text(tester, BagSendSheet.noteKey).data, en.bagSendPermanentNote);
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
      expect(
        _text(tester, BagScreen.timeKey('golden_stags')).data,
        '2 minutes left',
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
    expect(find.byKey(BagScreen.itemKey('bunny_royal')), findsOneWidget);
  });

  testWidgets('owning nothing: the empty state, no other item', (tester) async {
    final f = await _pump(tester, items: const [], worn: null);
    expect(find.byKey(BagScreen.emptyKey), findsOneWidget);
    expect(find.text(en.bagEmptyTitle), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(f.bag.calls, ['myBag']);
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
          expect(find.text(l10n.bagTitle), findsOneWidget);
          expect(
            find.text(bagItemName('bunny_royal', ar: isAr)),
            findsOneWidget,
          );
          // The preview sits at the reading start: right in Arabic.
          final card = tester.getRect(
            find.byKey(BagScreen.itemKey('bunny_royal')),
          );
          final art = tester.getCenter(
            _in('bunny_royal', find.byType(ProfileCardPreview)),
          );
          expect(art.dx > card.center.dx, isAr, reason: language.name);
          // Wear / Remove beside Send.
          final wear = tester.getCenter(
            find.byKey(BagScreen.takeOffKey('bunny_royal')),
          );
          final send = tester.getCenter(
            find.byKey(BagScreen.sendKey('bunny_royal')),
          );
          expect((wear.dy - send.dy).abs() < 1, isTrue);
          expect(wear.dx > send.dx, isAr);
          if (isAr) {
            expect(find.text('إزالة'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.byKey(BagScreen.timeKey('golden_stags')),
              200,
              scrollable: _list,
            );
            expect(
              _text(tester, BagScreen.timeKey('golden_stags')).data,
              'متبقٍ 6 أيام 4 ساعات',
            );
            await tester.scrollUntilVisible(
              find.byKey(BagScreen.sourceKey('emerald_wings')),
              200,
              scrollable: _list,
            );
            expect(
              _text(tester, BagScreen.sourceKey('emerald_wings')).data,
              contains('هدية من'),
            );
            expect(find.text('ارتداء'), findsWidgets);
            expect(find.text('إرسال'), findsWidgets);
          }
          await tester.scrollUntilVisible(
            find.byKey(BagScreen.itemKey('fire_frame')),
            200,
            scrollable: _list,
          );
          expect(tester.takeException(), isNull, reason: language.name);
          // The send sheet too.
          await tester.scrollUntilVisible(
            find.byKey(BagScreen.sendKey('golden_stags')),
            -200,
            scrollable: _list,
          );
          await tester.tap(find.byKey(BagScreen.sendKey('golden_stags')));
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
