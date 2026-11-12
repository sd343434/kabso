import 'dart:async';
import 'dart:ui' as ui;

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
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/features/stories/presentation/story_people_carousel.dart';
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

  /// D375 (owner «طبق التصميم ١٠٠٪», measured on the reference at
  /// 0.552 px/dp): the story fills the screen; thin 2 dp bars at the very
  /// top (4 dp under the status bar, 12 dp from the sides, 4 dp apart),
  /// then a 30 dp avatar centred ≈ 25 dp under them, the name (13 dp) and
  /// the time, ⋯ and ✕ (22 dp glyphs in 48 dp targets). No line under the
  /// header (owner «وازل الخط اسفل الايقونات»).
  static const double barTop = 4;
  static const double barInset = 12;
  static const double barHeight = 2;
  static const double barGap = 4;
  static const double headerTop = 1;
  static const double headerStart = 24;
  static const double headerEnd = 4;
  static const double avatar = 30;
  static const double nameSize = 13;
  static const double icon = 22;
  static const double iconTarget = KSizes.minTouchTarget;

  /// The blur of the photo's copy that fills the screen behind it.
  static const double backdropBlur = 30;

  /// D375: under the carousel (23 dp), one 14 dp line — the caption — at
  /// 28 dp from the start, then (your own story) who saw it in 11 dp; the
  /// ⋯ at the end. Its centre lands ≈ 30 dp above the home indicator, the
  /// carousel's centre ≈ 157 dp above it, as on the reference.
  static const double captionTop = 23;
  static const double captionStart = 28;
  static const double captionEnd = 2;
  static const double captionSize = 14;
  static const double metaHeight = 16;
  static const double metaIcon = 14;
  static const double metaSize = 11;

  /// The reply field (opened from the caption line).
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
/// - D375 (owner 2026-11-11): opened from the tray, the bottom shows the
///   people who have stories ([StoryPeopleCarousel], the whole tray in its
///   order, the current author centred); a tap or a swipe on someone jumps
///   to their stories. It shows on opening and on every change of person,
///   then fades out after [KStoryCarousel.autoHide]; touching the lower
///   area, a long press or typing a reply brings it back and keeps it up.
///   The story fills the screen; under the carousel, the caption line
///   (a tap opens the reply field), who saw it on your own, and a second ⋯.
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
  static const moreBottomKey = Key('story.more.bottom');

  /// D375: the caption line under the carousel; a tap opens the reply.
  static const replyOpenKey = Key('story.reply.open');

  /// D375: the carousel's fade (an [AnimatedOpacity]).
  static const carouselVisibilityKey = Key('story.carousel.visibility');
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

  /// The accounts to show, in order: D375, the whole tray (starting at the
  /// opened account), fixed once the tray is known (a profile's account
  /// alone otherwise).
  List<String>? _fixedQueue;

  List<String> get _queue => _fixedQueue ?? [widget.username ?? ''];
  int _account = 0;

  /// D375: the tray's people with stories (the carousel), when the opened
  /// account is in the tray; [_queue] then holds their usernames.
  List<FeedStoryData>? _people;

  /// Accounts whose every story has been seen here (their ring turns grey).
  final Set<String> _allSeen = {};

  /// D375: whether the carousel is up, and its fade-out timer.
  bool _carouselShown = true;
  Timer? _carouselTimer;

  /// A finger is down on the lower area.
  bool _touching = false;

  /// D375: the story whose reply field is open (from its caption line).
  String? _replyStory;

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
          if (s.hasStory && s.username != null) s,
      ],
      _ => const <FeedStoryData>[],
    };
    final at = tray.indexWhere((s) => s.username == username);
    if (at < 0) {
      _fixedQueue = [username];
      return;
    }
    // D375: the whole tray, from the opened account (the carousel shows
    // the people before it too, and going back reaches them).
    _people = tray;
    _fixedQueue = [for (final s in tray) s.username!];
    _account = at;
    _carouselLater();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  /// D375: the carousel stays up while something holds it: a finger on the
  /// lower area, a long press, a sheet, typing a reply, or a screen reader.
  bool get _carouselPinned =>
      _touching || _held || MediaQuery.accessibleNavigationOf(context);

  /// Shows the carousel and restarts its fade-out.
  void _revealCarousel() {
    if (!_carouselShown && mounted) setState(() => _carouselShown = true);
    _carouselLater();
  }

  /// Fades the carousel out after [KStoryCarousel.autoHide], unless pinned.
  void _carouselLater() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    if (_people == null || _carouselPinned) return;
    _carouselTimer = Timer(KStoryCarousel.autoHide, () {
      _carouselTimer = null;
      if (mounted && !_carouselPinned) {
        setState(() => _carouselShown = false);
      }
    });
  }

  void _touch(bool down) {
    _touching = down;
    if (down) {
      _carouselTimer?.cancel();
      if (!_carouselShown) setState(() => _carouselShown = true);
    } else {
      _carouselLater();
    }
  }

  /// Remembers that the current account is all seen before leaving it.
  void _leaving() {
    final stories = _stories;
    if (stories == null || stories.isEmpty) return;
    if (stories.every((s) => s.viewerHasSeen || _markedSeen.contains(s.id))) {
      _allSeen.add(_queue[_account]);
    }
  }

  /// Moves to the account at [account] (D375: the carousel shows again).
  void _toAccount(int account, {int index = -1}) {
    _leaving();
    setState(() {
      _account = account;
      _index = index;
    });
    _revealCarousel();
  }

  /// D375: a tap or a swipe on someone in the carousel.
  void _jumpTo(int account) {
    if (account == _account || account < 0 || account >= _queue.length) {
      return;
    }
    _toAccount(account);
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
      _toAccount(_account + 1);
    } else {
      _close();
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (_account > 0) {
      _toAccount(_account - 1, index: 0);
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
      // D375: pausing (or typing, or a sheet) brings the carousel back.
      _carouselTimer?.cancel();
      if (!_carouselShown && mounted) setState(() => _carouselShown = true);
    } else {
      if (_started != null) _progress.forward();
      _carouselLater();
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
      _toAccount(_account + 1);
      _started = null;
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
    final people = widget.stories == null ? _people : null;
    if (story?.id != _replyStory) _replyStory = null;
    final page = switch (story) {
      final s? => _StoryPage(
        key: StoryViewerScreen.storyKey(s.id),
        story: s,
        count: stories!.length,
        index: _index,
        progress: _progress,
        onClose: _close,
        onMore: () => _more(s),
      ),
      null => KTopSafeArea(
        bottom: true,
        child: switch (source) {
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
      ),
    };
    // D375: the carousel fades in and out (with a slight rise); with
    // reduced motion it shows and hides at once, without the slide.
    final fade = KMotion.of(context, KMotion.base);
    final still = fade == Duration.zero;
    final shown = _carouselShown;
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // D375: the story fills the screen edge to edge.
            page,
            // D375: a frosted fade rising from the bottom behind the
            // carousel and the caption; it comes and goes with them.
            if (people != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: KStoryCarousel.frostHeight,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: shown ? 1 : 0,
                    duration: fade,
                    curve: KMotion.standard,
                    child: const _Frost(),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                // Touching the lower area brings the carousel back and
                // keeps it up while the finger is down.
                child: Listener(
                  onPointerDown: (_) => _touch(true),
                  onPointerUp: (_) => _touch(false),
                  onPointerCancel: (_) => _touch(false),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (people != null)
                        // A tap on the lower area only brings the carousel
                        // back: it never turns the story.
                        GestureDetector(
                          key: const ValueKey('story.bottom.carousel'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _revealCarousel,
                          child: AnimatedSlide(
                            offset: shown || still
                                ? Offset.zero
                                : const Offset(0, 0.15),
                            duration: fade,
                            curve: KMotion.standard,
                            child: AnimatedOpacity(
                              key: StoryViewerScreen.carouselVisibilityKey,
                              opacity: shown ? 1 : 0,
                              duration: fade,
                              curve: KMotion.standard,
                              child: IgnorePointer(
                                ignoring: !shown,
                                child: StoryPeopleCarousel(
                                  people: people,
                                  current: _account,
                                  onSelect: _jumpTo,
                                  seen: (p) =>
                                      p.seen || _allSeen.contains(p.username),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (story case final s?)
                        Padding(
                          key: ValueKey('story.bottom.${s.id}'),
                          padding: const EdgeInsets.only(
                            top: KStoryViewer.captionTop,
                          ),
                          child: _replyStory == s.id
                              ? Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: KSpacing.md,
                                    end: KSpacing.xs,
                                  ),
                                  child: _StoryReplyBar(
                                    key: ValueKey(
                                      'story.reply.${s.author.username}',
                                    ),
                                    story: s,
                                    onActive: _hold,
                                    onDone: () =>
                                        setState(() => _replyStory = null),
                                  ),
                                )
                              : _StoryBottom(
                                  story: s,
                                  onReply: () =>
                                      setState(() => _replyStory = s.id),
                                  onViewers: () => _viewers(s),
                                  onMore: () => _more(s),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D375: the reference's frosted fade — the photo blurs more and more
/// towards the bottom under a light tint (no hard panel).
class _Frost extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, band) in KStoryCarousel.frostBands.indexed)
        Positioned(
          top: KStoryCarousel.frostHeight * band,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: KStoryCarousel.frostSigmas[i],
                sigmaY: KStoryCarousel.frostSigmas[i],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.45, 1],
            colors: [
              KStoryCarousel.frostClear,
              KStoryCarousel.frostMid,
              KStoryCarousel.frostBottom,
            ],
          ),
        ),
      ),
    ],
  );
}

/// D375 (the reference): under the carousel, one line — the story's text
/// (or, on someone else's story without text, «اكتب رسالة…») — then, on
/// your own story, who saw it; ⋯ at the end. A tap on someone else's line
/// opens the reply field (the reference has no field box).
class _StoryBottom extends StatelessWidget {
  const new({
    required this.story,
    required this.onReply,
    required this.onViewers,
    required this.onMore,
  });

  final Story story;
  final VoidCallback onReply;
  final VoidCallback onViewers;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final text = story.text.isEmpty
        ? null
        : isolateHandles(story.text, mentions: story.mentions);
    final Widget? line = switch ((text, story.isSelf)) {
      (final text?, _) => Text(
        text,
        key: StoryViewerScreen.textKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.body.copyWith(
          fontSize: KStoryViewer.captionSize,
          height: 1.4,
          color: white,
          shadows: KLiveColors.glassShadow,
        ),
      ),
      (null, false) => Text(
        l10n.storyReplyHint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.body.copyWith(
          fontSize: KStoryViewer.captionSize,
          height: 1.4,
          color: const Color(0xB3FFFFFF),
          shadows: KLiveColors.glassShadow,
        ),
      ),
      (null, true) => null,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: KStoryViewer.captionStart,
        end: KStoryViewer.captionEnd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (line != null)
                  if (story.isSelf)
                    line
                  else
                    Semantics(
                      button: true,
                      label: l10n.storyReplyHint,
                      excludeSemantics: text == null,
                      child: GestureDetector(
                        key: StoryViewerScreen.replyOpenKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: onReply,
                        child: line,
                      ),
                    ),
                const SizedBox(height: KSpacing.xxs),
                SizedBox(
                  height: KStoryViewer.metaHeight,
                  child: story.isSelf
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Semantics(
                            button: true,
                            child: GestureDetector(
                              key: StoryViewerScreen.viewersKey,
                              behavior: HitTestBehavior.opaque,
                              onTap: onViewers,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.visibility_outlined,
                                    size: KStoryViewer.metaIcon,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                  const SizedBox(width: KSpacing.xs),
                                  Text(
                                    l10n.storyViewCount(story.viewCount ?? 0),
                                    style: t.caption.copyWith(
                                      fontSize: KStoryViewer.metaSize,
                                      color: const Color(0xCCFFFFFF),
                                      shadows: KLiveColors.glassShadow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          // D375: the ⋯ menu (mute, report… or archive, delete).
          IconButton(
            key: StoryViewerScreen.moreBottomKey,
            tooltip: l10n.storyMore,
            onPressed: onMore,
            constraints: const BoxConstraints.tightFor(
              width: KStoryViewer.iconTarget,
              height: KStoryViewer.iconTarget,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: KStoryViewer.icon,
              color: white,
            ),
          ),
        ],
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
    super.key,
  });

  final Story story;
  final int count;
  final int index;
  final Animation<double> progress;
  final VoidCallback onClose;
  final VoidCallback onMore;

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
        // D375: edge to edge — the same photo, blurred, fills the screen
        // behind the whole photo, so there is no black frame.
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: KStoryViewer.backdropBlur,
              sigmaY: KStoryViewer.backdropBlur,
            ),
            child: Image.network(
              story.media.url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Owner (D218): «اجعل الصورة كاملة ولا تقص منها» — the whole photo,
        // never cropped (contain).
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
          height: 140,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        // Keeps the caption readable while the carousel is hidden.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x59000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        // D375 (the reference): thin bars at the very top, then a small
        // avatar, the name and the time, ⋯ and ✕, over the photo.
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: KStoryViewer.barTop),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KStoryViewer.barInset,
                  ),
                  child: _Bars(count: count, index: index, progress: progress),
                ),
                const SizedBox(height: KStoryViewer.headerTop),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: KStoryViewer.headerStart,
                    end: KStoryViewer.headerEnd,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        // D378 (STORY_RING): a member's own ring in the
                        // viewer; without the perk, D375's plain avatar.
                        child: VipStoryRing(
                          vip: story.author.vip,
                          outerSize: KStoryViewer.avatar,
                          stroke: KMetrics.stroke,
                          fallback: KAvatar(
                            name: name,
                            imageUrl: story.author.avatarUrl,
                            size: KStoryViewer.avatar,
                          ),
                          child: KAvatar(
                            name: name,
                            imageUrl: story.author.avatarUrl,
                            size:
                                KStoryViewer.avatar - 2 * (KMetrics.stroke + 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      // The name, then the time (D167: either may be long).
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            fontSize: KStoryViewer.nameSize,
                            color: white,
                            shadows: KLiveColors.glassShadow,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      Flexible(
                        child: Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: const Color(0xB3FFFFFF),
                            shadows: KLiveColors.glassShadow,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: StoryViewerScreen.moreKey,
                        tooltip: l10n.storyMore,
                        onPressed: onMore,
                        constraints: const BoxConstraints.tightFor(
                          width: KStoryViewer.iconTarget,
                          height: KStoryViewer.iconTarget,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          size: KStoryViewer.icon,
                          color: white,
                        ),
                      ),
                      IconButton(
                        key: StoryViewerScreen.closeKey,
                        tooltip: l10n.storyClose,
                        onPressed: onClose,
                        constraints: const BoxConstraints.tightFor(
                          width: KStoryViewer.iconTarget,
                          height: KStoryViewer.iconTarget,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: KStoryViewer.icon,
                          color: white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  const new({
    required this.story,
    required this.onActive,
    required this.onDone,
    super.key,
  });

  final Story story;
  final ValueChanged<bool> onActive;

  /// D375: the field closes (back to the caption line) once it loses focus
  /// empty or the reply is sent.
  final VoidCallback onDone;

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
    _focus.addListener(() {
      widget.onActive(_focus.hasFocus);
      if (!_focus.hasFocus && _text.text.trim().isEmpty && !_sending) {
        widget.onDone();
      }
    });
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
              autofocus: true,
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
