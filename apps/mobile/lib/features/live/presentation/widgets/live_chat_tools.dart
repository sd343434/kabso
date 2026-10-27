import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show photoPickerProvider;
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The live chat box with CP-017's tools (owner D104): above the field, a
/// row of small buttons — bullet message, voice clip, private messages and
/// picture, in this order from the start. Kabso's own (Material) icons.
///
/// - **Bullet:** toggles bullet mode; the hint gives the price (15 coins)
///   and the balance (`GET /wallet/me`); send posts a bullet (≤ 60).
/// - **Voice:** tap to record, tap again (or the send arrow) to send, ✕ to
///   throw away; it stops and sends by itself at 30 s. Hidden where clips
///   cannot be recorded (the web). The person's own live microphone
///   ([liveMic]: host or seated guest) is paused while the clip records
///   and restored after, whatever happens; a silent clip is not sent.
/// - **Messages:** [onMessages] (the Messages tab).
/// - **Picture:** one photo from the library.
///
/// Guests get no tools (they cannot write; the chat box is not offered to
/// them either).
class LiveRoomComposer extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmoji,
    required this.onMessages,
    this.liveMic,
    this.emoji = false,
    super.key,
  });

  /// D131 (ref 162): opened from 😊 — the emoji panel, no keyboard yet.
  final bool emoji;

  /// CP-017: the live's own microphone, paused while a voice clip records
  /// (null: no live media here).
  final LiveVoiceMic? liveMic;

  final String roomId;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Sends the field as a chat line (bullet mode off).
  final VoidCallback onSend;
  final ValueChanged<KabsoEmoji> onEmoji;

  /// Opens private messages.
  final VoidCallback onMessages;

  static const toolsKey = Key('liveChat.tools');
  static const bulletKey = Key('liveChat.tool.bullet');
  static const voiceKey = Key('liveChat.tool.voice');
  static const messagesKey = Key('liveChat.tool.messages');
  static const pictureKey = Key('liveChat.tool.picture');
  static const recordingKey = Key('liveChat.voice.recording');
  static const voiceCancelKey = Key('liveChat.voice.cancel');
  static const sendingKey = Key('liveChat.sending');
  static const micPausedKey = Key('liveChat.voice.livePaused');

  /// The longest voice clip (§10.19).
  static const maxVoice = Duration(seconds: 30);

  /// The longest bullet, in code points (§10.19).
  static const bulletMaxLength = 60;

  @override
  ConsumerState<LiveRoomComposer> createState() => _LiveRoomComposerState();
}

class _LiveRoomComposerState extends ConsumerState<LiveRoomComposer> {
  late final LiveVoiceRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(liveVoiceRecorderProvider)();
  }

  bool _bullet = false;
  bool _sendingBullet = false;
  bool _recording = false;
  bool _starting = false;
  bool _uploading = false;

  /// The live microphone was paused for this clip (CP-017).
  bool _micPaused = false;
  int _seconds = 0;
  Timer? _tick;
  Timer? _limit;

  @override
  void dispose() {
    _stopTimers();
    // A clip being recorded when the box closes is thrown away, then the
    // live microphone comes back.
    final paused = _micPaused;
    final mic = widget.liveMic;
    _micPaused = false;
    unawaited(
      _recorder
          .dispose()
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() {
            if (paused && mic != null) unawaited(_resume(mic));
          }),
    );
    super.dispose();
  }

  static Future<void> _resume(LiveVoiceMic mic) async {
    try {
      await mic.resumeAfterClip();
    } on Object {
      // Nothing more to do; the mic button still works.
    }
  }

  /// Gives the live microphone back after a clip (stop, cancel, failure).
  Future<void> _restoreMic() async {
    final mic = widget.liveMic;
    if (!_micPaused || mic == null) return;
    _micPaused = false;
    if (mounted) setState(() {});
    await _resume(mic);
  }

  void _stopTimers() {
    _tick?.cancel();
    _limit?.cancel();
    _tick = null;
    _limit = null;
  }

  LiveChatController get _chat =>
      ref.read(liveChatProvider(widget.roomId).notifier);

  void _toggleBullet() {
    setState(() => _bullet = !_bullet);
    if (!_bullet) return;
    // A bullet is at most 60 code points.
    final text = widget.controller.text;
    if (text.runes.length > LiveRoomComposer.bulletMaxLength) {
      widget.controller.text = String.fromCharCodes(
        text.runes.take(LiveRoomComposer.bulletMaxLength),
      );
    }
    // A fresh balance each time bullet mode opens.
    ref.invalidate(liveCoinsProvider);
  }

  Future<void> _sendBullet() async {
    final l10n = context.l10n;
    final text = widget.controller.text.trim();
    if (text.isEmpty || _sendingBullet) return;
    setState(() => _sendingBullet = true);
    final failure = await _chat.sendBullet(text);
    if (!mounted) return;
    setState(() => _sendingBullet = false);
    if (failure == null) {
      widget.controller.clear();
      KSnack.success(context, l10n.liveBulletSent);
    } else {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  Future<void> _toggleVoice() async {
    if (_recording) {
      await _stopAndSend();
      return;
    }
    if (_uploading || _starting) return;
    final l10n = context.l10n;
    _starting = true;
    try {
      // On Android the live's own capture and the clip recorder cannot both
      // hear the microphone: the live microphone is paused first, or no
      // clip (it would be silence).
      final mic = widget.liveMic;
      if (mic != null) {
        try {
          _micPaused = await mic.pauseForClip();
        } on Object {
          if (mounted) KSnack.error(context, l10n.liveVoiceLiveMicBusy);
          return;
        }
      }
      try {
        await _recorder.start();
      } on LiveVoiceException catch (e) {
        await _restoreMic();
        if (mounted) {
          KSnack.error(
            context,
            e.problem == LiveVoiceProblem.denied
                ? l10n.liveVoiceDenied
                : l10n.liveVoiceUnavailable,
          );
        }
        return;
      }
    } finally {
      _starting = false;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    // 30 s at most: it stops and sends by itself.
    _limit = Timer(LiveRoomComposer.maxVoice, () => unawaited(_stopAndSend()));
  }

  Future<void> _cancelVoice() async {
    if (!_recording) return;
    _stopTimers();
    setState(() => _recording = false);
    try {
      await _recorder.cancel();
    } finally {
      await _restoreMic();
    }
  }

  Future<void> _stopAndSend() async {
    if (!_recording) return;
    final l10n = context.l10n;
    _stopTimers();
    setState(() {
      _recording = false;
      _uploading = true;
    });
    try {
      final LiveVoiceClip? clip;
      try {
        clip = await _recorder.stop();
      } on Object {
        if (mounted) KSnack.error(context, l10n.liveVoiceUnavailable);
        return;
      } finally {
        // The recorder let go of the microphone: the live gets it back
        // before the upload.
        await _restoreMic();
      }
      if (!mounted) return;
      final bytes = clip?.bytes;
      if (clip == null || bytes == null || bytes.isEmpty) {
        KSnack.error(context, l10n.liveVoiceUnavailable);
        return;
      }
      // Silence (a microphone that delivered nothing) is not sent.
      if (clip.silent) {
        KSnack.error(context, l10n.liveVoiceSilent);
        return;
      }
      if (bytes.length > maxVoiceBytes) {
        KSnack.error(context, l10n.liveVoiceTooLarge);
        return;
      }
      await _send(bytes, 'audio/mp4', LiveChatKind.voice);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPicture() async {
    if (_uploading || _recording) return;
    final l10n = context.l10n;
    try {
      final picked = await ref.read(photoPickerProvider).pickPhotos(1);
      if (!mounted || picked.isEmpty) return;
      final bytes = picked.first;
      final type = sniffImageType(bytes);
      if (type == null) {
        KSnack.error(context, l10n.createPhotoUnsupported);
        return;
      }
      if (bytes.length > maxPhotoBytes) {
        KSnack.error(context, l10n.createPhotoTooLarge);
        return;
      }
      setState(() => _uploading = true);
      try {
        await _send(bytes, type, LiveChatKind.image);
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    }
  }

  Future<void> _send(
    Uint8List bytes,
    String contentType,
    LiveChatKind kind,
  ) async {
    final l10n = context.l10n;
    final failure = await _chat.uploadAndSend(bytes, contentType, kind: kind);
    if (failure != null && mounted) {
      // Uploads off on the server (503 MEDIA_UPLOADS_UNAVAILABLE): a voice
      // clip says voice messages, not "photo uploads".
      KSnack.error(
        context,
        kind == LiveChatKind.voice &&
                failure.code == ErrorCode.mediaUploadsUnavailable
            ? l10n.liveVoiceUploadsUnavailable
            : failureMessage(l10n, failure),
      );
    }
  }

  void _onSend() {
    if (_recording) {
      unawaited(_stopAndSend());
    } else if (_uploading) {
      return;
    } else if (_bullet) {
      unawaited(_sendBullet());
    } else {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final signedIn = ref.watch(currentUserProvider) != null;
    final String hint;
    if (_bullet) {
      final coins = ref.watch(liveCoinsProvider).value;
      hint = coins == null
          ? l10n.liveBulletHintNoBalance
          : l10n.liveBulletHint(KFormat.grouped(coins));
    } else {
      hint = l10n.goLiveChatHint;
    }
    return LiveChatComposer(
      controller: widget.controller,
      focusNode: widget.focusNode,
      hint: hint,
      sendLabel: _recording ? l10n.liveVoiceSend : l10n.goLiveChatSend,
      onSend: _onSend,
      onEmoji: widget.onEmoji,
      maxLength: _bullet ? LiveRoomComposer.bulletMaxLength : 200,
      accent: _bullet,
      startWithEmoji: widget.emoji,
      tools: signedIn ? _tools(l10n) : null,
      replaceField: _recording
          ? _recordingBar(l10n)
          : _uploading
          ? _sendingBar(l10n)
          : null,
    );
  }

  Widget _tools(AppLocalizations l10n) => SizedBox(
    key: LiveRoomComposer.toolsKey,
    height: 32,
    child: Row(
      children: [
        _ToolButton(
          targetKey: LiveRoomComposer.bulletKey,
          icon: Icons.text_fields_rounded,
          label: l10n.liveBulletToggle,
          active: _bullet,
          toggle: true,
          onTap: _toggleBullet,
        ),
        if (_recorder.supported)
          _ToolButton(
            targetKey: LiveRoomComposer.voiceKey,
            icon: _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
            label: _recording ? l10n.liveVoiceSend : l10n.liveVoiceRecord,
            active: _recording,
            danger: _recording,
            onTap: () => unawaited(_toggleVoice()),
          ),
        _ToolButton(
          targetKey: LiveRoomComposer.messagesKey,
          icon: Icons.mail_outline_rounded,
          label: l10n.liveChatPrivateMessages,
          onTap: widget.onMessages,
        ),
        _ToolButton(
          targetKey: LiveRoomComposer.pictureKey,
          icon: Icons.image_outlined,
          label: l10n.liveChatPicture,
          onTap: () => unawaited(_pickPicture()),
        ),
        // CP-017: the person's live microphone is paused for the clip.
        if (_recording && _micPaused)
          Expanded(
            child: Row(
              key: LiveRoomComposer.micPausedKey,
              children: [
                const Icon(
                  Icons.mic_off_rounded,
                  size: 14,
                  color: LiveChatComposer.hintInk,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.liveVoiceLiveMicPaused,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.caption.copyWith(
                      fontSize: 11,
                      height: 1.2,
                      color: LiveChatComposer.hintInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _recordingBar(AppLocalizations l10n) {
    final styles = context.textStyles;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _ToolButton.dangerColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.liveVoiceRecording(
              KFormat.countdown(Duration(seconds: _seconds)),
            ),
            key: LiveRoomComposer.recordingKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.body.copyWith(color: LiveChatComposer.ink),
          ),
        ),
        Semantics(
          button: true,
          label: l10n.liveVoiceCancel,
          onTap: () => unawaited(_cancelVoice()),
          excludeSemantics: true,
          child: GestureDetector(
            key: LiveRoomComposer.voiceCancelKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_cancelVoice()),
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: LiveChatComposer.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sendingBar(AppLocalizations l10n) => Row(
    key: LiveRoomComposer.sendingKey,
    children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: LiveChatComposer.sendOn,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          l10n.liveChatSending,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.body.copyWith(
            color: LiveChatComposer.hintInk,
          ),
        ),
      ),
    ],
  );
}

/// A small round tool above the chat field (32 pt, 8 pt apart).
class _ToolButton extends StatelessWidget {
  const new({
    required this.targetKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.toggle = false,
    this.danger = false,
  });

  static const dangerColor = Color(0xFFFF3B5C);

  /// On the tap target, inside the button's semantics node.
  final Key targetKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  /// Reads as a switch (on / off) to screen readers.
  final bool toggle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = !active
        ? LiveChatComposer.field
        : danger
        ? dangerColor
        : LiveChatComposer.sendOn;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        toggled: toggle ? active : null,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            key: targetKey,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: active ? KAudioRoom.text : LiveChatComposer.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
