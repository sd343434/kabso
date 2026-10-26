import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the ornament rises 83.4 % of its 750 × 280 canvas', () {
    expect(KabsoProfileHeader.overhang(750), closeTo(280 * 0.834, 0.001));
    expect(
      KabsoProfileHeader.overhang(360),
      closeTo(360 * 280 / 750 * 0.834, 0.001),
    );
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
    final still = find.image(AssetImage(header.still));
    expect(still, findsOneWidget);
    final rect = tester.getRect(still);
    expect(rect.width, width);
    // The still's bar lies on the card's edge line.
    expect(
      rect.top + rect.height * header.stillBar,
      closeTo(KabsoProfileHeader.overhang(width), 0.01),
    );
    await tester.tapAt(rect.center);
    expect(taps, 1);
  });
}
