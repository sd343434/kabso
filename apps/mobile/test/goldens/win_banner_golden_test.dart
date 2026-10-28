// D159 goldens: the owner's four win banners (sapphire ×10, ruby ×100,
// amethyst ×250, onyx ×1000) in ar and en, still (reduced motion: the
// banner at rest, the whole amount), on the audio room's purple.
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/win_banner_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/golden.dart';

const ValueKey<String> _boundary = ValueKey('win-banner-golden');

LuckyWin _win(int multiplier, int coins, String name) => LuckyWin(
  giftId: 'g-$multiplier',
  roomId: 'room-0',
  giftCode: 'lucky_clover',
  sender: UserSummary(
    id: 'u-$name',
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
  ),
  multiplier: multiplier,
  coinsWon: coins,
  createdAt: DateTime.utc(2026, 10, 28, 12),
);

void main() {
  forEachLanguage((language) {
    testWidgets('${language.name}: the four tiers', (tester) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      final width = LiveWinBanner.widthOn(
        GoldenViewport.phone.logicalSize.width,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: language.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: language.locale,
            ),
            // Still: the banner at rest (no slide), the whole amount.
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: app!,
            ),
            home: Scaffold(
              backgroundColor: const Color(0xFF6A4CBA),
              body: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (m, coins, name) in const [
                    (10, 1200, 'Sara'),
                    (100, 650, 'Oz Nabulsi'),
                    (250, 25000, 'Ahmed'),
                    (1000, 99878, 'Mona'),
                  ])
                    Center(
                      child: LiveWinBanner(
                        win: _win(m, coins, name),
                        width: width,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        for (final tier in LuckyWinTier.values) {
          await precacheImage(AssetImage(tier.frame), context);
        }
        await precacheImage(AssetImage(KabsoArt.coin.asset), context);
      });
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byKey(_boundary),
        matchesGoldenFile(
          'png/win_banners.${language.name}.${GoldenViewport.phone.name}.png',
        ),
      );
      // Let the 3.2 s timeline end.
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
