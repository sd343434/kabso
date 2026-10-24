// CP-015 (D98): "Edit" on the live cover of the go-live room card — choose a
// photo (uploaded as a LIVE_COVER, then PUT /me/live-cover), remove it, and
// the honest failure while uploads are off.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_cover_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_media_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Records the cover calls (tests only).
class _FakeCovers implements LiveCoverRepository {
  final List<String> calls = [];

  @override
  Future<String> setCover(String mediaId) async {
    calls.add('set:$mediaId');
    return 'https://media.example.test/media/$mediaId/640.webp';
  }

  @override
  Future<void> removeCover() async => calls.add('remove');
}

/// Signed in as [user] without restoring anything.
class _SignedIn extends SessionController {
  new(this.user);

  final User user;

  @override
  AuthState build() => Authenticated(user);
}

const _uploadsOff = ServerFailure(
  code: ErrorCode.mediaUploadsUnavailable,
  rawCode: 'MEDIA_UPLOADS_UNAVAILABLE',
  debugMessage: 'x',
  statusCode: 503,
);

Future<(_FakeCovers, FakeMediaRepository, FakePhotoPicker, ProviderContainer)>
_pump(WidgetTester tester, {String? cover}) async {
  final covers = _FakeCovers();
  final media = FakeMediaRepository();
  final picker = FakePhotoPicker([jpegBytes]);
  await pumpScreen(
    tester,
    const Scaffold(
      body: Center(
        child: LiveCoverPicture(
          hostName: 'Layla',
          hostAvatarUrl: null,
          enabled: true,
        ),
      ),
    ),
    overrides: [
      sessionControllerProvider.overrideWith(
        () =>
            _SignedIn(testUser().copyWith(canHost: true, liveCoverUrl: cover)),
      ),
      liveCoverRepositoryProvider.overrideWithValue(covers),
      mediaRepositoryProvider.overrideWithValue(media),
      photoPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveCoverPicture)),
  );
  return (covers, media, picker, container);
}

String? _coverOf(ProviderContainer c) =>
    c.read(currentUserProvider)?.liveCoverUrl;

String? _shownUrl(WidgetTester tester) {
  final images = tester.widgetList<Image>(
    find.descendant(
      of: find.byKey(LiveCoverPicture.pictureKey),
      matching: find.byType(Image),
    ),
  );
  if (images.isEmpty) return null;
  return (images.first.image as NetworkImage).url;
}

void main() {
  testWidgets('shows Edit on the picture; choosing a photo uploads a '
      'LIVE_COVER, sets it and shows it at once', (tester) async {
    final (covers, media, picker, container) = await _pump(tester);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit the live cover'), findsOneWidget);
    expect(_shownUrl(tester), isNull);

    await tester.tap(find.byKey(LiveCoverPicture.pictureKey));
    await tester.pumpAndSettle();
    expect(find.text('Live cover'), findsOneWidget);
    // No cover yet: nothing to remove.
    expect(find.byKey(LiveCoverPicture.removeKey), findsNothing);

    await tester.tap(find.byKey(LiveCoverPicture.chooseKey));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(media.coverUploads, 1);
    expect(covers.calls, ['set:a1']);
    const url = 'https://media.example.test/media/a1/640.webp';
    expect(_coverOf(container), url);
    expect(_shownUrl(tester), url);
    expect(find.text('Live cover updated.'), findsOneWidget);
  });

  testWidgets('Remove goes back to the avatar', (tester) async {
    const old = 'https://media.example.test/media/old/640.webp';
    final (covers, media, _, container) = await _pump(tester, cover: old);
    expect(_shownUrl(tester), old);

    await tester.tap(find.byKey(LiveCoverPicture.pictureKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCoverPicture.removeKey));
    await tester.pumpAndSettle();
    expect(covers.calls, ['remove']);
    expect(media.coverUploads, 0);
    expect(_coverOf(container), isNull);
    expect(_shownUrl(tester), isNull);
    expect(find.text('Cover removed; your picture is shown.'), findsOneWidget);
  });

  testWidgets('uploads off (503): says so and keeps the picture', (
    tester,
  ) async {
    const old = 'https://media.example.test/media/old/640.webp';
    final (covers, media, _, container) = await _pump(tester, cover: old);
    media.failWith = _uploadsOff;

    await tester.tap(find.byKey(LiveCoverPicture.pictureKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCoverPicture.chooseKey));
    await tester.pumpAndSettle();
    expect(covers.calls, isEmpty);
    expect(_coverOf(container), old);
    expect(_shownUrl(tester), old);
    expect(
      find.text("Photo uploads aren't available right now."),
      findsOneWidget,
    );
    // Not busy any more: the picture can be tapped again.
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('an unsupported photo is refused on the device', (tester) async {
    final (covers, media, picker, _) = await _pump(tester);
    picker.next = [heicBytes];

    await tester.tap(find.byKey(LiveCoverPicture.pictureKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveCoverPicture.chooseKey));
    await tester.pumpAndSettle();
    expect(media.uploads, isEmpty);
    expect(covers.calls, isEmpty);
    expect(
      find.text("This photo format isn't supported. Use JPEG, PNG or WebP."),
      findsOneWidget,
    );
  });
}
