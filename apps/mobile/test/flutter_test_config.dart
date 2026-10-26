// Global test setup: the debug previews draw generated art only, so widget
// tests and goldens do not depend on asynchronous asset decoding. The photo
// path is covered by test/features/debug/preview_photo_test.dart, which
// turns it back on. Post visibility is reported without delay.

import 'dart:async';

import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:visibility_detector/visibility_detector.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PreviewPhoto.enabled = false;
  KabsoBattleEmoji.enabled = false;
  KabsoProfileHeaderArt.animate = false;
  KabsoPkBar.enabled = false;
  // Visibility (post views) is reported at once instead of on a timer, so
  // no timer is left pending at the end of a test (the package's advice).
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await testMain();
}
