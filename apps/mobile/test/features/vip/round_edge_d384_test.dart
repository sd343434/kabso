// D384 (owner 2026-11-12: «الصورة الشخصية يكون لها حواف مستديرة غير
// مرئية»): the cut-out's invisible round edge, checked on real pixels — the
// old photo circle bounds the picture below its centre with a soft edge, the
// top stays open, nothing is painted where the circle is.

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:material_ui/material_ui.dart';

/// The alpha of the 100 × 100 red square under a [RoundEdge] of [feather].
Future<int Function(int x, int y)> _alpha(
  WidgetTester tester,
  double feather,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 100,
            height: 100,
            child: RoundEdge(
              circle: const Rect.fromLTWH(10, 10, 80, 80),
              feather: feather,
              child: const ColoredBox(color: Color(0xFFFF0000)),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync<ByteData?>(() async {
    final image = await boundary.toImage();
    try {
      return await image.toByteData();
    } finally {
      image.dispose();
    }
  }))!;
  int alpha(int x, int y) => data.getUint8((y * 100 + x) * 4 + 3);
  return alpha;
}

void main() {
  testWidgets('below the centre: only inside the circle; above: open', (
    tester,
  ) async {
    final a = await _alpha(tester, 0);
    // Inside the circle.
    expect(a(50, 50), 255);
    expect(a(50, 85), 255);
    // Outside the circle below its centre: erased (the shoulders' round end).
    expect(a(2, 98), 0);
    expect(a(97, 98), 0);
    expect(a(4, 70), 0);
    expect(a(50, 95), 0);
    // Above the centre: open, even outside the circle (the head and hair).
    expect(a(2, 2), 255);
    expect(a(97, 40), 255);
  });

  testWidgets('the edge is feathered, not a hard cut', (tester) async {
    final a = await _alpha(tester, VipCutoutMetrics.feather);
    expect(VipCutoutMetrics.feather, inInclusiveRange(4, 6));
    // Well inside and well outside as before.
    expect(a(50, 50), 255);
    expect(a(2, 98), 0);
    // Just inside the arc (bottom of the circle at y 90): partly transparent.
    expect(a(50, 88), inExclusiveRange(0, 255));
    expect(a(50, 92), inExclusiveRange(0, 255));
    expect(a(50, 88), greaterThan(a(50, 92)));
    // No ring or fill is drawn: the colour is only the child's.
  });
}
