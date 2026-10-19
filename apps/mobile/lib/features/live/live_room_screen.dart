import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_room_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live/room/:roomId` — the live room (KL-034, HOME_LIVE_LAYOUT_DECISIONS
/// §3), full screen above the shell (no bottom nav, HL-N1 §2).
///
/// Everything shown comes from the API: the room (`GET /live/rooms/{id}`:
/// title, category, host, status, end reason) and the host's public profile
/// (`GET /users/{username}`: follower count, follow state), with follow /
/// unfollow through `publicProfileProvider` (optimistic, rolled back with a
/// snack on failure).
///
/// What does not exist yet is shown honestly, never faked:
/// - video: no media provider (B1) → "Live video isn't available yet";
/// - chat: no chat API → a notice in the chat area and no composer;
/// - gifts: the sheet opens with Kabso's preview art, no prices, and Send
///   disabled with the reason (no catalogue or wallet, B5);
/// - viewers: no presence → nothing (`viewerCount` is 0), never a count;
/// - share: no room link domain (B7) → no share button.
///
/// States (HL-L10): loading, live (video unavailable), ended (host ended /
/// heartbeat timeout / other), not found, error and offline with Try again.
class LiveRoomScreen extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = liveRoomProvider(roomId);
    final async = ref.watch(provider);
    void close() => closeLiveRoom(context);
    void retry() => ref.invalidate(provider);

    final room = async.value;
    final Widget body;
    if (room != null && !async.isLoading) {
      body = _RoomView(room: room, onClose: close);
    } else if (async.hasError && !async.isLoading) {
      body = _failure(l10n, toAppFailure(async.error!), close, retry);
    } else {
      body = _LoadingRoom(onClose: close);
    }
    return Scaffold(backgroundColor: KPalette.dark.background, body: body);
  }

  static Widget _failure(
    AppLocalizations l10n,
    AppFailure failure,
    VoidCallback close,
    VoidCallback retry,
  ) {
    const p = KPalette.dark;
    if (failure.code == ErrorCode.notFound) {
      return KRoomMessage(
        key: const Key('room.notFound'),
        icon: Icons.sensors_off_outlined,
        iconColor: p.textSecondary,
        title: l10n.liveRoomNotFoundTitle,
        message: l10n.liveRoomNotFoundBody,
        onClose: close,
      );
    }
    if (failure.code == ErrorCode.networkOffline) {
      return KRoomMessage(
        key: const Key('room.offline'),
        icon: Icons.wifi_off_rounded,
        iconColor: p.textSecondary,
        title: l10n.feedOfflineTitle,
        message: l10n.feedOfflineBody,
        onClose: close,
        onRetry: retry,
      );
    }
    final id = failureErrorId(failure);
    return KRoomMessage(
      key: const Key('room.error'),
      icon: Icons.error_outline_rounded,
      iconColor: p.error,
      title: l10n.liveRoomErrorTitle,
      message: failureMessage(l10n, failure),
      detail: id == null ? null : l10n.errorIdLabel(id),
      onClose: close,
      onRetry: retry,
    );
  }
}

/// Leaves the room: back to where it was opened from (the Live hub), or to
/// the hub itself when the room was the first page (deep link).
void closeLiveRoom(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go(AppRoutes.home);
  }
}

ImageProvider? _networkImage(String? url) =>
    url == null || url.isEmpty ? null : NetworkImage(url);

class _LoadingRoom extends StatelessWidget {
  const new({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('room.loading'),
    container: true,
    label: context.l10n.liveRoomLoading,
    child: KLiveRoomScaffold(
      video: const KLiveVideoPlaceholder(child: SizedBox.shrink()),
      header: const KHostPillSkeleton(),
      onClose: onClose,
    ),
  );
}

class _RoomView extends ConsumerStatefulWidget {
  const new({required this.room, required this.onClose});

  final LiveRoom room;
  final VoidCallback onClose;

  @override
  ConsumerState<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends ConsumerState<_RoomView> {
  /// Latched once the ended overlay has offered Follow, so the button stays
  /// (as "Following") after the tap instead of vanishing.
  bool _endedOfferedFollow = false;

  String get _username => widget.room.host.username;

  Future<void> _setFollowing({required bool follow}) =>
      setHostFollowing(context, ref, _username, follow: follow);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final room = widget.room;
    final host = room.host;
    final avatar = _networkImage(host.avatarUrl);
    final profile = ref.watch(publicProfileProvider(_username)).value;
    final canFollow = profile?.canFollow ?? false;
    final following = profile?.isFollowing ?? false;
    final ended = room.status == LiveRoomStatus.ended;
    if (ended && canFollow && !following) _endedOfferedFollow = true;

    return KLiveRoomScaffold(
      // Ended: the overlay explains; no video message underneath it.
      video: ended
          ? const KLiveVideoPlaceholder(child: SizedBox.shrink())
          : const KRoomVideoUnavailable(),
      header: KHostPill(
        hostName: host.displayName,
        avatar: avatar,
        subtitle: profile == null
            ? null
            : l10n.liveRoomFollowers(
                profile.followerCount,
                KFormat.compact(profile.followerCount, l10n),
              ),
        following: following,
        onFollow: canFollow
            ? () => unawaited(_setFollowing(follow: true))
            : null,
        onTap: profile == null
            ? null
            : () => unawaited(showHostSheet(context, _username)),
      ),
      // Presence does not exist yet: a count only when the API has one.
      viewers: room.viewerCount > 0
          ? KViewerStrip(count: room.viewerCount)
          : null,
      onClose: widget.onClose,
      roomInfo: KRoomInfoRow(title: room.title, category: room.category?.name),
      chat: ended
          ? null
          : KLiveChatOverlay(
              key: const Key('room.chatUnavailable'),
              lines: [LiveChatSystem(text: l10n.liveRoomChatUnavailable)],
            ),
      actionBar: ended
          ? null
          : KRoomActionBar(onGift: () => unawaited(_openGifts(context))),
      cover: ended
          ? KRoomEndedOverlay(
              hostName: host.displayName,
              avatar: avatar,
              reason: endReasonText(l10n, room.endReason),
              onBack: widget.onClose,
              followAction: _endedOfferedFollow && canFollow
                  ? _FollowButton(
                      following: following,
                      onPressed: () =>
                          unawaited(_setFollowing(follow: !following)),
                    )
                  : null,
            )
          : null,
    );
  }

  static Future<void> _openGifts(BuildContext context) =>
      KGiftPanel.show(context, builder: (_) => const _GiftSheet());
}

/// The localized end reason (HL-L10).
String endReasonText(AppLocalizations l10n, LiveRoomEndReason? reason) =>
    switch (reason) {
      LiveRoomEndReason.hostEnded => l10n.liveRoomEndedByHost,
      LiveRoomEndReason.heartbeatTimeout => l10n.liveRoomEndedTimeout,
      LiveRoomEndReason.hostSuspended ||
      LiveRoomEndReason.admin ||
      LiveRoomEndReason.unknown ||
      null => l10n.liveRoomEndedOther,
    };

/// Follows or unfollows the host through [publicProfileProvider]
/// (optimistic); a failure has already been rolled back and shows a snack.
Future<void> setHostFollowing(
  BuildContext context,
  WidgetRef ref,
  String username, {
  required bool follow,
}) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(publicProfileProvider(username).notifier)
        .setFollowing(follow: follow);
  } on Object catch (e) {
    if (!context.mounted) return;
    KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
  }
}

/// The host's profile as a non-dimming room sheet (HL-L2 "tap opens the
/// host mini-profile"): avatar, name, @username, followers, bio and the
/// follow toggle, all from `GET /users/{username}`.
Future<void> showHostSheet(BuildContext context, String username) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KPalette.dark.surfaceRaised.withValues(alpha: 0),
      barrierColor: KMetrics.roomSheetBarrier,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * KMetrics.sheetMaxHeightFactor,
      ),
      builder: (_) => KLiveSurface(child: _HostSheet(username: username)),
    );

class _HostSheet extends ConsumerWidget {
  const new({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final profile = ref.watch(publicProfileProvider(username)).value;
    final bio = profile?.bio;
    return Container(
      key: const Key('room.hostSheet'),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.xl,
            KSpacing.sm,
            KSpacing.xl,
            KSpacing.xl,
          ),
          child: profile == null
              ? const SizedBox(height: KSizes.avatarLg)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: KMetrics.sheetHandleWidth,
                      height: KMetrics.sheetHandleHeight,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                    ),
                    const SizedBox(height: KSpacing.lg),
                    KAvatar(
                      name: profile.displayName,
                      image: _networkImage(profile.avatarUrl),
                      size: KSizes.avatarLg,
                    ),
                    const SizedBox(height: KSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        profile.displayName,
                        textAlign: TextAlign.center,
                        style: text.title,
                      ),
                    ),
                    Text(
                      l10n.liveRoomUsername(profile.username),
                      textDirection: TextDirection.ltr,
                      style: text.caption,
                    ),
                    const SizedBox(height: KSpacing.sm),
                    Text(
                      l10n.liveRoomFollowers(
                        profile.followerCount,
                        KFormat.compact(profile.followerCount, l10n),
                      ),
                      style: text.body.copyWith(color: p.textSecondary),
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.sm),
                      Text(bio, textAlign: TextAlign.center, style: text.body),
                    ],
                    if (profile.canFollow) ...[
                      const SizedBox(height: KSpacing.lg),
                      _FollowButton(
                        following: profile.isFollowing,
                        onPressed: () => unawaited(
                          setHostFollowing(
                            context,
                            ref,
                            username,
                            follow: !profile.isFollowing,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Follow / Following toggle button (ended overlay, host sheet).
class _FollowButton extends StatelessWidget {
  const new({required this.following, required this.onPressed});

  final bool following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KButton(
      key: const Key('room.follow'),
      label: following ? l10n.liveFollowing : l10n.liveFollow,
      icon: following ? Icons.check_rounded : Icons.add_rounded,
      variant: following ? KButtonVariant.secondary : KButtonVariant.primary,
      onPressed: onPressed,
      expand: false,
    );
  }
}

/// The gift sheet's selection (sending is disabled; no combo counter).
class _GiftSheet extends StatefulWidget {
  const new();

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) => KGiftPanel(
    gifts: KGiftPanel.preview(context.l10n),
    selectedId: _selected,
    onSelected: (gift) => setState(() => _selected = gift.id),
  );
}
