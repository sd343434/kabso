// KL-056: debug-only hub that links to the design previews.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:material_ui/material_ui.dart' show ListView, Offset;

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('lists every preview and opens the feed '
        '(${language.name})', (tester) async {
      // Signed out, no server: the hub still opens in a test build.
      await pumpKabsoApp(
        tester,
        language: language.name,
        overrides: [
          initialLocationProvider.overrideWithValue(AppRoutes.debugPreviews),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();
      final l10n = l10nFor(language);
      expect(find.text(l10n.previewsHubTitle), findsOneWidget);
      for (final label in [
        l10n.previewsHubFeed,
        l10n.previewsHubLive,
        l10n.previewsHubMessages,
        l10n.previewsHubComponents,
      ]) {
        // The list outgrew one screen (D57–D60 previews): scroll to each.
        await tester.scrollUntilVisible(find.text(label), 100);
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.previewsHubFeed));
      await tester.pumpAndSettle();
      expect(find.byType(FeedPreviewScreen), findsOneWidget);
    });
  }

  test('the hub route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugPreviews,',
      ),
    );
    // The start route override is ignored in release builds.
    expect(
      router,
      contains(
        'if (!kReleaseMode && start.startsWith(AppRoutes.debugPrefix)) '
        'return start;',
      ),
    );
  });
}
