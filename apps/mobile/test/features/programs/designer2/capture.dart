// KL-352 design-options capture helpers (scratch, not a regression test).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/golden.dart';

/// Output root: `D2_OUT` env or `designer2_png/` under the test dir.
final String outRoot =
    Platform.environment['D2_OUT'] ?? 'test/features/programs/designer2_png';

const sceneKey = ValueKey('d2.scene');

Future<void> shot(
  WidgetTester tester,
  String path, {
  double ratio = 3,
  Finder? finder,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    finder ?? find.byKey(sceneKey),
  );
  final file = File('$outRoot/$path')..parent.createSync(recursive: true);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Like pumpGolden, but never settles (the prototypes run a ticker) and
/// leaves motion on unless [reduceMotion].
Future<void> pumpScene(
  WidgetTester tester,
  Widget child, {
  bool ar = true,
  Size size = const Size(393, 852),
  bool reduceMotion = false,
}) async {
  await loadAppFonts();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final locale = Locale(ar ? 'ar' : 'en');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: KabsoApp.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: buildAppTheme(brightness: Brightness.dark, locale: locale),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: app!,
      ),
      home: Material(type: MaterialType.transparency, child: child),
    ),
  );
  for (var pass = 0; pass < 3; pass++) {
    final els = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final e in els) {
        await precacheImage((e.widget as Image).image, e, onError: (_, _) {});
      }
    });
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Writes the rect and text of every paragraph in the scene (logical px),
/// for the pixel contrast check (`tools/contrast.py`).
void dumpTextRects(WidgetTester tester, String path) {
  final root = tester.renderObject(find.byKey(sceneKey));
  final out = <Map<String, Object>>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize && o.size.width > 4) {
      final tl = o.localToGlobal(Offset.zero, ancestor: root);
      out.add({
        'text': o.text.toPlainText(),
        'rect': [tl.dx, tl.dy, tl.dx + o.size.width, tl.dy + o.size.height],
      });
    }
    o.visitChildren(visit);
  }

  visit(root);
  File('$outRoot/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(out));
}
