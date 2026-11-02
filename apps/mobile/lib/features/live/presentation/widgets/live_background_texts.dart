import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// The ongoing live notification's words in the person's language (D123).
LiveBackgroundTexts liveBackgroundTexts(AppLocalizations l10n) =>
    LiveBackgroundTexts(
      channelName: l10n.liveBgChannel,
      hostTitle: l10n.liveBgHostTitle,
      guestTitle: l10n.liveBgGuestTitle,
      listenerTitle: l10n.liveBgListenerTitle,
      body: l10n.liveBgBody,
      endLive: l10n.liveBgEnd,
      leave: l10n.liveBgLeave,
      // D213: a streamer host's notification toggles.
      micOff: l10n.streamerNotifMicOff,
      micOn: l10n.streamerNotifMicOn,
      cameraHide: l10n.streamerHideCamera,
      cameraShow: l10n.streamerShowCamera,
    );
