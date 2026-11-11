import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/media/inline_video.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/announcement_label.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Input for one reel (a short vertical video). Production builds it from
/// the reels API (`feedReelOf`, v1.41-social, D162) with a [postId] and a
/// [videoUrl], which plays while the reel is the current page (muted at
/// first; tap pauses, the speaker unmutes); the debug previews supply
/// fixtures without a video (their [cover] only) and without a [postId]
/// (their rail is display only).
@immutable
class FeedReelData {
  const new({
    required this.authorName,
    required this.postedAt,
    this.postId,
    this.videoUrl,
    this.aspect,
    this.isSelf = false,
    this.pendingModeration = false,
    this.announcement = false,
    this.authorAvatar,
    this.authorUsername,
    this.authorId,
    this.authorPremium = false,
    this.authorVerification,
    this.isFollowingAuthor,
    this.caption,
    this.cover,
    this.likes,
    this.comments,
    this.shares,
    this.liked = false,
    this.saved = false,
    this.hashtags = const {},
    this.mentions = const {},
    this.premiumMentions = const {},
    this.commentsOpen = true,
    this.giftCherries = 0,
    this.giftTo,
  });

  final String authorName;

  /// D293 (owner «نعم»): the author's verification badge, after the handle.
  final VerificationBadge? authorVerification;
  final ImageProvider? authorAvatar;

  /// The reel's post id (real reels only): like, comment, save and share
  /// work through the posts API only with it (D202).
  final String? postId;

  /// The video file (real reels only).
  final String? videoUrl;

  /// The video's width / height; a landscape video is shown whole.
  final double? aspect;

  /// The viewer posted it (no follow badge).
  final bool isSelf;

  /// Waiting for moderation: visible to its author only (CP-006 Q2).
  final bool pendingModeration;

  /// v1.72-live (D283): an official announcement reel of the Kabso Team.
  final bool announcement;

  /// The author's username, the key of the follow API
  /// (`PUT /users/{username}/follow`) and of their profile.
  final String? authorUsername;

  /// The author's id: their comments carry the "creator" label.
  final String? authorId;

  /// D158: a premium username shows without «@».
  final bool authorPremium;

  /// Whether the viewer follows the author; `null` when the source does not
  /// say (the reels API): the page then reads it from the author's profile
  /// (`GET /users/{username}`, D202) before offering Follow.
  final bool? isFollowingAuthor;

  final DateTime postedAt;
  final String? caption;

  /// The video's cover frame; `null` shows a dark surface.
  final ImageProvider? cover;

  /// Counts from the API (`likeCount`, `commentCount`, `shareCount`).
  final int? likes;
  final int? comments;
  final int? shares;

  /// The viewer's like and save (`viewerHasLiked`, `viewerHasSaved`).
  final bool liked;
  final bool saved;

  /// The caption's linked hashtags and mentions (lower case, no `#`/`@`):
  /// only these are tappable.
  final Set<String> hashtags;
  final Set<String> mentions;
  final Set<String> premiumMentions;

  /// Whether the viewer may comment (the sheet still opens to read).
  final bool commentsOpen;

  /// D372 «هدية الدعم»: the cherries the author earned from gifts on this
  /// reel (`Post.giftCherries`), shown under the comments when above 0.
  final int giftCherries;

  /// D372: the author to send a gift to (`Post.giftable`), or null.
  final UserSummary? giftTo;

  /// The handle shown at the bottom (`@layla`, a premium one bare), or the
  /// name when the source has no username.
  String get handle => switch (authorUsername) {
    final u? => authorPremium ? u : '@$u',
    null => authorName,
  };
}

/// Reels geometry (D202), measured from the owner's reference at 393 dp
/// (a third-party composite, kept out of git; layout and type scale only):
/// the author, caption and sound at the bottom start; the rail (author
/// photo with the follow badge, like, comment, save, share, the sound
/// disc) at the bottom end.
abstract final class KHomeReels {
  /// Side inset of the bottom block (avatar and caption start at 18).
  static const double contentInset = 18;

  /// The sound line's bottom above the screen's bottom.
  static const double contentBottom = 48;

  /// The rail: 56 wide, 12 from the end edge, its disc 36 above the bottom.
  static const double railWidth = 56;
  static const double railEnd = 12;
  static const double railBottom = 36;

  /// The author photo (2 dp white ring included) and the block it sits in
  /// (the badge hangs below it).
  static const double railAvatar = 46;
  static const double railAvatarBlock = 73;

  /// Rail actions: a 28 dp icon over a 12 sp label, 14 apart.
  static const double railIcon = 28;
  static const double railGap = 14;

  /// The spinning sound disc and its ring.
  static const double disc = 48;
  static const double discGap = 21;
  static const double discRing = 3;

  /// The follow badge under the rail photo, centred in a 48 dp target.
  static const double followBadge = 20;
  static const double followIcon = 14;

  /// The author photo of the bottom block and the gap to the handle.
  static const double authorAvatar = 34;
  static const double authorGap = 8;

  /// Caption: 14 sp, two lines before «المزيد»; gaps around it.
  static const double captionGap = 14;
  static const int captionLines = 2;
  static const double soundGap = 16;
  static const double soundIcon = 14;

  /// The double-tap heart.
  static const double burst = 96;

  /// D298: the progress line along the reel's bottom edge (above the
  /// bottom bar): 2 dp, 4 dp with a 12 dp thumb while scrubbing, in a
  /// 24 dp strip that takes the tap or drag.
  static const double progress = 2;
  static const double progressActive = 4;
  static const double progressThumb = 12;
  static const double progressHit = 24;

  /// D298: the progress line's unplayed part (white at 30 %).
  static const double progressTrackOpacity = 0.3;

  /// D298: the bottom scrim behind the author, caption and sound line:
  /// clear through the top half (the middle of the video stays untouched),
  /// then black rising to 85 % at the bottom edge (D202: 70 % from 55 %).
  static const List<double> bottomScrimStops = [0, 0.5, 0.68, 0.84, 1];
  static const List<double> bottomScrimOpacities = [0, 0, 0.25, 0.6, 0.85];
}

/// Full-screen vertical pager of reels: swipe up for the next one. Its
/// page survives mode and feed switches (they are kept alive), and its
/// [PageStorageKey] (unique per feed) restores it if the subtree is
/// rebuilt.
///
/// D162: only the current page's video plays; reaching the last pages asks
/// for more ([onNearEnd]).
class HomeReelsPager extends StatefulWidget {
  const new({
    required this.reels,
    required this.storageKey,
    this.onNearEnd,
    this.muteTop,
    super.key,
  });

  final List<FeedReelData> reels;
  final String storageKey;
  final VoidCallback? onNearEnd;

  /// D202: where the video's speaker button sits (below the page's header
  /// and chips); `null` keeps the video's default.
  final double? muteTop;

  @override
  State<HomeReelsPager> createState() => _HomeReelsPagerState();
}

class _HomeReelsPagerState extends State<HomeReelsPager> {
  int _current = 0;

  @override
  Widget build(BuildContext context) => PageView.builder(
    key: PageStorageKey<String>(widget.storageKey),
    scrollDirection: Axis.vertical,
    itemCount: widget.reels.length,
    onPageChanged: (i) {
      setState(() => _current = i);
      if (i >= widget.reels.length - 2) widget.onNearEnd?.call();
    },
    itemBuilder: (_, i) => HomeReelPage(
      key: ValueKey('home.reel.${widget.reels[i].postId ?? i}'),
      reel: widget.reels[i],
      active: i == _current,
      muteTop: widget.muteTop,
    ),
  );
}

/// D202: shares a reel through the system share sheet. Tests replace it.
abstract interface class ReelSharer {
  /// Opens the share sheet with [text]; `true` unless the person dismissed
  /// it (a platform that cannot tell counts as shared).
  Future<bool> share(String text, {Rect? origin});
}

class _SystemReelSharer implements ReelSharer {
  const new();

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

final reelSharerProvider = Provider<ReelSharer>(
  (ref) => const _SystemReelSharer(),
);

/// D202: whether the viewer follows a reel's author, read from the
/// author's public profile when the reels API does not say (one read per
/// author while the page is open).
typedef ReelAuthorFollow = ({bool following, bool requested, bool self});

final FutureProviderFamily<ReelAuthorFollow, String> reelAuthorFollowProvider =
    FutureProvider.autoDispose.family<ReelAuthorFollow, String>((
      ref,
      username,
    ) async {
      final profile = await ref
          .watch(profileRepositoryProvider)
          .getProfile(username);
      return (
        following: profile.isFollowing,
        requested: profile.followRequested,
        self: profile.isSelf,
      );
    });

/// One reel, edge to edge (D202): the video (tap pauses, double tap likes
/// with a heart), a bottom scrim, the author / caption / sound at the
/// bottom start and the rail at the bottom end. Like, comment, save and
/// share use the posts API (CONVENTIONS §11.2–§11.5, §11.15) when the reel
/// has a [FeedReelData.postId]; counts are the API's, updated at once and
/// put back if the call fails.
class HomeReelPage extends ConsumerStatefulWidget {
  const new({required this.reel, this.active = false, this.muteTop, super.key});

  final FeedReelData reel;

  /// The current page: its video plays.
  final bool active;

  /// See [HomeReelsPager.muteTop].
  final double? muteTop;

  static const pendingKey = Key('home.reel.pending');
  static const railKey = Key('home.reel.rail');
  static const countsKey = Key('home.reel.counts');
  static const authorKey = Key('home.reel.author');
  static const handleKey = Key('home.reel.handle');
  static const likeKey = Key('home.reel.like');
  static const commentKey = Key('home.reel.comment');

  /// D372: the gift counter (cherries) under the comments.
  static const giftCherriesKey = Key('home.reel.giftCherries');
  static const saveKey = Key('home.reel.save');
  static const shareKey = Key('home.reel.share');
  static const discKey = Key('home.reel.disc');
  static const soundKey = Key('home.reel.sound');
  static const captionKey = Key('home.reel.caption');
  static const moreKey = Key('home.reel.more');
  static const burstKey = Key('home.reel.burst');
  static const mediaKey = Key('home.reel.media');
  static const progressKey = Key('home.reel.progress');
  static const bottomScrimKey = Key('home.reel.bottomScrim');

  @override
  ConsumerState<HomeReelPage> createState() => _HomeReelPageState();
}

class _HomeReelPageState extends ConsumerState<HomeReelPage>
    with SingleTickerProviderStateMixin {
  late bool _liked = widget.reel.liked;
  late int? _likes = widget.reel.likes;
  late bool _saved = widget.reel.saved;
  late int? _comments = widget.reel.comments;
  late int _giftCherries = widget.reel.giftCherries;
  late int? _shares = widget.reel.shares;
  bool _liking = false;
  bool _saving = false;
  bool _sharing = false;

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  /// The sound disc's turns: it follows the playback position (one turn
  /// per [_discPeriod] of video), so it stops when the video stops.
  final ValueNotifier<double> _discTurns = ValueNotifier(0);
  Duration _lastPosition = Duration.zero;
  static const _discPeriod = Duration(seconds: 6);

  /// D298: the player's state for the progress line, and a way to seek.
  final ValueNotifier<InlineVideoState?> _playback = ValueNotifier(null);
  final InlineVideoHandle _video = InlineVideoHandle();
  InlineVideoState? _latest;

  void _onVideo(InlineVideoState state) {
    // A player can report while the tree builds (a page change pauses it
    // from didUpdateWidget): the line then follows after this frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _latest = state;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playback.value = _latest;
      });
    } else {
      _playback.value = _latest = state;
    }
    final step = state.position - _lastPosition;
    _lastPosition = state.position;
    if (state.playing && step > Duration.zero && step < _discPeriod) {
      _discTurns.value += step.inMilliseconds / _discPeriod.inMilliseconds;
    }
  }

  FeedReelData get reel => widget.reel;

  @override
  void dispose() {
    _burst.dispose();
    _discTurns.dispose();
    _playback.dispose();
    super.dispose();
  }

  PostsRepository get _posts => ref.read(postsRepositoryProvider);

  void _fail(Object e) {
    if (!mounted) return;
    KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
  }

  Future<void> _toggleLike() async {
    final id = reel.postId;
    if (id == null || _liking) return;
    final (before, beforeCount) = (_liked, _likes);
    final next = !_liked;
    setState(() {
      _liking = true;
      _liked = next;
      if (_likes case final n?) {
        _likes = math.max(0, n + (next ? 1 : -1));
      }
    });
    try {
      final state = await _posts.setLiked(id, liked: next);
      if (mounted) {
        setState(() {
          _liked = state.liked;
          _likes = state.likeCount ?? _likes;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _liked = before;
          _likes = beforeCount;
        });
      }
      _fail(e);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  /// A double tap on the video likes the reel (never unlikes) and shows the
  /// heart; with reduced motion the heart is skipped.
  void _doubleTap() {
    if (reel.postId == null) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _burst.forward(from: 0);
    }
    if (!_liked) unawaited(_toggleLike());
  }

  Future<void> _toggleSave() async {
    final id = reel.postId;
    if (id == null || _saving) return;
    final next = !_saved;
    setState(() {
      _saving = true;
      _saved = next;
    });
    try {
      final saved = await _posts.setSaved(id, saved: next);
      if (mounted) setState(() => _saved = saved);
    } on Object catch (e) {
      if (mounted) setState(() => _saved = !next);
      _fail(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openComments() async {
    final id = reel.postId;
    if (id == null) return;
    await showCommentsSheet(
      context,
      CommentsTarget(
        postId: id,
        commentCount: _comments ?? 0,
        authorId: reel.authorId,
        isSelf: reel.isSelf,
        commentsOpen: reel.commentsOpen,
        giftTo: reel.giftTo,
      ),
      onCount: (n) {
        if (mounted) setState(() => _comments = n);
      },
      onGiftCherries: (n) {
        if (mounted) setState(() => _giftCherries = n);
      },
    );
  }

  /// The system share sheet with the author and the caption's first line
  /// (no public reel link exists yet, CONVENTIONS §11.15); a share that was
  /// not dismissed is counted (`POST /posts/{id}/shares`, once a day).
  Future<void> _share(Rect? origin) async {
    final id = reel.postId;
    if (id == null || _sharing) return;
    final l10n = context.l10n;
    final caption = (reel.caption ?? '').trim().split('\n').first.trim();
    final text = caption.isEmpty
        ? l10n.reelsShareTextNoCaption(reel.handle)
        : l10n.reelsShareText(reel.handle, caption);
    setState(() => _sharing = true);
    try {
      final shared = await ref
          .read(reelSharerProvider)
          .share(text, origin: origin);
      if (!shared) return;
      final count = await _posts.countShare(id);
      if (mounted) setState(() => _shares = count);
    } on Object catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final interactive = reel.postId != null;
    final media = switch (reel.videoUrl) {
      final url? => InlineVideo(
        key: ValueKey('home.reel.video.${reel.postId ?? url}'),
        url: url,
        poster: reel.cover,
        autoplay: widget.active,
        muteOnTop: true,
        muteTop: widget.muteTop,
        onState: _onVideo,
        handle: _video,
        onDoubleTap: interactive ? _doubleTap : null,
        fit: (reel.aspect ?? 0) > 1 ? BoxFit.contain : BoxFit.cover,
      ),
      null => GestureDetector(
        onDoubleTap: interactive ? _doubleTap : null,
        child: _Cover(image: reel.cover),
      ),
    };
    return Semantics(
      container: true,
      label: l10n.homeReelBy(reel.authorName),
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(key: HomeReelPage.mediaKey, child: media),
          // D298: stronger at the bottom (the caption reads over a pale
          // video), still clear through the middle.
          IgnorePointer(
            child: DecoratedBox(
              key: HomeReelPage.bottomScrimKey,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: KHomeReels.bottomScrimStops,
                  colors: [
                    for (final o in KHomeReels.bottomScrimOpacities)
                      Color.fromRGBO(0, 0, 0, o),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (context, _) {
                  final t = _burst.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  final scale = t < 0.25 ? 0.6 + 1.6 * t : 1.0;
                  final opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3;
                  return Opacity(
                    key: HomeReelPage.burstKey,
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: AppIcon(
                        AppIcons.heartFilled,
                        size: KHomeReels.burst,
                        color: KPalette.dark.primaryText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          PositionedDirectional(
            start: KHomeReels.contentInset,
            end: KHomeReels.railEnd + KHomeReels.railWidth + KSpacing.sm,
            bottom: KHomeReels.contentBottom,
            child: _ReelInfo(reel: reel),
          ),
          PositionedDirectional(
            end: KHomeReels.railEnd,
            bottom: KHomeReels.railBottom,
            width: KHomeReels.railWidth,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: KMetrics.overlayMaxTextScale,
              child: Column(
                key: HomeReelPage.railKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RailAuthor(reel: reel),
                  if (interactive)
                    ..._actions(context)
                  else if (reel.likes != null &&
                      reel.comments != null &&
                      reel.shares != null)
                    _displayCounts(context),
                  const SizedBox(height: KHomeReels.discGap),
                  _MusicDisc(reel: reel, turns: _discTurns),
                ],
              ),
            ),
          ),
          if (reel.videoUrl != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ReelProgressBar(
                key: HomeReelPage.progressKey,
                playback: _playback,
                onSeek: _video.seekTo,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = context.l10n;
    final likes = _likes;
    final comments = _comments;
    final shares = _shares;
    String n(int v) => KFormat.compact(v, l10n);
    const gap = SizedBox(height: KHomeReels.railGap);
    return [
      _RailAction(
        key: HomeReelPage.likeKey,
        icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
        iconColor: _liked ? KPalette.dark.primaryText : null,
        label: likes == null ? null : n(likes),
        semanticLabel: _liked ? l10n.feedPostUnlike : l10n.feedPostLike,
        semanticValue: likes == null ? null : n(likes),
        toggled: _liked,
        onTap: _toggleLike,
      ),
      gap,
      _RailAction(
        key: HomeReelPage.commentKey,
        icon: AppIcons.comment,
        label: comments == null ? null : n(comments),
        semanticLabel: l10n.reelsCommentsLabel(n(comments ?? 0)),
        onTap: () => unawaited(_openComments()),
      ),
      // D372 «هدية الدعم»: the cherries earned from gifts on this reel.
      if (_giftCherries > 0) ...[
        gap,
        _RailCherries(
          key: HomeReelPage.giftCherriesKey,
          label: n(_giftCherries),
          semanticLabel: l10n.contentGiftCherriesLabel(n(_giftCherries)),
        ),
      ],
      gap,
      _RailAction(
        key: HomeReelPage.saveKey,
        icon: _saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
        label: _saved ? l10n.reelsSaved : l10n.reelsSave,
        semanticLabel: _saved ? l10n.feedPostUnsave : l10n.feedPostSave,
        toggled: _saved,
        onTap: _toggleSave,
      ),
      gap,
      Builder(
        builder: (button) => _RailAction(
          key: HomeReelPage.shareKey,
          icon: AppIcons.share,
          label: shares == null ? null : n(shares),
          semanticLabel: l10n.reelsShareLabel(n(shares ?? 0)),
          onTap: () {
            final box = button.findRenderObject() as RenderBox?;
            final origin = box == null || !box.hasSize
                ? null
                : box.localToGlobal(Offset.zero) & box.size;
            unawaited(_share(origin));
          },
        ),
      ),
    ];
  }

  /// A fixture without a post id: the counts are shown, not buttons.
  Widget _displayCounts(BuildContext context) {
    final l10n = context.l10n;
    final (likes, comments, shares) = (
      reel.likes!,
      reel.comments!,
      reel.shares!,
    );
    String n(int v) => KFormat.compact(v, l10n);
    const gap = SizedBox(height: KHomeReels.railGap);
    return Semantics(
      key: HomeReelPage.countsKey,
      container: true,
      label: l10n.feedPostCounts(n(likes), n(comments), n(shares)),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailAction(icon: AppIcons.heart, label: n(likes)),
          gap,
          _RailAction(icon: AppIcons.comment, label: n(comments)),
          gap,
          _RailAction(icon: AppIcons.share, label: n(shares)),
        ],
      ),
    );
  }
}

const _shadows = [
  Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1)),
  // D298: a tight shadow too, so white text keeps its edge on a pale video.
  Shadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(0, 1)),
];

/// D298 (owner: «لماذا لا يبان خط الفيديو؟»): the reel's playback progress,
/// a thin line along its bottom edge, full width, directly above the
/// bottom bar. The played part is white and grows from the reading start
/// (right to left in Arabic); the rest is white at 30 %. It shows once the
/// video has a known length. A tap jumps there; a horizontal drag scrubs
/// (a thicker line with a thumb) and seeks on release.
class ReelProgressBar extends StatefulWidget {
  const new({required this.playback, required this.onSeek, super.key});

  /// The player's state (position and duration).
  final ValueListenable<InlineVideoState?> playback;

  /// Jumps the player to a position.
  final Future<void> Function(Duration position) onSeek;

  @override
  State<ReelProgressBar> createState() => _ReelProgressBarState();
}

class _ReelProgressBarState extends State<ReelProgressBar> {
  /// The fraction under the finger while scrubbing, or of a seek on its
  /// way (so the line does not jump back before the player reports it).
  double? _scrub;
  bool _dragging = false;

  static const _step = Duration(seconds: 5);

  Future<void> _seek(double fraction, Duration duration) async {
    setState(() => _scrub = fraction);
    await widget.onSeek(
      Duration(microseconds: (fraction * duration.inMicroseconds).round()),
    );
    if (mounted && !_dragging) setState(() => _scrub = null);
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<InlineVideoState?>(
        valueListenable: widget.playback,
        builder: (context, state, _) {
          final duration = state?.duration ?? Duration.zero;
          if (state == null ||
              !state.initialized ||
              state.failed ||
              duration <= Duration.zero) {
            return const SizedBox.shrink();
          }
          final total = duration.inMicroseconds;
          final played =
              _scrub ?? (state.position.inMicroseconds / total).clamp(0.0, 1.0);
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final percent = (played * 100).round();
          double step(int sign) =>
              (played + sign * _step.inMicroseconds / total).clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              double at(Offset local) {
                final f = (local.dx / width).clamp(0.0, 1.0);
                return rtl ? 1 - f : f;
              }

              return Semantics(
                container: true,
                slider: true,
                label: context.l10n.reelsProgress,
                value: '$percent%',
                increasedValue: '${(step(1) * 100).round()}%',
                decreasedValue: '${(step(-1) * 100).round()}%',
                onIncrease: () => unawaited(_seek(step(1), duration)),
                onDecrease: () => unawaited(_seek(step(-1), duration)),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) =>
                      unawaited(_seek(at(d.localPosition), duration)),
                  onHorizontalDragStart: (d) => setState(() {
                    _dragging = true;
                    _scrub = at(d.localPosition);
                  }),
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _scrub = at(d.localPosition)),
                  onHorizontalDragEnd: (_) {
                    _dragging = false;
                    final f = _scrub;
                    if (f != null) unawaited(_seek(f, duration));
                  },
                  onHorizontalDragCancel: () => setState(() {
                    _dragging = false;
                    _scrub = null;
                  }),
                  child: SizedBox(
                    width: width,
                    height: KHomeReels.progressHit,
                    child: CustomPaint(
                      painter: _ProgressPainter(
                        played: played,
                        active: _dragging,
                        rtl: rtl,
                        color: KPalette.dark.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}

class _ProgressPainter extends CustomPainter {
  const new({
    required this.played,
    required this.active,
    required this.rtl,
    required this.color,
  });

  final double played;
  final bool active;
  final bool rtl;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final thick = active ? KHomeReels.progressActive : KHomeReels.progress;
    // Scrubbing lifts the line so the whole thumb stays on the reel.
    final bottom = active
        ? size.height -
              (KHomeReels.progressThumb - KHomeReels.progressActive) / 2
        : size.height;
    final track = Rect.fromLTRB(0, bottom - thick, size.width, bottom);
    canvas.drawRect(
      track,
      Paint()..color = color.withValues(alpha: KHomeReels.progressTrackOpacity),
    );
    final w = size.width * played;
    final done = rtl
        ? Rect.fromLTRB(size.width - w, track.top, size.width, track.bottom)
        : Rect.fromLTRB(0, track.top, w, track.bottom);
    canvas.drawRect(done, Paint()..color = color);
    if (active) {
      final x = rtl ? size.width - w : w;
      canvas.drawCircle(
        Offset(x, track.center.dy),
        KHomeReels.progressThumb / 2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.played != played ||
      old.active != active ||
      old.rtl != rtl ||
      old.color != color;
}

/// One rail action: a 28 dp icon over its label, a 48 dp target. Without
/// [onTap] it is display only (a fixture's counts).
class _RailAction extends StatelessWidget {
  const new({
    required this.icon,
    this.label,
    this.iconColor,
    this.semanticLabel,
    this.semanticValue,
    this.toggled,
    this.onTap,
    super.key,
  });

  final String icon;
  final String? label;
  final Color? iconColor;
  final String? semanticLabel;
  final String? semanticValue;
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final text = label;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: KSizes.minTouchTarget,
        minHeight: KSizes.minTouchTarget,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: KHomeReels.railIcon, color: iconColor ?? white),
          if (text != null) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: context.textStyles.caption.copyWith(
                color: white,
                fontWeight: FontWeight.w600,
                height: 1.25,
                shadows: _shadows,
              ),
            ),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return body;
    return Semantics(
      button: true,
      toggled: toggled,
      label: semanticLabel,
      value: semanticValue,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: body,
      ),
    );
  }
}

/// D372: the rail's gift counter — the cherry art and the compact amount of
/// cherries the author earned from gifts on the reel (display only).
class _RailCherries extends StatelessWidget {
  const new({required this.label, required this.semanticLabel, super.key});

  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: KSizes.minTouchTarget,
        minHeight: KSizes.minTouchTarget,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KCherryIcon(size: KHomeReels.railIcon),
          const SizedBox(height: KSpacing.xs),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: context.textStyles.caption.copyWith(
              color: KPalette.dark.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.25,
              shadows: _shadows,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The rail's author photo (opens the profile) with the follow badge
/// below it while the viewer neither follows the author nor waits for a
/// request (D175).
class _RailAuthor extends ConsumerWidget {
  const new({required this.reel});

  final FeedReelData reel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final white = KPalette.dark.textPrimary;
    final username = reel.authorUsername;
    // The source's answer first; a real reel without one asks the profile.
    final follow = switch (reel.isFollowingAuthor) {
      final f? => (following: f, requested: false, self: reel.isSelf),
      null when username != null && reel.postId != null && !reel.isSelf =>
        ref.watch(reelAuthorFollowProvider(username)).value,
      null => null,
    };
    final offer =
        username != null &&
        follow != null &&
        !follow.self &&
        !reel.isSelf &&
        !follow.following &&
        !follow.requested;
    return SizedBox(
      width: KHomeReels.railWidth,
      height: KHomeReels.railAvatarBlock,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // D60: the photo opens the author's profile.
          Semantics(
            button: username != null,
            label: reel.authorName,
            excludeSemantics: true,
            child: GestureDetector(
              key: HomeReelPage.authorKey,
              onTap: username == null
                  ? null
                  : () => context.push(AppRoutes.userProfile(username)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: white, width: KMetrics.stroke),
                ),
                child: KAvatar(
                  name: reel.authorName,
                  image: reel.authorAvatar,
                  size: KHomeReels.railAvatar - 2 * KMetrics.stroke,
                ),
              ),
            ),
          ),
          if (offer)
            Positioned(
              // The badge's centre sits 3 dp below the photo.
              top: KHomeReels.railAvatar + 3 - KSizes.minTouchTarget / 2,
              child: ReelFollowBadge(
                username: username,
                authorName: reel.authorName,
              ),
            ),
        ],
      ),
    );
  }
}

/// Follow on the rail photo: a red "+" badge (48 dp target) that follows
/// the author through the follow API (`PUT /users/{username}/follow`,
/// CONVENTIONS §10.6). It turns into a check at once and stays so on
/// success; a private account (D175) answers with a request, shown as a
/// clock. On failure it comes back and a snack bar says why.
class ReelFollowBadge extends ConsumerStatefulWidget {
  const new({required this.username, required this.authorName, super.key});

  final String username;
  final String authorName;

  static const badgeKey = Key('home.reel.follow');

  @override
  ConsumerState<ReelFollowBadge> createState() => _ReelFollowBadgeState();
}

enum _Follow { none, following, requested }

class _ReelFollowBadgeState extends ConsumerState<ReelFollowBadge> {
  _Follow _state = _Follow.none;
  bool _busy = false;

  Future<void> _follow() async {
    if (_busy || _state != _Follow.none) return;
    setState(() {
      _busy = true;
      _state = _Follow.following;
    });
    try {
      final result = await ref
          .read(profileRepositoryProvider)
          .follow(widget.username);
      if (!mounted) return;
      setState(
        () => _state = result.isFollowing
            ? _Follow.following
            : result.isRequested
            ? _Follow.requested
            : _Follow.none,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _state = _Follow.none);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    final (label, icon, fill, ink) = switch (_state) {
      _Follow.none => (
        l10n.homeFollowAuthor(widget.authorName),
        Icons.add_rounded,
        p.primary,
        p.onPrimary,
      ),
      _Follow.following => (
        l10n.homeFollowingAuthor(widget.authorName),
        Icons.check_rounded,
        p.textPrimary,
        p.primary,
      ),
      _Follow.requested => (
        l10n.reelsFollowRequested(widget.authorName),
        Icons.schedule_rounded,
        p.surfaceOverlay,
        p.textPrimary,
      ),
    };
    final idle = _state == _Follow.none;
    return Semantics(
      container: true,
      button: idle,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ReelFollowBadge.badgeKey,
        behavior: HitTestBehavior.opaque,
        onTap: idle ? _follow : null,
        child: SizedBox.square(
          dimension: KSizes.minTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.fast),
              width: KHomeReels.followBadge,
              height: KHomeReels.followBadge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                gradient: idle
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: KBrandColors.gradientLive,
                      )
                    : null,
              ),
              child: Icon(icon, size: KHomeReels.followIcon, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sound disc: the author's photo inside a brand-red ring, turning
/// with the video's playback (still with reduced motion). There is no
/// sounds feature, so it is not a button (D202).
class _MusicDisc extends StatelessWidget {
  const new({required this.reel, required this.turns});

  final FeedReelData reel;
  final ValueListenable<double> turns;

  @override
  Widget build(BuildContext context) {
    const inner = KHomeReels.disc - 2 * KHomeReels.discRing;
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Container(
        key: HomeReelPage.discKey,
        width: KHomeReels.disc,
        height: KHomeReels.disc,
        padding: const EdgeInsets.all(KHomeReels.discRing),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              KBrandColors.red400,
              KBrandColors.red700,
              KBrandColors.gold,
              KBrandColors.red400,
            ],
          ),
        ),
        child: ValueListenableBuilder<double>(
          valueListenable: turns,
          builder: (context, value, child) => AnimatedRotation(
            turns: still ? 0 : value,
            duration: still ? Duration.zero : const Duration(milliseconds: 600),
            child: child,
          ),
          child: Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KPalette.dark.background,
            ),
            alignment: Alignment.center,
            child: KAvatar(
              name: reel.authorName,
              image: reel.authorAvatar,
              size: inner - 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom block: the author's photo and handle (both open the
/// profile), the caption (two lines, then «المزيد»; linked #tags and
/// @mentions open their pages) and the sound line.
class _ReelInfo extends StatelessWidget {
  const new({required this.reel});

  final FeedReelData reel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final username = reel.authorUsername;
    final caption = reel.caption;
    void openProfile() => context.push(AppRoutes.userProfile(username!));
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.overlayMaxTextScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: username != null,
            label: reel.authorName,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: username == null ? null : openProfile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KAvatar(
                    name: reel.authorName,
                    image: reel.authorAvatar,
                    size: KHomeReels.authorAvatar,
                  ),
                  const SizedBox(width: KHomeReels.authorGap),
                  Flexible(
                    child: Text(
                      // A Latin handle keeps its «@» in front in Arabic.
                      username == null
                          ? reel.authorName
                          : KHandle.ltr(reel.handle),
                      key: HomeReelPage.handleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(
                        color: white,
                        fontSize: 16,
                        height: 1.3,
                        shadows: _shadows,
                      ),
                    ),
                  ),
                  // D293: the verification seal right after the handle.
                  VerificationSeal(reel.authorVerification, fontSize: 16),
                ],
              ),
            ),
          ),
          // D283: the Kabso Team's official announcement reel.
          if (reel.announcement)
            const Padding(
              padding: EdgeInsets.only(top: KSpacing.xs),
              child: AnnouncementLabel(onMedia: true),
            ),
          if (reel.pendingModeration)
            Padding(
              key: HomeReelPage.pendingKey,
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                l10n.feedPostPending,
                style: t.caption.copyWith(color: white, shadows: _shadows),
              ),
            ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: KHomeReels.captionGap),
            _ReelCaption(
              key: HomeReelPage.captionKey,
              text: caption,
              hashtags: reel.hashtags,
              mentions: reel.mentions,
              premiumMentions: reel.premiumMentions,
            ),
          ],
          const SizedBox(height: KHomeReels.soundGap),
          Row(
            key: HomeReelPage.soundKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.musicNote,
                size: KHomeReels.soundIcon,
                color: white,
              ),
              const SizedBox(width: KSpacing.sm),
              Flexible(
                child: Text(
                  l10n.reelsOriginalSound(reel.authorName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(color: white, shadows: _shadows),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The caption: [KHomeReels.captionLines] lines; a longer one ends in
/// "… المزيد", which expands it in place. Linked `#tags` open the hashtag
/// page and `@mentions` the profile (only the ones the API linked).
class _ReelCaption extends StatefulWidget {
  const new({
    required this.text,
    required this.hashtags,
    required this.mentions,
    required this.premiumMentions,
    super.key,
  });

  final String text;
  final Set<String> hashtags;
  final Set<String> mentions;
  final Set<String> premiumMentions;

  @override
  State<_ReelCaption> createState() => _ReelCaptionState();
}

class _ReelCaptionState extends State<_ReelCaption> {
  bool _expanded = false;
  final List<TapGestureRecognizer> _taps = [];

  static final RegExp _entity = RegExp(
    r'(?<![\p{L}\p{N}_])([#@])([\p{L}\p{M}\p{N}_.]+)',
    unicode: true,
  );

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(String s, TextStyle style) {
    final out = <InlineSpan>[];
    var last = 0;
    final accent = style.copyWith(fontWeight: FontWeight.w700);
    for (final m in _entity.allMatches(s)) {
      final hash = m.group(1) == '#';
      final name = hash
          ? m.group(2)!
          : m.group(2)!.replaceFirst(RegExp(r'\.+$'), '');
      final linked = hash
          ? widget.hashtags.contains(name.toLowerCase())
          : widget.mentions.contains(name.toLowerCase());
      if (!linked) continue;
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      final tap = TapGestureRecognizer()
        ..onTap = () => context.push(
          hash ? AppRoutes.hashtag(name) : AppRoutes.userProfile(name),
        );
      _taps.add(tap);
      out.add(
        TextSpan(
          text: hash
              ? '#$name'
              : KHandle.ltr(
                  widget.premiumMentions.contains(name.toLowerCase())
                      ? name
                      : '@$name',
                ),
          style: accent,
          recognizer: tap,
        ),
      );
      last = m.start + 1 + name.length;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final style = DefaultTextStyle.of(context).style.merge(
      context.textStyles.body.copyWith(
        color: KPalette.dark.textPrimary,
        fontSize: 14,
        height: 1.4,
        shadows: _shadows,
      ),
    );
    if (_expanded) {
      return Text.rich(
        TextSpan(style: style, children: _spans(widget.text, style)),
      );
    }
    final more = context.l10n.reelsMore;
    final tail = TextSpan(
      text: '… ',
      children: [
        TextSpan(
          text: more,
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        final locale = Localizations.maybeLocaleOf(context);
        bool fits(String s, {InlineSpan? end}) {
          final painter = TextPainter(
            text: TextSpan(
              style: style,
              children: [
                TextSpan(text: s),
                ?end,
              ],
            ),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: KHomeReels.captionLines,
          )..layout(maxWidth: constraints.maxWidth);
          final ok = !painter.didExceedMaxLines;
          painter.dispose();
          return ok;
        }

        if (fits(widget.text)) {
          return Text.rich(
            TextSpan(style: style, children: _spans(widget.text, style)),
          );
        }
        var lo = 0;
        var hi = widget.text.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          if (fits(widget.text.substring(0, mid).trimRight(), end: tail)) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        var shown = widget.text.substring(0, lo);
        final space = shown.lastIndexOf(RegExp(r'\s'));
        if (space > 0) shown = shown.substring(0, space);
        shown = shown.trimRight();
        return Semantics(
          container: true,
          button: true,
          label: '${widget.text}. $more',
          excludeSemantics: true,
          child: GestureDetector(
            key: HomeReelPage.moreKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = true),
            child: Text.rich(
              TextSpan(style: style, children: [..._spans(shown, style), tail]),
              maxLines: KHomeReels.captionLines,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const new({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final cover = image;
    return ColoredBox(
      color: KPalette.dark.surfaceRaised,
      child: cover == null
          ? const SizedBox.expand()
          : Image(
              image: cover,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}
