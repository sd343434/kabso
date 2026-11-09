// D347 goldens (owner, 2026-11-09: «شريط المردود يظهر في كل لايفات للشريط
// x250 / x500 / x1000», CONVENTIONS §10.146): the global lucky banner in
// another live, on the real effects layer (LiveGiftEffectsLayer), from a
// `lucky-ticker` message as the server sends it (parsed by the app), still
// (reduced motion: the banner at rest). 393×852 @3x; Arabic light and dark,
// English dark, and the ×250 tier.
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/lucky_global_banner_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_gift_repository.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Map<String, Object?> _message(int multiplier, {required bool ar}) => {
  'type': 'lucky-ticker',
  'win': {
    'giftId': 'g-$multiplier',
    'roomId': 'room-b',
    'giftCode': 'lucky_clover',
    'sender': {
      'id': 'u-oz',
      'username': 'oz',
      'displayName': ar ? 'عز النابلسي' : 'Oz Nabulsi',
      'avatarUrl': null,
    },
    'multiplier': multiplier,
    'coinsWon': multiplier * 100,
    'createdAt': '2026-11-09T12:00:00.000Z',
  },
  'gift': {
    'code': 'lucky_clover',
    'assetKey': 'gift_lucky_clover',
    'imageUrl': null,
  },
  'room': {
    'id': 'room-b',
    'title': ar ? 'سهرة الجمعة مع سارة' : 'Friday night with Sara',
    'mode': 'AUDIO',
    'host': {
      'id': 'u-sara',
      'username': 'sara',
      'displayName': ar ? 'سارة' : 'Sara',
      'avatarUrl': null,
    },
  },
};

/// A stand-in for the live's picture behind the layer (light: a bright
/// video; dark: a night audio room).
Widget _backdrop(Brightness brightness) => DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: brightness == Brightness.light
          ? const [Color(0xFFFCE7D6), Color(0xFFF4B9B2), Color(0xFFE59AA8)]
          : const [Color(0xFF1B1036), Color(0xFF3A1E6E), Color(0xFF120A24)],
    ),
  ),
);

void main() {
  for (final (language, brightness, multiplier) in const [
    (AppLanguage.ar, Brightness.light, 500),
    (AppLanguage.ar, Brightness.dark, 500),
    (AppLanguage.en, Brightness.dark, 1000),
    (AppLanguage.ar, Brightness.dark, 250),
  ]) {
    final name =
        'lucky_global_banner.x$multiplier.${brightness.name}.${language.name}';
    testWidgets(name, (tester) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      final ar = language == AppLanguage.ar;
      final engine = FakeLiveMediaEngine();
      await pumpScreen(
        tester,
        Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              _backdrop(brightness),
              LiveGiftEffectsLayer(roomId: 'room-a', onOpenRoom: (_) {}),
            ],
          ),
        ),
        language: language,
        brightness: brightness,
        disableAnimations: true,
        liveGiftRepository: FakeLiveGiftRepository(
          codes: const ['lucky_clover'],
          ar: ar,
        ),
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      );
      container
          .read(liveLuckyTickersProvider('room-a').notifier)
          .attach(engine);
      engine.chat.add(LiveChatEvent.parse(_message(multiplier, ar: ar))!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final context = tester.element(find.byType(LiveGiftEffectsLayer));
      await tester.runAsync(() async {
        for (final tier in LuckyWinTier.values) {
          await precacheImage(AssetImage(tier.frame), context);
        }
        await precacheImage(AssetImage(KabsoArt.coin.asset), context);
      });
      // Not precacheImages: its settle would run the banner's 3.5 s out.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/$name.${GoldenViewport.phone.name}.png'),
      );
      await tester.pump(LiveLuckyTickers.showTime);
    });
  }
}
