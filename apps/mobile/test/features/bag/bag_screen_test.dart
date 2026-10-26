// CP-019: the bag screen — owned profile cards with a preview, the worn one
// marked, Wear / Take off (PUT /me/bag/equipped), the error of
// BAG_ITEM_NOT_OWNED, the empty bag, locked catalogue items, the user's own
// profile reloaded after a change; Arabic and English at 360×800, text
// scale 2.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/bag_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bag_repository.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';

Future<({FakeBagRepository bag, FakeProfileRepository profiles})> _pump(
  WidgetTester tester, {
  List<String> owned = const ['bunny_royal', 'emerald_wings'],
  String? worn = 'bunny_royal',
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.android);
  final bag = FakeBagRepository(
    owned: owned,
    worn: worn,
    ar: language == AppLanguage.ar,
  );
  final profiles = FakeProfileRepository(apiProfile(isSelf: true));
  await pumpBonds(
    tester,
    const BagScreen(),
    language: language,
    overrides: [
      bagRepositoryProvider.overrideWithValue(bag),
      profileRepositoryProvider.overrideWithValue(profiles),
    ],
  );
  return (bag: bag, profiles: profiles);
}

Finder _in(String code, Finder finder) => find.descendant(
  of: find.byKey(BagCategoryView.itemKey(code)),
  matching: finder,
);

/// The bag's list (not the tab bar or the pages).
final Finder _list = find
    .descendant(
      of: find.byType(BagCategoryView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('owned cards with previews, the worn one marked, locked rest', (
    tester,
  ) async {
    final f = await _pump(tester);
    expect(f.bag.calls, containsAll(['catalogue', 'myBag']));
    expect(find.text(en.bagTitle), findsOneWidget);
    expect(
      find.byKey(BagScreen.tabKey(BagCategory.profileCard)),
      findsOneWidget,
    );
    expect(find.text(en.bagCategoryProfileCard), findsOneWidget);
    expect(find.byKey(BagCategoryView.ownedKey), findsOneWidget);

    // Owned: the preview of each header, the name; the worn one marked.
    expect(_in('bunny_royal', find.text('Royal Bunny')), findsOneWidget);
    expect(
      _in('bunny_royal', find.byType(KabsoProfileHeaderArt)),
      findsOneWidget,
    );
    expect(find.byKey(BagCategoryView.wornKey('bunny_royal')), findsOneWidget);
    expect(find.text(en.bagWorn), findsOneWidget);
    expect(
      find.byKey(BagCategoryView.takeOffKey('bunny_royal')),
      findsOneWidget,
    );
    expect(
      find.byKey(BagCategoryView.wearKey('emerald_wings')),
      findsOneWidget,
    );
    expect(find.byKey(BagCategoryView.wornKey('emerald_wings')), findsNothing);
    final art = tester.widget<KabsoProfileHeaderArt>(
      _in('emerald_wings', find.byType(KabsoProfileHeaderArt)),
    );
    expect(art.header, KabsoProfileHeader.emeraldWings);

    // Not owned: greyed with "Not owned yet", no action.
    await tester.scrollUntilVisible(
      find.byKey(BagCategoryView.itemKey('golden_stags')),
      200,
      scrollable: _list,
    );
    expect(find.byKey(BagCategoryView.lockedSectionKey), findsOneWidget);
    for (final code in ['kabi_royal', 'golden_stags']) {
      expect(find.byKey(BagCategoryView.lockedKey(code)), findsOneWidget);
      expect(_in(code, find.byType(ColorFiltered)), findsOneWidget);
      expect(_in(code, find.byType(FilledButton)), findsNothing);
      expect(_in(code, find.byType(OutlinedButton)), findsNothing);
    }
    expect(find.text(en.bagLocked), findsNWidgets(2));
    expect(
      find.byKey(BagCategoryView.lockedKey('emerald_wings')),
      findsNothing,
    );
  });

  testWidgets('Wear: PUT the code, the badge moves, the profile reloads', (
    tester,
  ) async {
    final f = await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagScreen)),
    );
    final sub = container.listen(profileStatsProvider('host0'), (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    final gets = f.profiles.calls.length;

    await tester.tap(find.byKey(BagCategoryView.wearKey('emerald_wings')));
    await tester.pumpAndSettle();
    expect(f.bag.calls, contains('setEquipped:emerald_wings'));
    expect(
      find.byKey(BagCategoryView.wornKey('emerald_wings')),
      findsOneWidget,
    );
    expect(find.byKey(BagCategoryView.wornKey('bunny_royal')), findsNothing);
    expect(find.byKey(BagCategoryView.wearKey('bunny_royal')), findsOneWidget);
    expect(
      find.byKey(BagCategoryView.takeOffKey('emerald_wings')),
      findsOneWidget,
    );
    // The bag reloaded, and the user's own profile (their card) too.
    expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
    expect(f.profiles.calls.length, greaterThan(gets));
  });

  testWidgets('Take off: PUT null, nothing worn', (tester) async {
    final f = await _pump(tester);
    await tester.tap(find.byKey(BagCategoryView.takeOffKey('bunny_royal')));
    await tester.pumpAndSettle();
    expect(f.bag.calls, contains('setEquipped:null'));
    expect(f.bag.worn, isNull);
    expect(find.text(en.bagWorn), findsNothing);
    expect(find.byKey(BagCategoryView.wearKey('bunny_royal')), findsOneWidget);
    expect(
      find.byKey(BagCategoryView.wearKey('emerald_wings')),
      findsOneWidget,
    );
  });

  testWidgets('BAG_ITEM_NOT_OWNED: its message, the bag reloads, no change', (
    tester,
  ) async {
    final f = await _pump(tester);
    f.bag.failNext['setEquipped'] = bondFailure(ErrorCode.bagItemNotOwned);
    await tester.tap(find.byKey(BagCategoryView.wearKey('emerald_wings')));
    await tester.pumpAndSettle();
    expect(find.text(en.errorBagItemNotOwned), findsOneWidget);
    expect(f.bag.calls.where((c) => c == 'myBag'), hasLength(2));
    expect(find.byKey(BagCategoryView.wornKey('bunny_royal')), findsOneWidget);
    expect(find.byKey(BagCategoryView.wornKey('emerald_wings')), findsNothing);
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
    expect(find.byKey(BagCategoryView.itemKey('bunny_royal')), findsOneWidget);
  });

  testWidgets('owning nothing: the empty state, the catalogue locked', (
    tester,
  ) async {
    await _pump(tester, owned: const [], worn: null);
    expect(find.byKey(BagCategoryView.emptyKey), findsOneWidget);
    expect(find.text(en.bagEmptyTitle), findsOneWidget);
    expect(find.byKey(BagCategoryView.ownedKey), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      find.byKey(BagCategoryView.lockedKey('bunny_royal')),
      findsOneWidget,
    );
  });

  testWidgets('Arabic (RTL) and English at 360×800, text scale 2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull, reason: language.name);
      final l10n = language == AppLanguage.ar ? ar : en;
      expect(find.text(l10n.bagTitle), findsOneWidget);
      expect(
        find.text(bagItemName('bunny_royal', ar: language == AppLanguage.ar)),
        findsOneWidget,
      );
      // The first item at the reading start.
      final first = tester.getCenter(
        find.byKey(BagCategoryView.itemKey('bunny_royal')),
      );
      final second = tester.getCenter(
        find.byKey(BagCategoryView.itemKey('emerald_wings')),
      );
      expect(first.dx < second.dx, language == AppLanguage.en);
      await tester.scrollUntilVisible(
        find.byKey(BagCategoryView.itemKey('golden_stags')),
        200,
        scrollable: _list,
      );
      expect(tester.takeException(), isNull, reason: language.name);
    }
  });

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
