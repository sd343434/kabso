// D248c (owner: «… جميعها يتم تحميلها من لوحة الأدمن، كل فئة يمكن أن تكون
// متحركة»): an animated banner picture plays in the card-size hub banner,
// shows its first frame with reduce motion, and is paused while its subtree's
// tickers are off (a hidden route or tab). The fixture is a 3-frame Kabso-red
// GIF (Flutter decodes animated WebP the same way).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/hub_card_banner.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

const _card = HomeBanner(
  id: 'card-anim',
  imageUrl: 'https://media.example.test/media/card-anim/720.webp',
  width: 720,
  height: 805,
  link: '/families',
);

final Uint8List _gif = File('test/fixtures/live/d248c_anim_banner.gif')
    .readAsBytesSync();

Future<void> _pump(
  WidgetTester tester, {
  bool reduceMotion = false,
  bool tickers = true,
}) async {
  KHubCardBanner.imageForTesting = (_) => MemoryImage(_gif);
  addTearDown(() => KHubCardBanner.imageForTesting = null);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        brightness: Brightness.dark,
        locale: const Locale('en'),
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickers,
            child: const Center(
              child: SizedBox(
                width: 180,
                height: 201,
                child: KHubCardBanner(banners: [_card]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The colour of the shown frame's centre pixel (RGBA bytes).
Future<int> _frameColor(WidgetTester tester) async {
  final raw = tester.widget<RawImage>(find.byType(RawImage));
  final image = raw.image;
  if (image == null) return -1;
  final data = await tester.runAsync(image.toByteData);
  final i = (image.height ~/ 2 * image.width + image.width ~/ 2) * 4;
  return data!.getUint32(i);
}

/// Lets the codec decode and the frame timer run for [ms] of real and fake
/// time.
Future<void> _play(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('an animated picture plays in the hub card cell', (tester) async {
    await _pump(tester);
    await _play(tester, 300);
    final first = await _frameColor(tester);
    expect(first, isNot(-1));
    final seen = {first};
    for (var i = 0; i < 6; i++) {
      await _play(tester, 200);
      seen.add(await _frameColor(tester));
    }
    expect(seen.length, greaterThan(1), reason: 'the frames change');
  });

  testWidgets('reduce motion: the first frame only', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _play(tester, 300);
    final first = await _frameColor(tester);
    expect(first, isNot(-1));
    for (var i = 0; i < 6; i++) {
      await _play(tester, 200);
      expect(await _frameColor(tester), first);
    }
  });

  testWidgets('paused while its tickers are off (a hidden route or tab)', (
    tester,
  ) async {
    await _pump(tester, tickers: false);
    await _play(tester, 300);
    final shown = await _frameColor(tester);
    for (var i = 0; i < 6; i++) {
      await _play(tester, 200);
      expect(await _frameColor(tester), shown);
    }
  });
}
