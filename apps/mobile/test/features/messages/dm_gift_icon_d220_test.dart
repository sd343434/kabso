// D220 (owner: «صندوق الهدايا اجعله نفس الايقونة الاساسية وحتى في الرسائل نفس
// الايقونة»): the conversation's gift button shows the app's main gift icon,
// the live bar's colourful box (`assets/live_bar/bar_gift.png`) inside a
// circle, and still
// opens the gifts; a 48 dp target.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('the composer gift button: the main gift art, same behaviour', (
    tester,
  ) async {
    var opened = 0;
    await pumpScreen(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: TextEditingController(),
            onSend: () {},
            onGift: () => opened++,
            giftKey: const Key('gift'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gift = find.byKey(const Key('gift'));
    final art = tester.widget<KabsoArtIcon>(
      find.descendant(of: gift, matching: find.byType(KabsoArtIcon)),
    );
    expect(art.art, KabsoArt.mainGift);
    // Owner: inside a circle, like the "+" beside it.
    final button = tester.widget<IconButton>(gift);
    expect(button.style!.shape!.resolve({}), isA<CircleBorder>());
    final ratio =
        tester.getSize(find.byType(KabsoArtIcon)).width /
        tester.getSize(gift).width;
    expect(ratio, inInclusiveRange(0.58, 0.68));
    expect(KabsoArt.mainGift.asset, 'assets/live_bar/bar_gift.png');
    expect(
      find.descendant(
        of: gift,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/live_bar/bar_gift.png',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(gift);
    await tester.pump();
    expect(opened, 1);
  });
}
