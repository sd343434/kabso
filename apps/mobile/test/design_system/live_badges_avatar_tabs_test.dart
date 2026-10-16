import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_fixtures.dart';
import '../helpers/component_harness.dart';

void main() {
  group('KBadge', () {
    testWidgets('live badge reads LIVE / مباشر', (tester) async {
      await pumpComponent(tester, const Center(child: KBadge.live()));
      expect(find.bySemanticsLabel('LIVE'), findsOneWidget);
      expect(tester.getSize(find.byType(KBadge)).height, KMetrics.badgeHeight);

      await pumpComponent(
        tester,
        const Center(child: KBadge.live()),
        language: AppLanguage.ar,
      );
      expect(find.bySemanticsLabel('مباشر'), findsOneWidget);
    });

    testWidgets('PK badge reads PK in both locales', (tester) async {
      for (final language in AppLanguage.values) {
        await pumpComponent(
          tester,
          const Center(child: KBadge.pk()),
          language: language,
        );
        expect(find.bySemanticsLabel('PK'), findsOneWidget);
      }
    });
  });

  group('KViewerCountChip', () {
    testWidgets('compact text, exact number for screen readers', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const Center(child: KViewerCountChip(count: 12345)),
      );
      expect(find.text('12.3K'), findsOneWidget);
      expect(find.bySemanticsLabel('12,345 viewers'), findsOneWidget);

      await pumpComponent(
        tester,
        const Center(child: KViewerCountChip(count: 12345)),
        language: AppLanguage.ar,
      );
      expect(find.text('12.3 ألف'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('12,345')), findsOneWidget);
    });

    testWidgets('singular in English', (tester) async {
      await pumpComponent(
        tester,
        const Center(child: KViewerCountChip(count: 1)),
      );
      expect(find.bySemanticsLabel('1 viewer'), findsOneWidget);
    });
  });

  group('KAvatar rings', () {
    test('outer size = image + 2 × (stroke + gap) (DESIGN_SYSTEM §9.4)', () {
      expect(const KAvatar(name: 'a').outerSize, KSizes.avatarMd);
      expect(
        const KAvatar(
          name: 'a',
          size: KSizes.avatarSm,
          ring: KAvatarRing.live,
        ).outerSize,
        KSizes.avatarSm + 2 * (2 + 2),
      );
      expect(
        const KAvatar(
          name: 'a',
          size: KSizes.avatarLg,
          ring: KAvatarRing.storyUnseen,
        ).outerSize,
        KSizes.avatarLg + 2 * (3 + 3),
      );
      for (final ring in [
        KAvatarRing.storyUnseen,
        KAvatarRing.storySeen,
        KAvatarRing.live,
      ]) {
        expect(
          KAvatar.story(name: 'a', ring: ring).outerSize,
          KSizes.storyRing,
          reason: '$ring',
        );
      }
    });

    testWidgets('ring adds a semantics suffix', (tester) async {
      for (final (ring, suffix) in const [
        (KAvatarRing.storyUnseen, 'has new story'),
        (KAvatarRing.storySeen, 'story viewed'),
        (KAvatarRing.live, 'live now'),
      ]) {
        await pumpComponent(
          tester,
          Center(
            child: KAvatar(name: 'Sara', ring: ring),
          ),
        );
        expect(find.bySemanticsLabel('Sara, $suffix'), findsOneWidget);
      }
      await pumpComponent(
        tester,
        const Center(
          child: KAvatar(name: 'سارة', ring: KAvatarRing.live),
        ),
        language: AppLanguage.ar,
      );
      expect(find.bySemanticsLabel('سارة, يبث مباشرة الآن'), findsOneWidget);
    });

    testWidgets('live ring shows the LIVE badge from md up, not on sm', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const Center(
          child: KAvatar(name: 'a', ring: KAvatarRing.live),
        ),
      );
      expect(find.byType(KBadge), findsOneWidget);

      await pumpComponent(
        tester,
        const Center(
          child: KAvatar(
            name: 'a',
            size: KSizes.avatarSm,
            ring: KAvatarRing.live,
          ),
        ),
      );
      expect(find.byType(KBadge), findsNothing);
    });
  });

  group('KScrollableTabs', () {
    Future<List<int>> pumpTabs(
      WidgetTester tester,
      AppLanguage language, {
      int selected = 0,
    }) async {
      final taps = <int>[];
      await pumpComponent(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: KScrollableTabs(
            labels: categories(language),
            selectedIndex: selected,
            onSelected: taps.add,
          ),
        ),
        language: language,
      );
      return taps;
    }

    testWidgets('tap selects; hit height 48, min width 72', (tester) async {
      final taps = await pumpTabs(tester, AppLanguage.en);
      await tester.tap(find.text('Music'));
      expect(taps, [2]);
      final tab = find.ancestor(
        of: find.text('All'),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(tab);
      expect(size.height, KSizes.minTouchTarget);
      expect(size.width, greaterThanOrEqualTo(KMetrics.tabMinWidth));
    });

    testWidgets('selected tab is marked for screen readers', (tester) async {
      await pumpTabs(tester, AppLanguage.en, selected: 1);
      expect(
        tester.getSemantics(find.text('Nearby')),
        isSemantics(
          label: 'Nearby',
          isSelected: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('order follows the reading direction', (tester) async {
      await pumpTabs(tester, AppLanguage.en);
      expect(
        tester.getCenter(find.text('All')).dx,
        lessThan(tester.getCenter(find.text('Nearby')).dx),
      );
      await pumpTabs(tester, AppLanguage.ar);
      expect(
        tester.getCenter(find.text('الكل')).dx,
        greaterThan(tester.getCenter(find.text('قريب')).dx),
      );
    });
  });
}
