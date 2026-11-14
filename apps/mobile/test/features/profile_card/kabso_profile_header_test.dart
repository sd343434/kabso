import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('each ornament rises to its bar on a 750 × 280 canvas', () {
    expect(
      KabsoProfileHeader.emeraldWings.overhang(750),
      closeTo(280 * 0.834, 0.001),
    );
    // The owner: y = 230 of 280 for the others.
    for (final h in [
      KabsoProfileHeader.bunnyRoyal,
      KabsoProfileHeader.kabiRoyal,
      KabsoProfileHeader.goldenStags,
    ]) {
      expect(h.overhang(750), closeTo(230, 0.001), reason: h.code);
    }
  });

  test('headers are found by their bag code', () {
    expect(
      KabsoProfileHeader.byCode('bunny_royal'),
      KabsoProfileHeader.bunnyRoyal,
    );
    expect(KabsoProfileHeader.byCode('unknown'), isNull);
    expect(KabsoProfileHeader.byCode(null), isNull);
  });

  testWidgets('tests draw the still, its bar on the given line, and it '
      'never takes taps', (tester) async {
    const width = 360.0;
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              child: KabsoProfileHeaderArt(
                KabsoProfileHeader.emeraldWings,
                width: width,
              ),
            ),
          ],
        ),
      ),
    );
    const header = KabsoProfileHeader.emeraldWings;
    final still = find.image(AssetImage(header.still!.asset));
    expect(still, findsOneWidget);
    final rect = tester.getRect(still);
    expect(rect.width, width);
    // The still's bar lies on the card's edge line.
    expect(
      rect.top + rect.height * header.still!.bar,
      closeTo(header.overhang(width), 0.01),
    );
    await tester.tapAt(rect.center);
    expect(taps, 1);
  });
}
