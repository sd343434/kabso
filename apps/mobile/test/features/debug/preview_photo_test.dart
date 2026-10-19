// KL-056: development preview imagery (assets/preview/) — present, decodes,
// documented, used by the debug previews only, and drawn over the
// generated art.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final all = [
    ...PreviewPhotos.portrait,
    ...PreviewPhotos.landscape,
    ...PreviewPhotos.avatars,
  ];

  test(
    'every preview photo exists, decodes, and has the expected shape',
    () async {
      for (final path in all) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        final ratio = image.width / image.height;
        if (PreviewPhotos.portrait.contains(path)) {
          expect(ratio, closeTo(9 / 16, 0.02), reason: path);
          expect(image.width, greaterThanOrEqualTo(720), reason: path);
        } else if (PreviewPhotos.avatars.contains(path)) {
          expect(image.width, image.height, reason: path);
          expect(image.width, greaterThanOrEqualTo(512), reason: path);
        } else {
          expect(ratio, inInclusiveRange(1, 1.4), reason: path);
        }
        image.dispose();
      }
      // Nothing extra in the folder (Flutter bundles every file in it).
      final onDisk = Directory('assets/preview')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toSet();
      expect(onDisk, all.toSet());
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('    - assets/preview/\n'),
      );
    },
  );

  test('every preview photo has a provenance row', () {
    final manifest = File('../../docs/design/PREVIEW_ASSETS.md')
        .readAsStringSync();
    for (final path in all) {
      expect(manifest, contains('`$path`'), reason: path);
    }
    expect(manifest, contains('development only'));
  });

  test('only the debug previews use the preview imagery', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final s = f.readAsStringSync();
          return s.contains('assets/preview') ||
              s.contains('PreviewPhoto') ||
              s.contains('preview_photo.dart');
        })
        .map((f) => f.path.replaceAll(r'\', '/'));
    for (final path in users) {
      expect(path, startsWith('lib/features/debug/'), reason: path);
    }
  });

  testWidgets('enabled: the photo is drawn over the art once decoded', (
    tester,
  ) async {
    PreviewPhoto.enabled = true;
    addTearDown(() => PreviewPhoto.enabled = false);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 180, height: 320, child: PreviewPhoto(0)),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        PreviewPhotos.image(PreviewPhotoKind.portrait, 0),
        tester.element(find.byType(PreviewPhoto)),
      ),
    );
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, PreviewPhotos.portrait.first);
    expect(image.fit, BoxFit.cover);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('disabled (tests, goldens): generated art only', (tester) async {
    expect(PreviewPhoto.enabled, isFalse);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 180, height: 320, child: PreviewPhoto(3)),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(PreviewPhotos.avatar(0), isNull);
    expect(PreviewPhotos.cover(0), isNull);
  });
}
