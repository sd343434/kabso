// CP-020: the `gift` data message → banners and the large effect in the
// room (combos update one banner, a send plays once, big and animated
// gifts play centred, banners take turns); ar + en at 360×800, text scale 2.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.android);
  final engine = FakeLiveMediaEngine();
  await pumpScreen(
    tester,
    const Scaffold(body: LiveGiftEffectsLayer(roomId: 'room-0')),
    language: language,
    liveGiftRepository: FakeLiveGiftRepository(
      codes: giftFixtureCodes,
      ar: language == AppLanguage.ar,
    ),
    overrides: [currentUserProvider.overrideWithValue(testUser())],
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(tester.element(find.byType(LiveGiftEffectsLayer)))
      .read(liveGiftEffectsProvider('room-0').notifier)
      .attach(engine);
  return engine;
}

LiveGiftReceived _gift({
  String id = 'g1',
  String roomId = 'room-0',
  String code = 'rose',
  int quantity = 10,
  String sender = 'lina',
  String? comboId,
  int comboCount = 1,
  List<Map<String, Object?>>? recipients,
}) => LiveGiftReceived(
  LiveGift.fromJson(
    liveGiftJson(
      id: id,
      roomId: roomId,
      code: code,
      quantity: quantity,
      sender: giftUserJson(sender, sender == 'lina' ? 'Lina' : sender),
      recipients:
          recipients ??
          [giftUserJson('sara', 'Sara'), giftUserJson('omar', 'Omar')],
      comboId: comboId,
      comboCount: comboCount,
    ),
  ),
);

Future<void> _show(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final en = l10nFor(AppLanguage.en);

  testWidgets('a gift message: sender → recipients, the name from the '
      'catalogue, ×quantity; gone 4 s after it (D145c)', (tester) async {
    final engine = await _pump(tester);
    engine.chat.add(_gift());
    await _show(tester);
    expect(find.byType(LiveGiftBanner), findsOneWidget);
    expect(find.textContaining('Lina'), findsOneWidget);
    expect(
      find.text(
        en.liveGiftBannerSent(
          '\u2068Rose\u2069',
          en.liveGiftRecipientsTwo('\u2068Sara\u2069', '\u2068Omar\u2069'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(en.giftCombo(10)), findsOneWidget);
    expect(find.byType(KGiftImage), findsOneWidget);
    // A small gift: no centred effect.
    expect(find.byType(KGiftEffect), findsNothing);
    expect(LiveGiftEffects.bannerTime, const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.byType(LiveGiftBanner), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(LiveGiftBanner), findsNothing);
  });

  testWidgets('a combo updates its banner (×count); the same send twice '
      'plays once; another live is ignored', (tester) async {
    final engine = await _pump(tester);
    engine.chat.add(_gift());
    await _show(tester);
    engine.chat
      ..add(_gift(id: 'g2', comboId: 'g1', comboCount: 2))
      ..add(_gift(id: 'g3', comboId: 'g1', comboCount: 3))
      // Late and out of order: the count does not go back.
      ..add(_gift(id: 'g2b', comboId: 'g1', comboCount: 2))
      ..add(_gift(id: 'g3', comboId: 'g1', comboCount: 3))
      ..add(_gift(id: 'x', roomId: 'room-9'));
    await _show(tester);
    expect(find.byType(LiveGiftBanner), findsOneWidget);
    expect(find.byType(KGiftComboCounter), findsOneWidget);
    // D145a: one count — the gifts each recipient got in the combo (10 × 3).
    expect(find.text(en.giftCombo(30)), findsOneWidget);
    // Each send of the combo keeps the banner up.
    await tester.pump(const Duration(seconds: 2));
    engine.chat.add(_gift(id: 'g4', comboId: 'g1', comboCount: 4));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(en.giftCombo(40)), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LiveGiftBanner), findsNothing);
  });

  testWidgets('D145: three strips at once, the newest on top; the fourth '
      'waits its turn', (tester) async {
    final engine = await _pump(tester);
    engine.chat
      ..add(_gift(id: 'a', sender: 'a'))
      ..add(_gift(id: 'b', sender: 'b'))
      ..add(_gift(id: 'c', sender: 'c'))
      ..add(_gift(id: 'd', sender: 'd'));
    await _show(tester);
    expect(find.byType(LiveGiftBanner), findsNWidgets(3));
    expect(find.byKey(LiveGiftEffectsLayer.bannerKey('d')), findsNothing);
    double top(String id) =>
        tester.getRect(find.byKey(LiveGiftEffectsLayer.bannerKey(id))).top;
    expect(top('c'), lessThan(top('b')));
    expect(top('b'), lessThan(top('a')));
    await tester.pump(LiveGiftEffects.bannerTime);
    await _show(tester);
    expect(find.byKey(LiveGiftEffectsLayer.bannerKey('d')), findsOneWidget);
    await tester.pump(LiveGiftEffects.bannerTime);
    await tester.pumpAndSettle();
    expect(find.byType(LiveGiftBanner), findsNothing);
  });

  testWidgets('D145c: only an animated gift plays the full-screen effect '
      '(never the still picture blown up); its strip shows with it; the '
      'next one waits', (tester) async {
    final engine = await _pump(tester);
    // 5 000 coins × 1 × 2, and it names an animation.
    engine.chat.add(_gift(id: 'car', code: 'sports_car', quantity: 1));
    await _show(tester);
    expect(find.byType(KGiftEffect), findsOneWidget);
    expect(find.byType(LiveGiftBanner), findsOneWidget);
    // Tests skip decoding: nothing is drawn until the movie is ready — no
    // still picture of the gift outside its strip.
    expect(
      find.descendant(
        of: find.byKey(LiveGiftEffectsLayer.effectKey),
        matching: find.byType(KGiftImage),
      ),
      findsNothing,
    );
    // 520 × 10 × 2 coins but no animation: its strip only.
    engine.chat.add(_gift(id: 'cake', code: 'cake'));
    // A second animated gift waits for the first.
    engine.chat.add(_gift(id: 'car2', code: 'sports_car', sender: 'b'));
    await tester.pump(LiveGiftEffects.bigTime);
    await tester.pump();
    final effect = tester.widget<KGiftEffect>(find.byType(KGiftEffect));
    expect(effect.key, const ValueKey('car2'));
    await tester.pump(LiveGiftEffects.bigTime);
    await tester.pumpAndSettle();
    expect(find.byType(KGiftEffect), findsNothing);
  });

  testWidgets('a gift the catalogue does not have: "a gift"; three or more '
      'recipients: the first and how many more', (tester) async {
    final engine = await _pump(tester);
    engine.chat.add(
      _gift(
        code: 'mystery',
        recipients: [
          giftUserJson('sara', 'Sara'),
          giftUserJson('omar', 'Omar'),
          giftUserJson('nour', 'Nour'),
        ],
      ),
    );
    await _show(tester);
    expect(
      find.text(
        en.liveGiftBannerSent(
          '\u2068${en.liveGiftGeneric}\u2069',
          en.liveGiftRecipientsMore('\u2068Sara\u2069', 2),
        ),
      ),
      findsOneWidget,
    );
    await tester.pump(LiveGiftEffects.bannerTime);
    await tester.pumpAndSettle();
  });

  testWidgets('Arabic (RTL) and English at 360×800, text scale 2: no '
      'overflow; the banner sits at the reading start', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      final engine = await _pump(tester, language: language);
      engine.chat.add(
        _gift(
          sender: 'a_very_long_display_name_for_a_sender',
          code: 'sports_car',
          quantity: 1314,
        ),
      );
      await _show(tester);
      expect(tester.takeException(), isNull, reason: language.name);
      final banner = tester.getRect(find.byType(LiveGiftBanner));
      final rtl = language == AppLanguage.ar;
      expect(banner.left < 40, !rtl, reason: language.name);
      expect(banner.right > 320, rtl, reason: language.name);
      expect(banner.right <= 360, isTrue);
      await tester.pump(LiveGiftEffects.bigTime);
      await tester.pumpAndSettle();
    }
  });
}
