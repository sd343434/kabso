// D233 «صواريخ الزيارات» goldens (owner 2026-11-01: the visit card becomes
// a 4-stage rocket, coins only, a distinct rocket per stage and an animated
// «مميز» frame on the hub; Kabso-drawn art, test fixtures only):
// - the purchase sheet: ar and en, 393×852 dark and light, 360×800 at text
//   scale 1.3;
// - hub cards with stages 1–4 running (the frame held still: goldens run with
//   animations disabled), the same variants.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_visit_rocket_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_boost_sheet.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_boost_repository.dart';
import '../helpers/golden.dart';

typedef _Variant = ({
  String name,
  GoldenViewport viewport,
  Brightness brightness,
  double textScale,
});

const List<_Variant> _variants = [
  (
    name: 'dark',
    viewport: GoldenViewport.phone,
    brightness: Brightness.dark,
    textScale: 1,
  ),
  (
    name: 'light',
    viewport: GoldenViewport.phone,
    brightness: Brightness.light,
    textScale: 1,
  ),
  (
    name: 'text13',
    viewport: GoldenViewport.android,
    brightness: Brightness.dark,
    textScale: 1.3,
  ),
];

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Future<void> _pumpSheet(
  WidgetTester tester,
  AppLanguage language,
  _Variant v,
) async {
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        liveBoostRepositoryProvider.overrideWithValue(
          FakeLiveBoostRepository(),
        ),
      ],
      child: _scaled(
        v.textScale,
        ColoredBox(
          // The dimmed live behind the sheet (a plain stand-in).
          color: const Color(0xFF3B3346),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F1D24),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: const LiveBoostSheet(roomId: 'room-0'),
            ),
          ),
        ),
      ),
    ),
    language: language,
    viewport: v.viewport,
    brightness: v.brightness,
    bare: true,
  );
  await tester.pumpAndSettle();
}

const _titles = ['Night chat', 'سهرة طرب', 'Quiz time', 'PK الليلة'];
const _hosts = ['Lina', 'عمر', 'Sami', 'نور'];

Future<void> _pumpCards(
  WidgetTester tester,
  AppLanguage language,
  _Variant v,
) async {
  Widget card(int i) => AspectRatio(
    aspectRatio: KLiveGrid.cardAspect,
    child: KLiveGridCard(
      room: LiveRoomCardData(
        hostName: _hosts[i],
        title: _titles[i],
        viewerCount: [12, 340, 2100, 9800][i],
        roomId: 'r$i',
        featured: true,
        boostStage: i + 1,
        inPk: i == 3,
      ),
      onTap: () {},
    ),
  );
  await pumpGolden(
    tester,
    _scaled(
      v.textScale,
      SingleChildScrollView(
        child: Column(
          children: [
            for (final row in [0, 2]) ...[
              if (row > 0) const SizedBox(height: KLiveGrid.rowGap),
              Row(
                children: [
                  Expanded(child: card(row)),
                  const SizedBox(width: KLiveGrid.gap),
                  Expanded(child: card(row + 1)),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    language: language,
    viewport: v.viewport,
    brightness: v.brightness,
    padding: const EdgeInsets.symmetric(
      horizontal: KLiveGrid.inset,
      vertical: KLiveGrid.inset,
    ),
  );
}

void main() {
  forEachLanguage((language) {
    for (final v in _variants) {
      testWidgets('visit rocket sheet ${v.name} (${language.name})', (
        tester,
      ) async {
        await _pumpSheet(tester, language, v);
        await expectScreenGolden(
          'live_visit_rocket_sheet_${v.name}',
          language: language,
          viewport: v.viewport,
        );
      });
      testWidgets('visit rocket hub cards ${v.name} (${language.name})', (
        tester,
      ) async {
        await _pumpCards(tester, language, v);
        await expectScreenGolden(
          'live_visit_rocket_cards_${v.name}',
          language: language,
          viewport: v.viewport,
        );
      });
    }
  });
}
