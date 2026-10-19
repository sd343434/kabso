// Global test setup: the debug previews draw generated art only, so widget
// tests and goldens do not depend on asynchronous asset decoding. The photo
// path is covered by test/features/debug/preview_photo_test.dart, which
// turns it back on.

import 'dart:async';

import 'package:kabso_live/features/debug/preview_photo.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PreviewPhoto.enabled = false;
  await testMain();
}
