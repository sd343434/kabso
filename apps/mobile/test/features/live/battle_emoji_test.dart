// D71: the owner's PK battle animations (SVGA) — bundled, decodable, the
// expected size and length, silent, and announced to screen readers.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUp(() => KabsoBattleEmoji.enabled = true);
  tearDown(() => KabsoBattleEmoji.enabled = false);

  test('one file per battle, and nothing else in the folder', () {
    final files = Directory('assets/battle')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(files, {
      for (final b in KabsoBattle.values) 'kabso_battle_${b.id}.svga',
    });
  });

  testWidgets('each file decodes: 600×600, 30 fps, 75 frames, no sound', (
    tester,
  ) async {
    for (final b in KabsoBattle.values) {
      final movie = await tester.runAsync(() async {
        final bytes = await rootBundle.load(b.asset);
        return await SVGAParser.shared.decodeFromBuffer(
          bytes.buffer.asUint8List(),
        );
      });
      expect(movie, isNotNull, reason: b.id);
      final params = movie!.params;
      expect(params.viewBoxWidth, 600, reason: b.id);
      expect(params.viewBoxHeight, 600, reason: b.id);
      expect(params.fps, 30, reason: b.id);
      expect(params.frames, 75, reason: b.id);
      expect(movie.audios, isEmpty, reason: b.id);
      expect(movie.sprites, isNotEmpty, reason: b.id);
      expect(
        Duration(milliseconds: params.frames * 1000 ~/ params.fps),
        KabsoBattleEmoji.duration,
        reason: b.id,
      );
    }
  });

  for (final language in AppLanguage.values) {
    testWidgets('screen readers hear the battle (${language.name})', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = l10nFor(language);
      await pumpScreen(
        tester,
        const Center(child: KabsoBattleEmoji(KabsoBattle.start)),
        language: language,
      );
      expect(find.bySemanticsLabel(l10n.pkBattleStart), findsOneWidget);
      expect(
        tester.getSize(find.byType(KabsoBattleEmoji)),
        const Size.square(220),
      );
      handle.dispose();
    });
  }

  testWidgets('reduced motion: one still frame, held, then done', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var done = 0;
    await pumpScreen(
      tester,
      Center(child: KabsoBattleEmoji(KabsoBattle.lose, onDone: () => done++)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(tester.hasRunningAnimations, isFalse);
    expect(done, 0);
    await tester.pump(KabsoBattleEmoji.duration);
    expect(done, 1);
  });

  testWidgets('leaving early cancels the held frame', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScreen(
      tester,
      const Center(child: KabsoBattleEmoji(KabsoBattle.draw)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    // No pending timer may outlive the widget (checked by the binding).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('plays once and reports when done', (tester) async {
    var done = 0;
    await pumpScreen(
      tester,
      Center(child: KabsoBattleEmoji(KabsoBattle.win, onDone: () => done++)),
    );
    // Decoding reads the bundle and decodes its images outside fake time.
    for (var i = 0; i < 20 && done == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(done, 1);
    // Once only.
    await tester.pump(KabsoBattleEmoji.duration * 2);
    expect(done, 1);
  });
}
