// D218 (owner: «اجعل الصورة كاملة ولا تقص منها»): a story photo is shown
// whole — a wide and a tall picture each fit inside the screen at their own
// ratio (contain), never cropped; the header and the reply bar only lie over
// them, with no line under the header («وازل الخط اسفل الايقونات»).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/fixture_images.dart';
import '../../helpers/golden.dart' show GoldenViewport, setViewport;
import '../../helpers/pump_app.dart';

/// Serves [bytes] for every image URL (Image.network in a widget test).
class _Client implements HttpClient {
  new(this.bytes);
  final Uint8List bytes;
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  new(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  HttpHeaders get headers => _Headers();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  new(this.data);
  final Uint8List data;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => data.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([data]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Story _story(int width, int height) => Story(
  id: 's-$width-$height',
  author: const UserSummary(
    id: 'u1',
    username: 'nour',
    displayName: 'Nour',
    avatarUrl: null,
  ),
  media: MediaAsset(
    id: 'm1',
    // One URL per picture: the image cache keys by URL.
    url: 'https://media.example.test/media/m-$width-$height/1920.webp',
    thumbUrl: 'https://media.example.test/media/m1/320.webp',
    width: width,
    height: height,
  ),
  text: '',
  mentions: const [],
  createdAt: DateTime.utc(2026, 11, 1, 9),
  expiresAt: DateTime.utc(2026, 11, 2, 9),
  viewerHasSeen: true,
  isSelf: false,
);

void main() {
  for (final (name, width, height) in [
    ('wide', 1200, 300),
    ('tall', 300, 1200),
  ]) {
    testWidgets('a $name photo is shown whole (contain), inside the screen '
        'at its own ratio; no line under the header', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final bytes = fixtureImage(
        top: const Color(0xFF2266AA),
        bottom: const Color(0xFFEEBB88),
        width: width,
        height: height,
      ).bytes;
      debugNetworkImageHttpClientProvider = () => _Client(bytes);
      await pumpScreen(
        tester,
        StoryViewerScreen.list(stories: [_story(width, height)]),
        language: AppLanguage.ar,
      );
      final photo = find.byKey(StoryViewerScreen.photoKey);
      // Decode the photo outside the fake clock; no settle (the story's
      // 5 s bar would run out and close the viewer).
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(photo).image,
          tester.element(photo),
        ),
      );
      await tester.pump();
      expect(tester.widget<Image>(photo).fit, BoxFit.contain);
      final rect = tester.getRect(photo);
      final screen = Offset.zero & const Size(393, 852);
      // Whole: the drawn photo lies inside the screen, at its own ratio.
      expect(screen.contains(rect.topLeft), isTrue);
      expect(rect.right, lessThanOrEqualTo(393 + 0.01));
      expect(rect.bottom, lessThanOrEqualTo(852 + 0.01));
      expect(rect.width / rect.height, moreOrLessEquals(width / height));
      // It fills the limiting side of the viewer's area.
      final area = tester.getSize(
        find.ancestor(of: photo, matching: find.byType(Center)).first,
      );
      if (width > height) {
        expect(rect.width, moreOrLessEquals(area.width));
      } else {
        expect(rect.height, moreOrLessEquals(area.height));
      }
      // No clipping or transform between the screen and the photo.
      expect(
        find.ancestor(of: photo, matching: find.byType(ClipRect)),
        findsNothing,
      );
      expect(
        find.ancestor(of: photo, matching: find.byType(FittedBox)),
        findsNothing,
      );
      // «وازل الخط اسفل الايقونات»: no divider in the viewer.
      expect(find.byType(Divider), findsNothing);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
