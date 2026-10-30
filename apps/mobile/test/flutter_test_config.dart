// Global test setup: the debug previews draw generated art only, so widget
// tests and goldens do not depend on asynchronous asset decoding. The photo
// path is covered by test/features/debug/preview_photo_test.dart, which
// turns it back on. Post visibility is reported without delay.

import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_art.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_mic_effect.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seat_fx.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/push/notification_sounds.dart';
import 'package:kabso_live/features/push/push_messaging.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:visibility_detector/visibility_detector.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PreviewPhoto.enabled = false;
  KabsoBattleEmoji.enabled = false;
  KGiftEffect.animate = false;
  // D145d: the MAX X orb's endless motion, and its sounds (no audio plugin).
  MaxXOrb.animate = false;
  AudioplayersMaxXSounds.enabled = false;
  // D154: the quips' sounds (no audio plugin in tests).
  AudioplayersQuipAudio.enabled = false;
  KabsoProfileHeaderArt.animate = false;
  CpRisingHearts.animate = false;
  CpPairFx.animate = false;
  CpMicEffect.animate = false;
  KabsoPkBar.enabled = false;
  // D144a: the permission channel has no handler in tests.
  DeviceLivePermissions.enabled = false;
  // D152: no Firebase, no audio plugin, no permission channel in tests
  // (push tests override the providers with fakes).
  FirebasePushMessaging.enabled = false;
  AudioplayersNotificationSounds.enabled = false;
  DevicePushPermissions.enabled = false;
  KLiveEqualizer.animate = false;
  // D146: the special-ID badge's light sweep loops; never in tests.
  KSpecialUsername.motion = false;
  // Visibility (post views) is reported at once instead of on a timer, so
  // no timer is left pending at the end of a test (the package's advice).
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await testMain();
}
