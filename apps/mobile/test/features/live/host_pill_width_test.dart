// QA-009: at 360 dp the host name in the live room header must keep at
// least ~8 visible characters (real fonts, both locales).

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';

import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/golden.dart';

void main() {
  for (final viewport in GoldenViewport.values) {
    for (final (language, host) in const [
      (AppLanguage.en, 'Abdullah'),
      (AppLanguage.ar, 'عبدالرحمن'),
    ]) {
      testWidgets('${language.name} ${viewport.name}: "$host" is not '
          'truncated; close keeps 48 dp', (tester) async {
        await pumpGolden(
          tester,
          KLiveRoomScaffold(
            header: KHostPill(hostName: host, onFollow: () {}),
            viewers: const KViewerStrip(names: viewerNames, count: 12345),
            onClose: () {},
            chat: KLiveChatOverlay(lines: chatLines(language)),
            actionBar: const KRoomActionBar(),
          ),
          language: language,
          viewport: viewport,
          bare: true,
        );
        final paragraph = tester.renderObject<RenderParagraph>(find.text(host));
        expect(paragraph.didExceedMaxLines, isFalse, reason: host);
        expect(find.byType(KViewerCountChip), findsOneWidget);
        final close = tester.getSize(
          find.bySemanticsLabel(RegExp(r'^(Close|إغلاق)$')),
        );
        expect(close.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
        expect(close.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
      });
    }
  }
}
