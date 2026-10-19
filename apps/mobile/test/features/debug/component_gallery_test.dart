import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/features/debug/component_gallery_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/component_harness.dart';

void main() {
  testWidgets('gallery renders every P0 component and opens the demos', (
    tester,
  ) async {
    await pumpComponent(tester, const ComponentGalleryScreen());
    expect(find.text('Component gallery'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Gifts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Gifts'));
    await tester.pumpAndSettle();
    expect(find.byType(KGiftPanel), findsOneWidget);
    await tester.tap(find.text('Star'));
    await tester.pump();
    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();
    expect(find.text('×2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.byType(KLiveRoomScaffold), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Follow'));
    await tester.pump();
    expect(find.bySemanticsLabel('Following'), findsOneWidget);
  });

  testWidgets('KL-034: every room layout and state demo opens', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpComponent(tester, const ComponentGalleryScreen());
    for (final name in [
      'pk',
      'multiGuest',
      'weak',
      'reconnecting',
      'cameraOff',
      'videoUnavailable',
      'ended',
    ]) {
      final button = find.byKey(Key('gallery.room.$name'));
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(KLiveRoomScaffold), findsOneWidget, reason: name);
      expect(tester.takeException(), isNull, reason: name);
      // The ended overlay is modal: its own button leaves.
      await tester.tap(
        name == 'ended'
            ? find.text('Back to live rooms')
            : find.bySemanticsLabel('Close').first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(KLiveRoomScaffold), findsNothing, reason: name);
    }
  });

  test('the gallery route is only registered outside release mode', () {
    // Tests run in debug mode; the release guard is checked in the source.
    expect(kReleaseMode, isFalse);
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugComponents,',
      ),
    );
    expect(AppRoutes.debugComponents, '/debug/components');
    // Only the router and the debug Settings entry reference the gallery.
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('ComponentGalleryScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugComponents'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/component_gallery_screen.dart',
      // The debug-only hub links to every preview.
      'lib/features/debug/previews_hub_screen.dart',
      'lib/features/settings/settings_screen.dart',
    });
    final settings = File('lib/features/settings/settings_screen.dart')
        .readAsStringSync();
    expect(
      settings,
      contains(
        'if (!kReleaseMode)\n'
        '            ListTile(\n'
        "              key: const Key('settings.debug.components'),",
      ),
    );
  });
}
