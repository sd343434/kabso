// D353 (owner, staging 8ddbbfb): «المستخدمين لا يمكنهم رفع/وضع صورة غلاف،
// يظهر خطأ». The own profile page's cover tap (D335) and «تعديل الملف»'s
// «صورة الغلاف» row both choose a picture, upload it as a `PROFILE_COVER`,
// `PUT /me/cover` it and show it at once — with no error.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../premium/premium_harness.dart' show FixedSession;

final AppLocalizations _en = l10nFor(AppLanguage.en);

class _FakeProfileEdit implements ProfileEditRepository {
  final List<String> calls = [];

  @override
  Future<String> setCover(String mediaId) async {
    calls.add('cover:$mediaId');
    return 'https://media.example.test/media/$mediaId/1080.webp';
  }

  @override
  Future<void> removeCover() async => calls.add('removeCover');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePicker implements AvatarPhotoPicker {
  new(this.bytes);

  final Uint8List? bytes;
  final List<AvatarSource> calls = [];

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    calls.add(source);
    // A real picker leaves the app for seconds: the frame goes on meanwhile.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return bytes;
  }
}

Future<Uint8List> _png(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 60, 20),
        Paint()..color = const Color(0xFF2266AA),
      );
      final image = await recorder.endRecording().toImage(60, 20);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

typedef _Harness = ({
  _FakeProfileEdit repo,
  FakeMediaRepository media,
  _FakePicker picker,
});

Future<_Harness> _pump(
  WidgetTester tester,
  Widget screen,
  Uint8List png,
) async {
  final user = testUser();
  final repo = _FakeProfileEdit();
  final media = FakeMediaRepository();
  final picker = _FakePicker(png);
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    screen,
    overrides: [
      sessionControllerProvider.overrideWith(() => FixedSession(user)),
      meProvider.overrideWith((ref) => user),
      profileStatsProvider.overrideWith((ref, _) => apiProfile(isSelf: true)),
      profileGridProvider.overrideWith(
        (ref, _) => const FeedUnavailable<ProfileGridItem>(),
      ),
      profileEditRepositoryProvider.overrideWithValue(repo),
      mediaRepositoryProvider.overrideWithValue(media),
      avatarPhotoPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.pumpAndSettle();
  return (repo: repo, media: media, picker: picker);
}

Future<void> _chooseFromLibrary(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(EditProfileScreen.coverLibraryKey));
  // The picker's delay, then the upload and the PUT.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('D353: the own profile page — a tap on the cover, «Photos»: '
      'uploaded as a PROFILE_COVER, PUT /me/cover, no error', (tester) async {
    final h = await _pump(tester, const ProfileScreen(), await _png(tester));
    await tester.tap(find.byKey(ProfileCoverHeader.coverButtonKey));
    await _chooseFromLibrary(tester);
    expect(h.picker.calls, [AvatarSource.library]);
    // Before D353: «Something unexpected happened» (UnmountedRefException).
    expect(find.text(_en.errorUnknown), findsNothing);
    expect(h.media.profileCoverUploads, hasLength(1));
    expect(h.media.profileCoverUploads.single, startsWith('image/png:'));
    expect(h.repo.calls, ['cover:cv1']);
    expect(find.text(_en.errorUnknown), findsNothing);
    expect(find.text(_en.profileEditCoverUpdated), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D353: «Edit profile» → «Cover photo» → «Photos»: uploaded, set, '
      'no error', (tester) async {
    final h = await _pump(
      tester,
      const EditProfileScreen(),
      await _png(tester),
    );
    await tester.ensureVisible(find.byKey(EditProfileScreen.coverKey));
    await tester.tap(find.byKey(EditProfileScreen.coverKey));
    await _chooseFromLibrary(tester);
    expect(h.repo.calls, ['cover:cv1']);
    expect(find.text(_en.errorUnknown), findsNothing);
    expect(find.text(_en.profileEditCoverUpdated), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
