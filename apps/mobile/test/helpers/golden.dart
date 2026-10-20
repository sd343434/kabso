// G-26 golden-test infrastructure (REFERENCE_INVENTORY §6.1).
//
// - Real fonts: Inter, Readex Pro and Material Icons are loaded
//   with FontLoader (flutter_test defaults to Ahem, which hides Arabic
//   shaping and icon problems).
// - Pinned viewports: 393×852 @3x (primary) and 360×800 @3x (Android).
// - Determinism: animations disabled through MediaQuery (skeletons are
//   static, motion is instant), memory images precached in runAsync, data
//   from test/fixtures only.
//
// Goldens are generated and compared on Linux with the pinned Flutter
// (3.47.7). On other OSes font rasterisation differs, so treat local
// failures there as informational. Regenerate (dedicated commit, A5 reviews
// the images):
//
//   flutter test --update-goldens test/goldens/
//   flutter test --update-goldens test/goldens/<file>_golden_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Test tag for golden tests (`flutter test --tags golden`).
const goldenTag = 'golden';

enum GoldenViewport {
  /// Primary reference device: 393×852 dp @3x.
  phone(Size(393, 852)),

  /// Android check: 360×800 dp @3x.
  android(Size(360, 800));

  new(this.logicalSize);

  final Size logicalSize;

  static const double pixelRatio = 3;
}

bool _fontsLoaded = false;

/// Loads the bundled app fonts and Material Icons once per test isolate.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family(KFonts.latin, const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await family(KFonts.arabic, const [
    'assets/fonts/ReadexPro-Regular.ttf',
    'assets/fonts/ReadexPro-Medium.ttf',
    'assets/fonts/ReadexPro-SemiBold.ttf',
    'assets/fonts/ReadexPro-Bold.ttf',
  ]);
  // D63/D64: splash wordmark and the welcome screen.
  await family('Fredoka', const ['assets/fonts/Fredoka-Bold.ttf']);
  await family('Baloo Bhaijaan 2', const [
    'assets/fonts/BalooBhaijaan2-SemiBold.ttf',
    'assets/fonts/BalooBhaijaan2-ExtraBold.ttf',
  ]);
  // Bundled by `uses-material-design: true`.
  await family('MaterialIcons', const ['fonts/MaterialIcons-Regular.otf']);
  _fontsLoaded = true;
}

/// Pins the test view to [viewport] for the rest of the test.
void setViewport(WidgetTester tester, GoldenViewport viewport) {
  tester.view
    ..physicalSize = viewport.logicalSize * GoldenViewport.pixelRatio
    ..devicePixelRatio = GoldenViewport.pixelRatio;
  addTearDown(tester.view.reset);
}

const ValueKey<String> _boundaryKey = ValueKey('golden-boundary');

/// Pumps [child] full-screen in a themed, localized app with animations
/// disabled, then precaches every [Image] in the tree.
///
/// [child] is placed in a [Scaffold] body unless [bare] is set (room
/// scaffolds and sheets bring their own surface).
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  required AppLanguage language,
  GoldenViewport viewport = GoldenViewport.phone,
  Brightness brightness = Brightness.dark,
  bool bare = false,
  EdgeInsetsGeometry padding = const EdgeInsets.all(KSpacing.lg),
}) async {
  await loadAppFonts();
  setViewport(tester, viewport);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        home: bare
            ? Material(type: MaterialType.transparency, child: child)
            : Scaffold(
                body: SafeArea(
                  child: Padding(padding: padding, child: child),
                ),
              ),
      ),
    ),
  );
  await precacheImages(tester);
}

/// Decodes every image in the tree outside the fake-async zone, then
/// rebuilds so images (or their error builders) are painted.
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, _) {});
    }
  });
  await tester.pumpAndSettle();
}

/// Compares the whole screen with `test/goldens/png/<name>.<lang>.<vp>.png`.
Future<void> expectScreenGolden(
  String name, {
  required AppLanguage language,
  GoldenViewport viewport = GoldenViewport.phone,
}) => expectLater(
  find.byKey(_boundaryKey),
  matchesGoldenFile('png/$name.${language.name}.${viewport.name}.png'),
);

/// Runs [body] once per language (ar first: Arabic is the primary locale).
void forEachLanguage(void Function(AppLanguage language) body) {
  const [AppLanguage.ar, AppLanguage.en].forEach(body);
}
