// D349 (owner 2026-11-09, CONVENTIONS §10.147): «إفيهات» by dialect — the
// quips tab's sub-categories in the server's order مجانية, مصري, خليجي,
// أردني; every paid line 100 000 coins; a Gulf / Jordanian line shows the
// owner's words (with their emoji) and plays its bundled sound; every
// bundled quip folder is in the app's assets. Arabic RTL and English,
// goldens at 393×852 @3x (the picker and the playing strip).

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

const _open = Key('test.openGifts');

class _FakeAudio implements QuipAudio {
  final played = <String>[];

  @override
  Future<void> play(String soundKey) async => played.add(soundKey);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _Room extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: TextButton(
            key: _open,
            onPressed: () => unawaited(
              KLiveGiftSheet.show(
                context,
                room: LiveGiftRoom(
                  roomId: 'room-0',
                  host: _host,
                  seated: (_) => const [],
                ),
              ),
            ),
            child: const SizedBox.square(dimension: 40),
          ),
        ),
        const Positioned(
          top: 140,
          left: 16,
          right: 16,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: LiveGiftStrips(roomId: 'room-0'),
          ),
        ),
      ],
    ),
  );
}

Future<(FakeLiveGiftRepository, _FakeAudio)> _pump(
  WidgetTester tester, {
  required AppLanguage language,
}) async {
  await loadAppFonts();
  final gifts = FakeLiveGiftRepository(
    codes: [...giftFixtureCodes, ...quipRegionFixtureCodes],
    ar: language == AppLanguage.ar,
    coins: 1000000,
  )..categories = const ['POPULAR', 'EVENT', 'FUN', 'QUIPS'];
  final audio = _FakeAudio();
  await pumpScreen(
    tester,
    const _Room(),
    language: language,
    liveGiftRepository: gifts,
    disableAnimations: true,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
      quipAudioProvider.overrideWithValue(audio),
    ],
  );
  setViewport(tester, GoldenViewport.phone);
  ProviderScope.containerOf(tester.element(find.byType(_Room)))
      .listen(liveQuipsProvider('room-0'), (_, _) {});
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(KLiveGiftSheet.tabKey('QUIPS')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(KLiveGiftSheet.tabKey('QUIPS')));
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return (gifts, audio);
}

Finder _cell(String code) => find.byKey(KLiveGiftSheet.cellKey(code));

Finder _inCell(String code, Finder f) =>
    find.descendant(of: _cell(code), matching: f);

double _x(WidgetTester tester, Finder f) => tester.getCenter(f).dx;

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    group('quips by dialect (${language.name})', () {
      testWidgets('the chips come in the server order مجانية, مصري, خليجي, '
          'أردني and filter the cells', (tester) async {
        await _pump(tester, language: language);
        final names = ar
            ? ['مجانية', 'مصري', 'خليجي', 'أردني']
            : ['Free', 'Egyptian', 'Gulf', 'Jordanian'];
        final codes = ['free', 'egypt', 'gulf', 'jordan'];
        for (var i = 0; i < codes.length; i++) {
          expect(
            find.descendant(
              of: find.byKey(KLiveGiftSheet.tagKey(codes[i])),
              matching: find.text(names[i]),
            ),
            findsOneWidget,
          );
        }
        // Reading order: right to left in Arabic, left to right in English.
        final xs = [
          for (final c in codes)
            _x(tester, find.byKey(KLiveGiftSheet.tagKey(c))),
        ];
        for (var i = 1; i < xs.length; i++) {
          expect(ar ? xs[i] < xs[i - 1] : xs[i] > xs[i - 1], isTrue);
        }
        // «خليجي» shows the Gulf line only.
        // The chip row scrolls sideways (the last chips start off screen).
        await tester.ensureVisible(find.byKey(KLiveGiftSheet.tagKey('gulf')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(KLiveGiftSheet.tagKey('gulf')));
        await tester.pumpAndSettle();
        expect(_cell('quip_gulf_14'), findsOneWidget);
        expect(_cell('quip_ghazal_01'), findsNothing);
        expect(_cell('quip_jordan_01'), findsNothing);
        expect(_cell('quip_clap'), findsNothing);
        // The chip row scrolls sideways (the last chips start off screen).
        await tester.ensureVisible(find.byKey(KLiveGiftSheet.tagKey('jordan')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(KLiveGiftSheet.tagKey('jordan')));
        await tester.pumpAndSettle();
        expect(_cell('quip_jordan_01'), findsOneWidget);
        expect(_cell('quip_gulf_14'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets("a Gulf line shows the owner's words and 100000; it is "
          'sent with coins and plays its own sound', (tester) async {
        final (gifts, audio) = await _pump(tester, language: language);
        const words =
            'تدري وش ناقص الدنيا؟ نسخة ثانية منك، '
            'عشان إذا اشتقت لك أروح لها! 😂';
        expect(_inCell('quip_gulf_14', find.text(words)), findsOneWidget);
        expect(_inCell('quip_gulf_14', find.text('100000')), findsOneWidget);
        expect(_inCell('quip_ghazal_01', find.text('100000')), findsOneWidget);
        await tester.ensureVisible(_cell('quip_gulf_14'));
        await tester.tap(_cell('quip_gulf_14'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
        await tester.pump(const Duration(milliseconds: 50));
        expect(gifts.sends.single.giftCode, 'quip_gulf_14');
        expect(gifts.sends.single.source, LiveGiftSource.coins);
        expect(audio.played, ['gulf/gulf_14']);
        // The strip shows the words, emoji included.
        expect(
          find.descendant(
            of: find.byType(LiveGiftBanner),
            matching: find.textContaining('😂'),
          ),
          findsWidgets,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/quips_regions_d349_strip.${language.name}.phone.png',
          ),
        );
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('golden: the quips tab with its four sub-categories', (
        tester,
      ) async {
        await _pump(tester, language: language);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/quips_regions_d349.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    });
  }

  test('the Gulf and Jordanian lines have their own Kabso art', () {
    expect(quipArt('quips/gulf').asset, startsWith('assets/emojis/kabi/'));
    expect(quipArt('quips/jordan').asset, startsWith('assets/emojis/kabi/'));
    expect(quipAssetOf('gulf/gulf_07'), 'quips/gulf');
    expect(quipAssetOf('jordan/jordan_02'), 'quips/jordan');
    expect(quipAssetOf('kabi/tease_02'), 'quips/tease');
    expect(quipAssetOf('room/ya_salam'), 'quips/ya_salam');
  });

  testWidgets('every bundled quip sound is an app asset (each folder is in '
      'pubspec.yaml) and loads', (tester) async {
    final root = Directory('assets/sounds/quips');
    final folders =
        root
            .listSync()
            .whereType<Directory>()
            .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
            .toList()
          ..sort();
    expect(folders, ['gulf', 'jordan', 'kabi', 'room']);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final keys = <String>[];
    for (final folder in folders) {
      expect(pubspec, contains('- assets/sounds/quips/$folder/'));
      for (final f in Directory('${root.path}/$folder').listSync()) {
        final name = f.uri.pathSegments.last;
        expect(name, endsWith('.mp3'));
        keys.add('$folder/${name.replaceAll('.mp3', '')}');
      }
    }
    // 8 free + 27 Egyptian (D154), 14 Gulf + 4 Jordanian (D349).
    expect(keys, hasLength(53));
    await tester.runAsync(() async {
      for (final key in keys) {
        final data = await rootBundle.load(
          'assets/${AudioplayersQuipAudio.assetOf(key)}',
        );
        expect(data.lengthInBytes, greaterThan(10000), reason: key);
      }
    });
  });
}
