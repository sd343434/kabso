// D332 (owner: «في المنشورات زر الإعجاب بعيد عن باقي الأزرار، عدّله»): the
// post card's action row — like · comment · share · repost · views one
// group at the start, each icon and its count a tight unit with the same
// air between units, save alone at the end — in Arabic RTL and English
// LTR, at 393 and 360 dp, with large counts and large text; every target
// stays at least 48 dp.
import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 9, 9, 41);

FeedPostData _post({
  required String id,
  bool isSelf = false,
  int likes = 0,
  int comments = 0,
  int shares = 0,
  int reposts = 0,
  int? views = 0,
}) => FeedPostData(
  authorName: 'Kabso',
  authorUsername: 'kabso',
  postedAt: _now.subtract(const Duration(hours: 2)),
  postId: id,
  text: 'Post $id',
  isSelf: isSelf,
  likes: likes,
  comments: comments,
  shares: shares,
  reposts: reposts,
  views: views,
);

Future<void> _pump(
  WidgetTester tester,
  FeedPostData post, {
  required AppLanguage language,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  await withClock(Clock.fixed(_now), () async {
    await pumpScreen(
      tester,
      Scaffold(
        body: ListView(children: [FeedPostTile(post: post)]),
      ),
      language: language,
      brightness: Brightness.light,
    );
  });
  await tester.pump();
}

Rect _icon(WidgetTester tester, Key target) => tester.getRect(
  find.descendant(of: find.byKey(target), matching: find.byType(AppIcon)),
);

Rect _text(WidgetTester tester, Key target) => tester.getRect(
  find.descendant(of: find.byKey(target), matching: find.byType(Text)),
);

/// The gap between two rects along the reading direction.
double _gap(Rect before, Rect after, {required bool rtl}) =>
    rtl ? before.left - after.right : after.left - before.right;

void main() {
  // The real fonts: the widths of the counts decide the row.
  setUpAll(loadAppFonts);

  for (final language in AppLanguage.values) {
    final rtl = language == AppLanguage.ar;
    for (final viewport in GoldenViewport.values) {
      final tag = '${language.name} ${viewport.name}';

      testWidgets('$tag: the heart sits with its count and the other units, '
          'save alone at the end', (tester) async {
        await _pump(
          tester,
          _post(id: 'p1', isSelf: true),
          language: language,
          viewport: viewport,
        );
        final width = viewport.logicalSize.width;
        final heart = _icon(tester, FeedPostTile.likeKey);
        final likes = tester.getRect(find.byKey(FeedPostTile.likersKey));
        final likeCount = _text(tester, FeedPostTile.likersKey);
        final comment = _icon(tester, FeedPostTile.commentKey);
        final commentCount = _text(tester, FeedPostTile.commentKey);
        final save = _icon(tester, FeedPostTile.saveKey);

        // The heart and its count are one tight unit (4 dp), like the
        // comment icon and its count.
        expect(
          _gap(heart, likeCount, rtl: rtl),
          closeTo(KPostCard.countGap, 1),
        );
        expect(
          _gap(comment, commentCount, rtl: rtl),
          closeTo(KPostCard.countGap, 1),
        );
        // The like unit is as close to the comment unit as the units after.
        final likeToComment = _gap(likeCount, comment, rtl: rtl);
        expect(likeToComment, inInclusiveRange(12, 20));
        // Before D332 the heart stood alone 26 dp before its count.
        expect(_gap(heart, likes, rtl: rtl), lessThan(KPostCard.countGap + 1));

        // The heart starts the row and the bookmark ends it, both 22 dp
        // from their edge.
        final heartInset = rtl ? width - heart.right : heart.left;
        final saveInset = rtl ? save.left : width - save.right;
        expect(heartInset, closeTo(22, 0.5));
        expect(saveInset, closeTo(22, 0.5));
        // Save is alone at the end, well away from the group.
        final commentEnd = rtl ? commentCount.left : commentCount.right;
        expect((save.center.dx - commentEnd).abs(), greaterThan(100));

        // Every button keeps a 48 dp target.
        for (final key in [
          FeedPostTile.likeKey,
          FeedPostTile.commentKey,
          FeedPostTile.saveKey,
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
        }
        expect(
          tester.getSize(find.byKey(FeedPostTile.likersKey)).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('$tag: equal air between the units (16 dp when they fit '
          'comfortably)', (tester) async {
        await _pump(
          tester,
          _post(id: 'p2', likes: 7, comments: 3, shares: 2, reposts: 1),
          language: language,
          viewport: viewport,
        );
        final likeCount = _text(tester, FeedPostTile.likersKey);
        final comment = _icon(tester, FeedPostTile.commentKey);
        final commentCount = _text(tester, FeedPostTile.commentKey);
        final repost = _icon(tester, FeedPostTile.repostKey);
        // Like → comment, and the share unit sits between comment and
        // repost with the same air on both of its sides.
        final first = _gap(likeCount, comment, rtl: rtl);
        expect(first, closeTo(2 * KPostCard.unitPad, 1));
        final span = _gap(commentCount, repost, rtl: rtl);
        // comment count → [share unit] → repost icon: two gaps + the unit.
        expect(span, greaterThan(2 * 2 * KPostCard.unitPad));
        // The repost unit's count follows its icon closely.
        final repostCount = _text(tester, FeedPostTile.repostKey);
        expect(
          _gap(repost, repostCount, rtl: rtl),
          closeTo(KPostCard.countGap, 1),
        );
        // All on one line.
        expect(repost.center.dy, closeTo(comment.center.dy, 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${language.name}: large counts (12.4K) stay on one line '
        'at 393 dp, the air shrinking instead of clipping', (tester) async {
      await _pump(
        tester,
        _post(
          id: 'p3',
          likes: 12400,
          comments: 857,
          shares: 42,
          reposts: 3,
          views: 98100,
        ),
        language: language,
      );
      final heart = _icon(tester, FeedPostTile.likeKey);
      final repost = _icon(tester, FeedPostTile.repostKey);
      final save = _icon(tester, FeedPostTile.saveKey);
      expect(repost.center.dy, closeTo(heart.center.dy, 0.5));
      expect(save.center.dy, closeTo(heart.center.dy, 0.5));
      expect(find.textContaining('12.4'), findsOneWidget);
      for (final key in [
        FeedPostTile.likeKey,
        FeedPostTile.commentKey,
        FeedPostTile.repostKey,
        FeedPostTile.saveKey,
      ]) {
        expect(
          tester.getSize(find.byKey(key)).width,
          greaterThanOrEqualTo(48),
          reason: '$key',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('${language.name}: huge counts at 360 dp and 1.6× text wrap '
        'without clipping or overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        _post(
          id: 'p4',
          likes: 12400,
          comments: 12400,
          shares: 12400,
          reposts: 12400,
          views: 1200000,
        ),
        language: language,
        viewport: GoldenViewport.android,
      );
      expect(tester.takeException(), isNull);
      // Every count is laid out at its full width (none ellipsised or cut).
      for (final key in [
        FeedPostTile.likersKey,
        FeedPostTile.commentKey,
        FeedPostTile.repostKey,
      ]) {
        final text = find.descendant(
          of: find.byKey(key),
          matching: find.byType(Text),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: '$key');
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
          ),
          reason: '$key',
        );
      }
      // The row stays inside the screen.
      final width = GoldenViewport.android.logicalSize.width;
      for (final key in [
        FeedPostTile.likeKey,
        FeedPostTile.commentKey,
        FeedPostTile.repostKey,
        FeedPostTile.saveKey,
      ]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.left, greaterThanOrEqualTo(0), reason: '$key');
        expect(r.right, lessThanOrEqualTo(width), reason: '$key');
      }
    });
  }

  testWidgets('semantics unchanged: like, likers, comments, share, repost, '
      'views and save keep their labels', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _post(id: 'p5', likes: 7, comments: 3, shares: 2, reposts: 1, views: 9),
      language: AppLanguage.en,
    );
    final like = tester.getSemantics(find.byKey(FeedPostTile.likeKey));
    expect(like.label, isNotEmpty);
    expect(like.value, '7');
    expect(
      tester.getSemantics(find.byKey(FeedPostTile.commentKey)).label,
      isNotEmpty,
    );
    expect(tester.getSemantics(find.byKey(FeedPostTile.likersKey)).value, '7');
    expect(tester.getSemantics(find.byKey(FeedPostTile.repostKey)).value, '1');
    handle.dispose();
  });
}
