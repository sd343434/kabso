import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/features/stories/presentation/story_viewers_sheet.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry and timing of the story viewer.
abstract final class KStoryViewer {
  /// How long one photo stays before the next.
  static const Duration duration = Duration(seconds: 5);

  /// The share of the width, on the reading-start side, that goes back.
  static const double backZone = 0.3;

  /// D218 (the owner's reference, E at ≈0.81 px/dp, 393 dp wide assumed):
  /// 3 dp bars 4 dp apart, a 38 dp avatar with the name over the time (no
  /// line under it: owner «وازل الخط اسفل الايقونات»), and at the bottom a
  /// 44 dp «اكتب رسالة» pill with a heart and send (28 dp glyphs in 48 dp
  /// targets).
  static const double barHeight = 3;
  static const double barGap = 4;
  static const double avatar = 38;
  static const double replyHeight = 44;
  static const double replyBorder = 1.2;
  static const double replyIcon = 28;

  /// A downward fling faster than this closes the viewer.
  static const double closeVelocity = 400;
}

/// `/stories/:username` (CP-008): full-screen photo stories, one account
/// after another in tray order (or [stories] alone, from the archive).
///
/// - A tap on the reading-end side goes forward, on the start side back;
///   press and hold pauses; a downward swipe closes.
/// - Each photo stays [KStoryViewer.duration] once loaded; a story seen
///   for the first time is marked seen (`PUT /stories/{id}/seen`).
/// - Your own: who saw it (48 hours) and delete. Someone else's: report
///   and mute.
/// - An account whose stories are gone or no longer visible is skipped.
/// - D218 (the owner's reference): someone else's story has «اكتب رسالة…»,
///   a heart and send at the bottom; the reply and the heart («❤️») go to
///   the author as direct messages (`POST /dm/messages`, CONVENTIONS
///   §10.73.5); the story pauses while the field is in use. Your own keeps
///   who saw it, delete and (D218) the archive.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const new({required String this.username, super.key})
    : stories = null,
      start = 0;

  /// The archive: exactly [stories], starting at [start].
  const new list({required List<Story> this.stories, this.start = 0, super.key})
    : username = null;

  final String? username;
  final List<Story>? stories;
  final int start;

  static const viewerKey = Key('story.viewer');
  static const closeKey = Key('story.close');
  static const moreKey = Key('story.more');
  static const viewersKey = Key('story.viewers');
  static const deleteKey = Key('story.more.delete');
  static const reportKey = Key('story.more.report');
  static const muteKey = Key('story.more.mute');
  static const deleteConfirmKey = Key('story.delete.confirm');
  static const textKey = Key('story.text');
  static const archiveKey = Key('story.more.archive');
  static const replyFieldKey = Key('story.reply.field');
  static const replySendKey = Key('story.reply.send');
  static const heartKey = Key('story.reply.heart');
  static const photoKey = Key('story.photo');
  static Key storyKey(String id) => Key('story.$id');

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: KStoryViewer.duration,
  )..addStatusListener(_onStatus);

  /// The accounts to show, in order: the tray from the opened account on,
  /// fixed once the tray is known (a profile's account alone otherwise).
  List<String>? _fixedQueue;

  List<String> get _queue => _fixedQueue ?? [widget.username ?? ''];
  int _account = 0;

  /// -1 until an account's stories arrive: it then opens at its first
  /// unseen story. The archive opens at [StoryViewerScreen.start].
  late int _index = widget.stories != null ? widget.start : -1;
  bool _held = false;
  String? _started;
  final Set<String> _deleted = {};
  final Set<String> _markedSeen = {};

  void _fixQueue() {
    final username = widget.username;
    if (_fixedQueue != null || username == null) return;
    final load = ref.watch(homeStoriesProvider);
    if (load.isLoading && !load.hasValue) return;
    final tray = switch (load.value) {
      FeedItems(:final items) => [
        for (final s in items)
          if (s.hasStory && s.username != null) s.username!,
      ],
      _ => const <String>[],
    };
    final at = tray.indexOf(username);
    _fixedQueue = at < 0 ? [username] : tray.sublist(at);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _next();
  }

  List<Story>? get _stories {
    final fixed = widget.stories;
    if (fixed != null) {
      return [
        for (final s in fixed)
          if (!_deleted.contains(s.id)) s,
      ];
    }
    return switch (ref.read(userStoriesProvider(_queue[_account]))) {
      AsyncData(:final value) => [
        for (final s in value)
          if (!_deleted.contains(s.id)) s,
      ],
      _ => null,
    };
  }

  /// Leaves the viewer; the tray then shows what was seen.
  void _close() {
    if (widget.username != null) ref.invalidate(storyTrayProvider);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.reels);
    }
  }

  void _next() {
    final stories = _stories;
    if (stories != null && _index < stories.length - 1) {
      setState(() => _index++);
    } else if (_account < _queue.length - 1) {
      setState(() {
        _account++;
        _index = -1;
      });
    } else {
      _close();
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (_account > 0) {
      setState(() {
        _account--;
        _index = 0;
      });
    } else {
      _restart();
    }
  }

  void _restart() {
    _progress.value = 0;
    if (!_held) _progress.forward();
  }

  /// Starts [story] once: loads its photo, marks it seen, runs the bar.
  void _start(Story story) {
    if (_started == story.id) return;
    _started = story.id;
    _progress
      ..stop()
      ..value = 0;
    if (!story.isSelf && !story.viewerHasSeen && _markedSeen.add(story.id)) {
      // Best effort: a failed mark only leaves the ring unseen.
      unawaited(
        ref
            .read(storiesRepositoryProvider)
            .markSeen(story.id)
            .catchError((Object _) {}),
      );
    }
    unawaited(
      precacheImage(
        NetworkImage(story.media.url),
        context,
        onError: (_, _) {},
      ).whenComplete(() {
        if (mounted && _started == story.id && !_held) {
          _progress.forward();
        }
      }),
    );
  }

  void _hold(bool held) {
    _held = held;
    if (held) {
      _progress.stop();
    } else if (_started != null) {
      _progress.forward();
    }
  }

  /// Pauses while [task] (a sheet or a dialog) is open.
  Future<T> _paused<T>(Future<T> Function() task) async {
    _hold(true);
    try {
      return await task();
    } finally {
      if (mounted) _hold(false);
    }
  }

  Future<void> _more(Story story) async {
    final l10n = context.l10n;
    final choice = await _paused(
      () => showModalBottomSheet<Key>(
        context: context,
        useRootNavigator: true,
        builder: (sheet) {
          Widget item(Key key, IconData icon, String label, {Color? color}) =>
              ListTile(
                key: key,
                leading: Icon(icon, color: color),
                title: Text(label, style: TextStyle(color: color)),
                onTap: () => Navigator.of(sheet).pop(key),
              );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: story.isSelf
                  ? [
                      // D218: the owner's «الأرشيف» next to delete.
                      item(
                        StoryViewerScreen.archiveKey,
                        Icons.history_rounded,
                        l10n.storyArchiveTitle,
                      ),
                      item(
                        StoryViewerScreen.deleteKey,
                        Icons.delete_outline,
                        l10n.storyDelete,
                        color: sheet.palette.error,
                      ),
                    ]
                  : [
                      item(
                        StoryViewerScreen.reportKey,
                        Icons.flag_outlined,
                        l10n.storyReport,
                      ),
                      item(
                        StoryViewerScreen.muteKey,
                        Icons.volume_off_outlined,
                        l10n.safetyMuteUser(_name(story)),
                      ),
                    ],
            ),
          );
        },
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == StoryViewerScreen.archiveKey) {
      await _paused(() => context.push<void>(AppRoutes.storyArchive));
    } else if (choice == StoryViewerScreen.deleteKey) {
      await _delete(story);
    } else if (choice == StoryViewerScreen.reportKey) {
      await _report(story);
    } else if (choice == StoryViewerScreen.muteKey) {
      await _paused(
        () => muteUser(
          context,
          ref,
          username: story.author.username,
          name: _name(story),
        ),
      );
      if (!mounted) return;
      ref.invalidate(storyTrayProvider);
      _skipAccount();
    }
  }

  Future<void> _delete(Story story) async {
    final l10n = context.l10n;
    final ok = await _paused(
      () => showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.storyDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              key: StoryViewerScreen.deleteConfirmKey,
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.storyDelete),
            ),
          ],
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    try {
      await ref.read(storiesRepositoryProvider).deleteStory(story.id);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
      return;
    }
    if (!mounted) return;
    KSnack.success(context, l10n.storyDeleted);
    ref
      ..invalidate(storyTrayProvider)
      ..invalidate(storyArchiveProvider);
    final remaining = (_stories?.length ?? 1) - 1;
    setState(() {
      _deleted.add(story.id);
      _started = null;
      if (_index >= remaining) _index = remaining - 1;
    });
    if (remaining <= 0) _skipAccount();
  }

  Future<void> _report(Story story) async {
    final l10n = context.l10n;
    final reason = await _paused(
      () => pickReportReason(context, l10n.storyReportTitle),
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(storiesRepositoryProvider).reportStory(story.id, reason);
      if (mounted) KSnack.success(context, l10n.storyReported);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  void _skipAccount() {
    if (_account < _queue.length - 1) {
      setState(() {
        _account++;
        _index = -1;
        _started = null;
      });
    } else {
      _close();
    }
  }

  Future<void> _viewers(Story story) =>
      _paused(() => showStoryViewersSheet(context, story));

  static String _name(Story s) =>
      s.author.displayName.isEmpty ? s.author.username : s.author.displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _fixQueue();
    final fixed = widget.stories;
    final source = fixed != null
        ? AsyncData<List<Story>>(fixed)
        : ref.watch(userStoriesProvider(_queue[_account]));
    final stories = switch (source) {
      AsyncData() => _stories ?? const <Story>[],
      _ => null,
    };
    // An account that is gone, hidden or empty is skipped.
    if (fixed == null) {
      final skip = switch (source) {
        AsyncData() => stories!.isEmpty,
        AsyncError(:final error) => switch (toAppFailure(error)) {
          ServerFailure(code: ErrorCode.notFound) => true,
          _ => false,
        },
        _ => false,
      };
      if (skip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _skipAccount();
        });
      }
    }
    Story? story;
    if (stories != null && stories.isNotEmpty) {
      if (_index < 0) {
        // A new account opens at its first unseen story.
        final unseen = stories.indexWhere((s) => !s.viewerHasSeen);
        _index = unseen < 0 ? 0 : unseen;
      }
      _index = _index.clamp(0, stories.length - 1);
      story = stories[_index];
      final current = story;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start(current);
      });
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      key: StoryViewerScreen.viewerKey,
      backgroundColor: const Color(0xFF000000),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final w = MediaQuery.sizeOf(context).width;
          final fromStart = rtl ? w - d.localPosition.dx : d.localPosition.dx;
          fromStart < w * KStoryViewer.backZone ? _previous() : _next();
        },
        onLongPressStart: (_) => _hold(true),
        onLongPressEnd: (_) => _hold(false),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > KStoryViewer.closeVelocity) _close();
        },
        child: KTopSafeArea(
          bottom: true,
          child: switch (story) {
            final s? => _StoryPage(
              key: StoryViewerScreen.storyKey(s.id),
              story: s,
              count: stories!.length,
              index: _index,
              progress: _progress,
              onClose: _close,
              onMore: () => _more(s),
              onViewers: () => _viewers(s),
              reply: s.isSelf
                  ? null
                  : _StoryReplyBar(
                      key: ValueKey('story.reply.${s.author.username}'),
                      story: s,
                      onActive: _hold,
                    ),
            ),
            null => switch (source) {
              AsyncError(:final error) when stories == null => _Failure(
                message: failureMessage(l10n, toAppFailure(error)),
                onRetry: () =>
                    ref.invalidate(userStoriesProvider(_queue[_account])),
                onClose: _close,
              ),
              _ => const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFFFFF)),
              ),
            },
          },
        ),
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const new({
    required this.story,
    required this.count,
    required this.index,
    required this.progress,
    required this.onClose,
    required this.onMore,
    required this.onViewers,
    super.key,
    this.reply,
  });

  final Story story;
  final int count;
  final int index;
  final Animation<double> progress;
  final VoidCallback onClose;
  final VoidCallback onMore;
  final VoidCallback onViewers;

  /// D218: the reply bar under someone else's story.
  final Widget? reply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final name = story.author.displayName.isEmpty
        ? story.author.username
        : story.author.displayName;
    final when =
        KFormat.relative(
          story.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Owner (D218): «اجعل الصورة كاملة ولا تقص منها» — the whole photo,
        // never cropped (contain); the header and the reply bar only lie
        // over it on soft scrims.
        Center(
          child: Image.network(
            story.media.url,
            key: StoryViewerScreen.photoKey,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: l10n.storyPhotoOf(name),
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Color(0x99FFFFFF),
              size: 48,
            ),
          ),
        ),
        // Keeps the bars and the name readable on bright photos.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          top: KSpacing.sm,
          left: KSpacing.sm + 2,
          right: KSpacing.sm + 2,
          child: Column(
            children: [
              _Bars(count: count, index: index, progress: progress),
              const SizedBox(height: KSpacing.md),
              Row(
                children: [
                  ExcludeSemantics(
                    // D378 (STORY_RING): a member's own ring in the viewer.
                    child: VipStoryRing(
                      vip: story.author.vip,
                      outerSize: KStoryViewer.avatar,
                      stroke: KMetrics.stroke,
                      fallback: KAvatar(
                        name: name,
                        imageUrl: story.author.avatarUrl,
                        size: KStoryViewer.avatar - 2 * (KMetrics.stroke + 1),
                        ring: KAvatarRing.storyUnseen,
                      ),
                      child: KAvatar(
                        name: name,
                        imageUrl: story.author.avatarUrl,
                        size: KStoryViewer.avatar - 2 * (KMetrics.stroke + 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  // D218: the name over the time (D167: either may be long).
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            color: white,
                            fontWeight: FontWeight.w700,
                            shadows: KLiveColors.glassShadow,
                          ),
                        ),
                        Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: const Color(0xCCFFFFFF),
                            shadows: KLiveColors.glassShadow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: StoryViewerScreen.moreKey,
                    tooltip: l10n.storyMore,
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert_rounded, color: white),
                  ),
                  IconButton(
                    key: StoryViewerScreen.closeKey,
                    tooltip: l10n.storyClose,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: white),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Keeps the reply bar readable over a bright photo (a scrim, never
        // a band that hides the photo).
        if (reply != null)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x80000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: KSpacing.md,
          right: KSpacing.md,
          bottom: KSpacing.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (story.text.isNotEmpty)
                Container(
                  key: StoryViewerScreen.textKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                    vertical: KSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(KRadius.md),
                  ),
                  child: Text(
                    isolateHandles(story.text, mentions: story.mentions),
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: white),
                  ),
                ),
              if (story.isSelf) ...[
                const SizedBox(height: KSpacing.sm),
                TextButton.icon(
                  key: StoryViewerScreen.viewersKey,
                  onPressed: onViewers,
                  style: TextButton.styleFrom(foregroundColor: white),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(l10n.storyViewCount(story.viewCount ?? 0)),
                ),
              ],
              if (reply case final reply?) ...[
                const SizedBox(height: KSpacing.md),
                reply,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// D218: «اكتب رسالة…», a heart and send under someone else's story. The
/// text and the heart («❤️») go to the author as direct messages (§11.13);
/// the story is paused ([onActive]) while the field has focus.
class _StoryReplyBar extends ConsumerStatefulWidget {
  const new({required this.story, required this.onActive, super.key});

  final Story story;
  final ValueChanged<bool> onActive;

  @override
  ConsumerState<_StoryReplyBar> createState() => _StoryReplyBarState();
}

class _StoryReplyBarState extends ConsumerState<_StoryReplyBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  bool _hearted = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => widget.onActive(_focus.hasFocus));
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<bool> _send(String text) async {
    if (_sending) return false;
    setState(() => _sending = true);
    final l10n = context.l10n;
    try {
      await ref
          .read(dmRepositoryProvider)
          .send(
            widget.story.author.username,
            DmOutgoingText(text),
            clientId: _clientId(),
          );
      if (mounted) KSnack.success(context, l10n.storyReplySent);
      return true;
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _clientId() {
    final now = clock.now().microsecondsSinceEpoch;
    return 'story-$now';
  }

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (await _send(text) && mounted) {
      _text.clear();
      _focus.unfocus();
    }
  }

  Future<void> _heart() async {
    if (_hearted) return;
    if (await _send('\u2764\uFE0F') && mounted) {
      setState(() => _hearted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final name = widget.story.author.displayName.isEmpty
        ? widget.story.author.username
        : widget.story.author.displayName;
    final canSend = _text.text.trim().isNotEmpty && !_sending;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: KStoryViewer.replyHeight,
            child: TextField(
              key: StoryViewerScreen.replyFieldKey,
              controller: _text,
              focusNode: _focus,
              enabled: !_sending,
              maxLength: 1000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              style: t.body.copyWith(color: white),
              cursorColor: white,
              decoration: InputDecoration(
                counterText: '',
                hintText: l10n.storyReplyHint,
                hintStyle: t.body.copyWith(color: const Color(0xCCFFFFFF)),
                filled: true,
                fillColor: const Color(0x26000000),
                isDense: true,
                contentPadding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpacing.lg,
                  vertical: KSpacing.sm + 2,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  borderSide: const BorderSide(
                    color: Color(0xB3FFFFFF),
                    width: KStoryViewer.replyBorder,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  borderSide: const BorderSide(
                    color: Color(0x66FFFFFF),
                    width: KStoryViewer.replyBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  borderSide: const BorderSide(
                    color: white,
                    width: KStoryViewer.replyBorder,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: StoryViewerScreen.heartKey,
          tooltip: l10n.storyReact(name),
          isSelected: _hearted,
          onPressed: _sending ? null : _heart,
          icon: AppIcon(
            _hearted ? AppIcons.heartFilled : AppIcons.heart,
            size: KStoryViewer.replyIcon,
            color: _hearted ? KLiveColors.badge : white,
          ),
        ),
        IconButton(
          key: StoryViewerScreen.replySendKey,
          tooltip: l10n.storyReplySend,
          onPressed: canSend ? _sendText : null,
          icon: AppIcon(
            AppIcons.send,
            size: KStoryViewer.replyIcon,
            color: canSend ? white : const Color(0x99FFFFFF),
          ),
        ),
      ],
    );
  }
}

/// One bar per story: full before [index], filling at [index], empty after
/// (in reading order).
class _Bars extends StatelessWidget {
  const new({required this.count, required this.index, required this.progress});

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: KStoryViewer.barGap),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KStoryViewer.barHeight),
              child: SizedBox(
                height: KStoryViewer.barHeight,
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (_, _) => LinearProgressIndicator(
                    value: i < index
                        ? 1
                        : i == index
                        ? progress.value
                        : 0,
                    minHeight: KStoryViewer.barHeight,
                    backgroundColor: const Color(0x59FFFFFF),
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const new({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const white = Color(0xFFFFFFFF);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: white),
            ),
            const SizedBox(height: KSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: white),
              child: Text(l10n.actionRetry),
            ),
            TextButton(
              key: StoryViewerScreen.closeKey,
              onPressed: onClose,
              style: TextButton.styleFrom(foregroundColor: white),
              child: Text(l10n.storyClose),
            ),
          ],
        ),
      ),
    );
  }
}
