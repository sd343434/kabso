// D75 (owner): `/debug/reels-preview` is the real Reels tab's reels — the
// Trending · Following tabs and the reel page — not a separate design with a
// coin balance.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/posts_preview_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('the reels preview opens the real Reels tab on its reels', (
    tester,
  ) async {
    final l10n = l10nFor(AppLanguage.ar);
    await pumpScreen(
      tester,
      const PostsPreviewScreen(initialTab: HomeTab.reels),
      language: AppLanguage.ar,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FeedScreen), findsOneWidget);
    expect(find.text(l10n.homeFeedTrending), findsOneWidget);
    expect(find.text(l10n.feedTabFollowing), findsOneWidget);
    // No coin balance on the reels page.
    expect(find.byType(KabsoArtIcon), findsNothing);
  });

  test('the route builds it with the reels tab', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains('const PostsPreviewScreen(initialTab: HomeTab.reels)'),
    );
  });
}
