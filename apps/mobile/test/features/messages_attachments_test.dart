// D67: attaching a photo or video in a conversation. The chat preview shows
// what was picked from the device; the real chat keeps the button disabled
// (no upload or messaging API yet, CP-004).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/messages/attachments.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_dm_repository.dart';
import '../helpers/pump_app.dart';

class _Picker implements MediaAttachmentPicker {
  new(this.result, {this.fail = false});

  final PickedMedia? result;
  final bool fail;
  final sources = <AttachmentSource>[];

  @override
  Future<PickedMedia?> pick(AttachmentSource source) async {
    sources.add(source);
    if (fail) throw PlatformException(code: 'photo_access_denied');
    return result;
  }
}

const _photo = PickedMedia(path: 'test/fixtures/none.jpg', isVideo: false);
const _video = PickedMedia(path: 'test/fixtures/none.mp4', isVideo: true);

Future<_Picker> _pump(
  WidgetTester tester,
  _Picker picker, {
  List<MessagePreview> initial = const [],
}) async {
  tester.view
    ..physicalSize = const Size(414 * 3, 896 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    MessagesPreviewScreen(initialMessages: initial),
    overrides: [mediaAttachmentPickerProvider.overrideWithValue(picker)],
  );
  return picker;
}

Future<void> _attach(WidgetTester tester, AttachmentSource source) async {
  await tester.tap(find.byKey(MessagesPreviewScreen.attachKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AttachmentButton.sourceKey(source)));
  await tester.pumpAndSettle();
}

void main() {
  test('photo or video from the MIME type, else the extension', () {
    expect(
      PickedMedia.fromFile(XFile('a.bin', mimeType: 'video/mp4')).isVideo,
      isTrue,
    );
    expect(PickedMedia.fromFile(XFile('a.MOV')).isVideo, isTrue);
    expect(PickedMedia.fromFile(XFile('a.heic')).isVideo, isFalse);
    expect(
      PickedMedia.fromFile(XFile('a.jpg', mimeType: 'image/jpeg')).isVideo,
      isFalse,
    );
  });

  testWidgets('the sheet offers the library, a photo and a video', (
    tester,
  ) async {
    await _pump(tester, _Picker(null));
    final l10n = l10nFor(AppLanguage.en);
    await tester.tap(find.byKey(MessagesPreviewScreen.attachKey));
    await tester.pumpAndSettle();
    expect(find.text(l10n.attachGallery), findsOneWidget);
    expect(find.text(l10n.attachTakePhoto), findsOneWidget);
    expect(find.text(l10n.attachRecordVideo), findsOneWidget);
  });

  testWidgets('a picked photo appears at once in the conversation', (
    tester,
  ) async {
    final picker = await _pump(tester, _Picker(_photo));
    await _attach(tester, AttachmentSource.gallery);
    expect(picker.sources, [AttachmentSource.gallery]);
    final view = tester.widget<LocalMediaView>(find.byType(LocalMediaView));
    expect(view.media, _photo);
    expect(view.size, KMessagePreview.picture);
  });

  testWidgets('a recorded video appears as a playable tile', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = l10nFor(AppLanguage.en);
    final picker = await _pump(tester, _Picker(_video));
    await _attach(tester, AttachmentSource.cameraVideo);
    expect(picker.sources, [AttachmentSource.cameraVideo]);
    final view = tester.widget<LocalMediaView>(find.byType(LocalMediaView));
    expect(view.size, KMessagePreview.video);
    expect(find.bySemanticsLabel(l10n.attachPlayVideo), findsOneWidget);
    handle.dispose();
  });

  testWidgets('what was just attached scrolls into view below a long '
      'conversation', (tester) async {
    await _pump(
      tester,
      _Picker(_photo),
      initial: messagesPreviewFixture(ar: false),
    );
    await _attach(tester, AttachmentSource.gallery);
    final media = tester.getRect(find.byType(LocalMediaView));
    final composer = tester.getRect(find.byKey(MessagesPreviewScreen.inputKey));
    expect(media.bottom, lessThanOrEqualTo(composer.top));
    expect(media.top, greaterThanOrEqualTo(0));
  });

  testWidgets('cancelling adds nothing', (tester) async {
    await _pump(tester, _Picker(null));
    await _attach(tester, AttachmentSource.cameraPhoto);
    expect(find.byType(LocalMediaView), findsNothing);
  });

  testWidgets('refused access explains where to allow it', (tester) async {
    await _pump(tester, _Picker(null, fail: true));
    await _attach(tester, AttachmentSource.gallery);
    expect(find.text(l10nFor(AppLanguage.en).attachFailed), findsOneWidget);
    expect(find.byType(LocalMediaView), findsNothing);
  });

  testWidgets('D155: the real chat attaches photos only (no video)', (
    tester,
  ) async {
    // D165: the library itself shows photos only there.
    final picker = _Picker(null);
    await pumpScreen(
      tester,
      const ChatScreen(username: 'nour'),
      dmRepository: FakeDmRepository(),
      overrides: [mediaAttachmentPickerProvider.overrideWithValue(picker)],
    );
    await tester.pumpAndSettle();
    final attach = find.descendant(
      of: find.byKey(ChatScreen.attachKey),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(attach).onPressed, isNotNull);
    await tester.tap(attach);
    await tester.pumpAndSettle();
    expect(
      find.byKey(AttachmentButton.sourceKey(AttachmentSource.gallery)),
      findsOneWidget,
    );
    expect(
      find.byKey(AttachmentButton.sourceKey(AttachmentSource.cameraVideo)),
      findsNothing,
    );
    await tester.tap(
      find.byKey(AttachmentButton.sourceKey(AttachmentSource.gallery)),
    );
    await tester.pumpAndSettle();
    expect(picker.sources, [AttachmentSource.galleryPhoto]);
  });
}
