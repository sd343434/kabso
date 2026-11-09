// Global test setup: the debug previews draw generated art only, so widget
// tests and goldens do not depend on asynchronous asset decoding. The photo
// path is covered by test/features/debug/preview_photo_test.dart, which
// turns it back on. Post visibility is reported without delay.

import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_art.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_mic_effect.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seat_fx.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_rocket_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/push/notification_sounds.dart';
import 'package:kabso_live/features/push/push_messaging.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:visibility_detector/visibility_detector.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PreviewPhoto.enabled = false;
  // D333: no automatic upload retries unless a test sets the waits.
  ComposeController.retryDelays = const [];
  KabsoBattleEmoji.enabled = false;
  KGiftEffect.animate = false;
  // D272b: no art read ahead as gifts arrive (no downloads in tests).
  LiveGiftEffects.prefetchArt = false;
  // D145d: the MAX X orb's endless motion, and its sounds (no audio plugin).
  MaxXOrb.animate = false;
  AudioplayersMaxXSounds.enabled = false;
  // D283: the team frame's window from its constants (no async measurement).
  KabsoTeamFrameWindow.enabled = false;
  // D154: the quips' sounds (no audio plugin in tests).
  AudioplayersQuipAudio.enabled = false;
  KabsoProfileHeaderArt.animate = false;
  // D252: the VIP badge / perk SVGA — tests show the still.
  VipAnimatedArt.animationsEnabled = false;
  VipSvga.enabled = false;
  CpRisingHearts.animate = false;
  CpPairFx.animate = false;
  CpMicEffect.animate = false;
  KabsoPkBar.enabled = false;
  // D195: the PK countdowns' one-second rebuilds (frames would never settle).
  LivePkStage.ticks = false;
  // D199: the owner's PK bar and banners hold one moment (frames settle;
  // their own tests play them).
  PkBattleBar.debugTimeMs = 1200;
  PkPowerBanner.debugTimeMs = 1200;
  // D144a: the permission channel has no handler in tests.
  DeviceLivePermissions.enabled = false;
  // D152: no Firebase, no audio plugin, no permission channel in tests
  // (push tests override the providers with fakes).
  FirebasePushMessaging.enabled = false;
  AudioplayersNotificationSounds.enabled = false;
  DevicePushPermissions.enabled = false;
  KLiveEqualizer.animate = false;
  // D233: the hub cards' rocket frame turns forever.
  KBoostFrame.animate = false;
  // D216: the interruption arc turns and the quip art loops forever.
  KLiveInterruption.animate = false;
  LiveQuipBadge.animate = false;
  // D146: the special-ID badge's light sweep loops; never in tests.
  KSpecialUsername.motion = false;
  // Visibility (post views) is reported at once instead of on a timer, so
  // no timer is left pending at the end of a test (the package's advice).
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await testMain();
}
