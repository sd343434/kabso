// KL-033 component refactors: primary tabs, chips, compact states, badge
// additions and the bottom-nav styling.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/component_harness.dart';
import '../helpers/pump_app.dart';

void main() {
  group('KPrimaryTabs', () {
    Future<List<int>> pumpTabs(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
      int selected = 1,
    }) async {
      final taps = <int>[];
      await pumpComponent(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: KPrimaryTabs(
            labels: const ['Following', 'Popular', 'New'],
            selectedIndex: selected,
            onSelected: taps.add,
          ),
        ),
        language: language,
      );
      return taps;
    }

    testWidgets('selected: title 18/600 textPrimary + 16×3 primary '
        'indicator; unselected: bodyStrong textSecondary', (tester) async {
      await pumpTabs(tester);
      const p = KPalette.dark;
      final selected = DefaultTextStyle.of(tester.element(find.text('Popular')))
          .style;
      expect(selected.fontSize, KTypography.title.size);
      expect(selected.fontWeight, FontWeight.w600);
      expect(selected.color, p.textPrimary);
      final other = DefaultTextStyle.of(tester.element(find.text('Following')))
          .style;
      expect(other.fontSize, KTypography.bodyStrong.size);
      expect(other.color, p.textSecondary);

      final indicators = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .toList();
      expect(indicators.map((o) => o.opacity), [0, 1, 0]);
      final bar = find.descendant(
        of: find.byWidget(indicators[1]),
        matching: find.byType(Container),
      );
      expect(
        tester.getSize(bar),
        const Size(KMetrics.tabIndicatorWidth, KMetrics.tabIndicatorHeight),
      );
    });

    testWidgets('48 dp hit height, tap selects, marked for screen readers', (
      tester,
    ) async {
      final taps = await pumpTabs(tester);
      final tab = find.ancestor(
        of: find.text('New'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tab).height, KSizes.minTouchTarget);
      expect(
        tester.getSize(tab).width,
        greaterThanOrEqualTo(KSizes.minTouchTarget),
      );
      await tester.tap(find.text('New'));
      expect(taps, [2]);
      expect(
        tester.getSemantics(find.text('Popular')),
        isSemantics(
          label: 'Popular',
          isSelected: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
    });

    testWidgets('order follows the reading direction', (tester) async {
      await pumpTabs(tester);
      expect(
        tester.getCenter(find.text('Following')).dx,
        lessThan(tester.getCenter(find.text('Popular')).dx),
      );
      await pumpTabs(tester, language: AppLanguage.ar);
      expect(
        tester.getCenter(find.text('Following')).dx,
        greaterThan(tester.getCenter(find.text('Popular')).dx),
      );
    });

    testWidgets('large text keeps the 48 dp header without overflow', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Align(
              alignment: Alignment.topCenter,
              child: KPrimaryTabs(
                labels: const ['Following', 'Popular', 'New'],
                selectedIndex: 1,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(KPrimaryTabs)).height,
        KMetrics.topBarHeight,
      );
    });
  });

  group('KChip', () {
    testWidgets('32 dp visual in a 48 dp target; selected = primary fill', (
      tester,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Center(
          child: KChip(
            label: 'Music',
            selected: true,
            onSelected: () => taps++,
          ),
        ),
      );
      final visual = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        (visual.decoration! as BoxDecoration).color,
        KPalette.dark.primary,
      );
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 32);
      expect(tester.getSize(find.byType(InkWell)).height, 48);
      await tester.tap(find.text('Music'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.text('Music')),
        isSemantics(isSelected: true, isButton: true),
      );
    });

    testWidgets('unselected = surfaceRaised; no callback = not a button', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const Center(child: KChip(label: 'All', selected: false)),
      );
      final visual = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        (visual.decoration! as BoxDecoration).color,
        KPalette.dark.surfaceRaised,
      );
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester.getSemantics(find.text('All')),
        isNot(isSemantics(isButton: true)),
      );
    });
  });

  group('compact states (VG-03)', () {
    testWidgets('48 dp icon without a circle container', (tester) async {
      await pumpComponent(
        tester,
        const KEmptyState(
          compact: true,
          icon: Icons.sensors_outlined,
          title: 'T',
          message: 'M',
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.sensors_outlined));
      expect(icon.size, KMetrics.compactStateIcon);
      expect(icon.color, KPalette.dark.textSecondary);
      final circles = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle);
      expect(circles, isEmpty);
      expect(tester.getSemantics(find.text('T')), isSemantics(isHeader: true));
    });

    testWidgets('compact error uses the error tint and keeps Try again', (
      tester,
    ) async {
      var retries = 0;
      await pumpComponent(
        tester,
        KErrorState(
          compact: true,
          title: 'T',
          message: 'M',
          retryLabel: 'Try again',
          onRetry: () => retries++,
        ),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.error_outline_rounded),
      );
      expect(icon.color, KPalette.dark.error);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });

  group('KBadge additions', () {
    testWidgets('PK is solid (no gradient)', (tester) async {
      await pumpComponent(tester, const Center(child: KBadge.pk()));
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(KBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, KBadge.pkFill);
    });

    testWidgets('newRoom reads New / جديد', (tester) async {
      await pumpComponent(tester, const Center(child: KBadge.newRoom()));
      expect(find.bySemanticsLabel('New'), findsOneWidget);
      await pumpComponent(
        tester,
        const Center(child: KBadge.newRoom()),
        language: AppLanguage.ar,
      );
      expect(find.bySemanticsLabel('جديد'), findsOneWidget);
    });

    testWidgets('multiGuest shows the count; semantics use plurals', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const Center(child: KBadge.multiGuest(count: 4)),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.bySemanticsLabel('4 guests'), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      await pumpComponent(
        tester,
        const Center(child: KBadge.multiGuest(count: 2)),
        language: AppLanguage.ar,
      );
      expect(find.bySemanticsLabel('ضيفان'), findsOneWidget);
    });
  });

  group('KBottomNav (§2 styling)', () {
    Future<void> pumpNav(WidgetTester tester, int index) => pumpComponent(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: KBottomNav(
          items: shellNavItems(l10nFor(AppLanguage.en)),
          currentIndex: index,
          onSelect: (_) {},
        ),
      ),
    );

    testWidgets('active: filled icon, textPrimary label, primary dot; '
        'inactive: outline icon, textSecondary; no red labels', (tester) async {
      await pumpNav(tester, 0);
      const p = KPalette.dark;
      Color labelColor(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;
      expect(labelColor('Home'), p.textPrimary);
      for (final label in ['Discover', 'Live', 'Profile']) {
        expect(labelColor(label), p.textSecondary);
      }
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sensors_outlined), findsOneWidget);

      final dots = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((o) => o.opacity)
          .toList();
      expect(dots, [1, 0, 0, 0, 0]);
      final dot = find
          .descendant(
            of: find.byType(AnimatedOpacity).first,
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(dot), const Size.square(KMetrics.navDotSize));
      expect(
        (tester.widget<Container>(dot).decoration! as BoxDecoration).color,
        p.primary,
      );
    });

    testWidgets('Create keeps its label-less pill with a "Create" name', (
      tester,
    ) async {
      await pumpNav(tester, 2);
      expect(find.text('Create'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const Key('nav.create'))),
        isSemantics(label: 'Create', isSelected: true, isButton: true),
      );
    });
  });
}
