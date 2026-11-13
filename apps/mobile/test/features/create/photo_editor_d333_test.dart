// D333: the photo editor of Create — crop presets (Original · 1:1 · 4:5),
// quarter turns, looks and brightness / contrast, applied on the device
// before the upload.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/create/photo_editor.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

Future<Uint8List> _png(int w, int h, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Size> _size(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
}

Future<Color> _pixel(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData();
  final b = data!.buffer.asUint8List();
  return Color.fromARGB(b[3], b[0], b[1], b[2]);
}

void main() {
  group('the crop', () {
    test('original keeps the photo; 1:1 and 4:5 are centred', () {
      expect(
        photoCropRect(400, 200, PhotoAspect.original),
        const Rect.fromLTWH(0, 0, 400, 200),
      );
      expect(
        photoCropRect(400, 200, PhotoAspect.square),
        const Rect.fromLTWH(100, 0, 200, 200),
      );
      expect(
        photoCropRect(200, 400, PhotoAspect.square),
        const Rect.fromLTWH(0, 100, 200, 200),
      );
      final portrait = photoCropRect(400, 400, PhotoAspect.portrait);
      expect(portrait.width / portrait.height, closeTo(0.8, 1e-9));
      expect(portrait.center, const Offset(200, 200));
    });
  });

  group('the colour matrix', () {
    test('normal with no adjustment is the identity', () {
      expect(const PhotoEdit().isIdentity, isTrue);
      expect(photoEditMatrix(PhotoFilter.normal, 0, 0), [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);
    });

    test('brightness lifts, contrast stretches around the middle, mono '
        'greys', () {
      final bright = photoEditMatrix(PhotoFilter.normal, 1, 0);
      expect(bright[4], 64);
      final contrast = photoEditMatrix(PhotoFilter.normal, 0, 1);
      expect(contrast[0], 1.5);
      expect(contrast[4], -64); // 128 stays 128
      final mono = photoEditMatrix(PhotoFilter.mono, 0, 0);
      // Every channel is the same mix of red, green and blue.
      expect(mono.sublist(0, 3), mono.sublist(5, 8));
      expect(mono.sublist(0, 3), mono.sublist(10, 13));
    });

    test('quarter turns wrap', () {
      expect(const PhotoEdit().copyWith(quarterTurns: 5).quarterTurns, 1);
    });
  });

  testWidgets('render: turned, cropped to 1:1 and 4:5, mono; a PNG under '
      'the upload limit', (tester) async {
    await tester.runAsync(() async {
      final red = await _png(300, 200, const Color(0xFFFF0000));
      final turned = await renderPhotoEdit(
        red,
        const PhotoEdit(quarterTurns: 1),
      );
      expect(await _size(turned), const Size(200, 300));
      final square = await renderPhotoEdit(
        red,
        const PhotoEdit(aspect: PhotoAspect.square),
      );
      expect(await _size(square), const Size(200, 200));
      final portrait = await renderPhotoEdit(
        red,
        const PhotoEdit(aspect: PhotoAspect.portrait, quarterTurns: 3),
      );
      expect(await _size(portrait), const Size(200, 250));
      final mono = await renderPhotoEdit(
        red,
        const PhotoEdit(filter: PhotoFilter.mono),
      );
      expect(sniffImageType(mono), 'image/png');
      expect(mono.length, lessThanOrEqualTo(maxPhotoBytes));
      final px = await _pixel(mono);
      expect(px.r, closeTo(px.g, 0.01));
      expect(px.g, closeTo(px.b, 0.01));
    });
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: the editor — crop presets and rotate, '
        'six looks, brightness and contrast; Done returns the edit', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(
        () => _png(120, 80, const Color(0xFF3366CC)),
      ))!;
      Uint8List? result;
      var closed = false;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showPhotoEditor(context, bytes);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        language: language,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoEditorScreen), findsOneWidget);
      for (final a in PhotoAspect.values) {
        expect(find.byKey(PhotoEditorScreen.aspectKey(a)), findsOneWidget);
      }
      await tester.tap(
        find.byKey(PhotoEditorScreen.aspectKey(PhotoAspect.square)),
      );
      await tester.tap(find.byKey(PhotoEditorScreen.rotateKey));
      await tester.pump();
      await tester.tap(find.byKey(PhotoEditorScreen.toolKey(1)));
      await tester.pumpAndSettle();
      for (final f in PhotoFilter.values) {
        expect(find.byKey(PhotoEditorScreen.filterKey(f)), findsOneWidget);
      }
      await tester.tap(
        find.byKey(PhotoEditorScreen.filterKey(PhotoFilter.warm)),
      );
      await tester.tap(find.byKey(PhotoEditorScreen.toolKey(2)));
      await tester.pumpAndSettle();
      expect(find.byKey(PhotoEditorScreen.brightnessKey), findsOneWidget);
      expect(find.byKey(PhotoEditorScreen.contrastKey), findsOneWidget);
      await tester.drag(
        find.byKey(PhotoEditorScreen.brightnessKey),
        const Offset(60, 0),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Done renders on the device (real image work, outside fake time).
      await tester.tap(find.byKey(PhotoEditorScreen.doneKey));
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && !closed; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNotNull);
      final size = (await tester.runAsync(() => _size(result!)))!;
      // 1:1 of the turned 80 × 120.
      expect(size, const Size(80, 80));
    });
  }
}
