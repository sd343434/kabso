import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/medals/application/medals_providers.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/premium/presentation/premium_labels.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/push/push_permission.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The bell on the Posts header (CP-009): opens the notifications, with the
/// unread count ("99+" at 99) while there is one.
class NotificationsBell extends ConsumerWidget {
  const new({this.color, super.key});

  final Color? color;

  static const bellKey = Key('notifications.bell');
  static const badgeKey = Key('notifications.badge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final count = ref.watch(unreadNotificationsProvider);
    return IconButton(
      key: bellKey,
      tooltip: l10n.notificationsBell(count),
      constraints: const BoxConstraints.tightFor(
        width: KSizes.minTouchTarget,
        height: KSizes.minTouchTarget,
      ),
      onPressed: () => context.push(AppRoutes.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          AppIcon(
            AppIcons.bell,
            size: KMetrics.iconMd,
            color: color ?? p.textPrimary,
          ),
          if (count > 0)
            PositionedDirectional(
              top: -5,
              start: KMetrics.iconMd - 9,
              child: ExcludeSemantics(
                child: Container(
                  key: badgeKey,
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    border: Border.all(color: p.background, width: 1.5),
                  ),
                  child: Text(
                    count >= 99 ? '99+' : '$count',
                    textScaler: TextScaler.noScaling,
                    textDirection: TextDirection.ltr,
                    style: context.textStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: p.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Today, this week (the last 7 days) or earlier, in local time.
enum NotificationSection { today, week, earlier }

NotificationSection sectionOf(DateTime at, DateTime now) {
  final local = at.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  if (!local.isBefore(today)) return NotificationSection.today;
  if (now.difference(local).inDays < 7) return NotificationSection.week;
  return NotificationSection.earlier;
}

/// `/notifications` (CP-009, CONVENTIONS §11.10): the inbox grouped by
/// Today, This week and Earlier. Opening it marks everything read (the
/// rows keep their unread look for this visit). A row opens the post (a
/// comment opens the post with its comments), the story or the profile;
/// removed content opens nothing.
class NotificationsScreen extends ConsumerWidget {
  const new({super.key});

  static const emptyKey = Key('notifications.empty');
  static const listKey = Key('notifications.list');
  static const settingsKey = Key('notifications.settings');
  static const backKey = Key('notifications.back');
  static const avatarKey = Key('notifications.avatar');

  /// D382: the header photo beside the title.
  static const double headerAvatar = 32;
  static Key rowKey(String id) => Key('notifications.row.$id');
  static Key sectionKey(NotificationSection s) =>
      Key('notifications.section.${s.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // D152: the first visit is a moment to explain notifications.
      PushPermissionTrigger(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final me = ref.watch(currentUserProvider);
    // D382: your photo and a large «الإشعارات» (no bar chrome); back only
    // when the page was pushed.
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context);
    return Scaffold(
      appBar: KAppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: canPop ? 0 : KSpacing.lg,
        toolbarHeight: 52,
        title: Row(
          children: [
            if (canPop)
              IconButton(
                key: backKey,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                icon: const BackButtonIcon(),
              ),
            if (me != null) ...[
              KAvatar(
                key: avatarKey,
                name: me.displayName.isEmpty ? me.username : me.displayName,
                imageUrl: me.avatarUrl,
                size: headerAvatar,
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.notificationsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.headline.copyWith(
                    fontSize: 22,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: settingsKey,
            tooltip: l10n.notificationsSettings,
            onPressed: () => context.push(AppRoutes.notificationSettings),
            icon: AppIcon(
              AppIcons.settings,
              size: KMetrics.iconMd,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(width: KSpacing.xs),
        ],
      ),
      body: switch (ref.watch(notificationsInboxProvider)) {
        AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
          RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsInboxProvider.future),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: box.maxHeight,
                  child: KEmptyState(
                    key: emptyKey,
                    icon: Icons.notifications_none_rounded,
                    title: l10n.notificationsEmpty,
                    message: l10n.notificationsEmptyBody,
                  ),
                ),
              ),
            ),
          ),
        AsyncValue(
          value: FeedItems(:final items, :final hasMore, :final loadMoreError),
        ) =>
          RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsInboxProvider.future),
            child: _NotificationList(
              items: items,
              hasMore: hasMore,
              loadMoreError: loadMoreError,
            ),
          ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(notificationsInboxProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const new({
    required this.items,
    required this.hasMore,
    required this.loadMoreError,
  });

  final List<AppNotification> items;
  final bool hasMore;
  final Object? loadMoreError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = clock.now();
    final rows = <Widget>[];
    NotificationSection? current;
    for (final n in items) {
      final section = sectionOf(n.createdAt, now);
      if (section != current) {
        current = section;
        rows.add(
          _SectionHeader(
            key: NotificationsScreen.sectionKey(section),
            label: switch (section) {
              NotificationSection.today => l10n.notifSectionToday,
              NotificationSection.week => l10n.notifSectionWeek,
              NotificationSection.earlier => l10n.notifSectionEarlier,
            },
          ),
        );
      }
      rows.add(NotificationRow(key: NotificationsScreen.rowKey(n.id), item: n));
    }
    final notifier = ref.read(notificationsInboxProvider.notifier);
    return ListView.builder(
      key: NotificationsScreen.listKey,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: KSpacing.xl),
      itemCount: rows.length + (hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < rows.length) return rows[i];
        return loadMoreError == null
            ? PostGridLoadMore(
                key: ValueKey(items.length),
                onVisible: () => unawaited(notifier.loadMore()),
              )
            : Center(
                child: TextButton(
                  onPressed: () => unawaited(notifier.loadMore()),
                  child: Text(l10n.actionRetry),
                ),
              );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    // D382: a plain heading with room above it.
    padding: const EdgeInsetsDirectional.fromSTEB(
      KSpacing.lg,
      KSpacing.md,
      KSpacing.lg,
      KSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: context.textStyles.bodyStrong.copyWith(
          fontSize: 16,
          height: 1.3,
          color: context.palette.textPrimary,
        ),
      ),
    ),
  );
}

/// One notification: who (bold) did what, when; the item's photo when it
/// has one. Unread rows are tinted with a dot.
class NotificationRow extends StatelessWidget {
  const new({required this.item, super.key});

  final AppNotification item;

  static const double avatar = 46;
  static const double thumb = 44;

  static const unreadDotKey = Key('notifications.unreadDot');

  /// Where a tap goes, or `null` (removed content, an unknown target).
  String? routeTo() {
    // D175: a removed photo leads to Edit profile (to choose another); a
    // follow request to the list of requests.
    if (item.type == NotificationType.avatarRemoved ||
        item.type == NotificationType.coverRemoved) {
      return AppRoutes.editProfile;
    }
    // D384: a removed animated picture leads to «صورة متحركة».
    if (item.type == NotificationType.animatedAvatarRemoved) {
      return AppRoutes.vipAnimatedAvatar;
    }
    if (item.type == NotificationType.followRequest) {
      return AppRoutes.followRequests;
    }
    // D198: the data export is ready → the download screen.
    if (item.type == NotificationType.dataExportReady) {
      return AppRoutes.dataExport;
    }
    // D206: every agency notification → «الوكالة».
    // D209: «كن مضيفاً مع الإدارة» decided → «الوكالة» (the state, the reason).
    // D227: the identity check's result → «الوكالة» (its forms show it).
    if (item.type.isAgency || item.type.isHostApplication || item.type.isKyc) {
      return AppRoutes.agency;
    }
    // D185: coins from an agent → the wallet; a cherry sale to confirm →
    // the cherry requests.
    if (item.type == NotificationType.rechargeCoinsReceived) {
      return AppRoutes.wallet;
    }
    // D217: a referral's cherries taken back → the cherry wallet (history).
    if (item.type == NotificationType.referralRewardReversed) {
      return AppRoutes.walletCherries;
    }
    // D390: the ambassadors programme → the programme (an approved ambassador
    // finds the dashboard there).
    if (item.type.isAmbassador) return AppRoutes.ambassadors;
    if (item.type == NotificationType.rechargeCherryRequest) {
      return AppRoutes.rechargeCherries;
    }
    // D290: the staff member's request decided → their requests; the
    // supporter's level raised → the levels page.
    if (item.type == NotificationType.levelRaised) return AppRoutes.levels;
    // D303: an event prize → the event.
    if (item.type == NotificationType.eventPrizeWon) {
      final id = item.target?.id;
      return id == null ? AppRoutes.eventCenter : AppRoutes.event(id);
    }
    if (item.type.isLevelRaise) return AppRoutes.staffLevelRaises;
    final target = item.target;
    if (target == null || item.type == NotificationType.contentRemoved) {
      return null;
    }
    // CP-018: requests and the couple live on the relationship page; a
    // medal on the medals page.
    if (item.type == NotificationType.cpRequest ||
        item.type == NotificationType.cpAccepted) {
      return AppRoutes.cp;
    }
    if (item.type == NotificationType.medalAwarded) return AppRoutes.medals;
    return switch (target.type) {
      NotificationTargetType.bagItem => AppRoutes.bag,
      NotificationTargetType.rechargeSale => AppRoutes.wallet,
      NotificationTargetType.rechargeOrder => AppRoutes.rechargeOrder(
        target.id,
      ),
      NotificationTargetType.agency => AppRoutes.agency,
      NotificationTargetType.premiumUsername => AppRoutes.premium,
      NotificationTargetType.post => AppRoutes.post(target.id),
      NotificationTargetType.comment when target.postId != null =>
        AppRoutes.post(target.postId!, comments: true),
      NotificationTargetType.comment => null,
      NotificationTargetType.story when item.actors.isNotEmpty =>
        AppRoutes.stories(item.actors.first.username),
      NotificationTargetType.story => null,
      NotificationTargetType.user => AppRoutes.userProfile(target.id),
      NotificationTargetType.family => AppRoutes.family(target.id),
      NotificationTargetType.medal => AppRoutes.medals,
      // D250: the team's action on a live — the row says it all.
      NotificationTargetType.liveModeration => null,
      // D273: a staff alert opens the live as staff on its reports.
      NotificationTargetType.liveRoom => AppRoutes.liveRoomStaffReports(
        target.id,
      ),
      // D288: «بلاغات» on that report.
      NotificationTargetType.report => AppRoutes.staffReport(target.id),
      NotificationTargetType.levelRaise => AppRoutes.staffLevelRaises,
      // D301: «صندوق المؤسس» lives in the panel — the row says it all.
      NotificationTargetType.ownerFeedback => null,
      NotificationTargetType.event => AppRoutes.event(target.id),
    };
  }

  /// The sentence, the "who" phrase in it and the latest actor's name
  /// (which starts that phrase and is shown bold).
  (String, String?, String) _sentence(
    AppLocalizations l10n,
    String localeTag, {
    String? medalName,
  }) {
    final first = item.actors.firstOrNull;
    // Isolated, so a name in the other script never mixes with the
    // sentence around it (a Latin name in Arabic, or the reverse).
    final shown = first == null
        ? ''
        : (first.displayName.isEmpty ? first.username : first.displayName);
    final name = shown.isEmpty ? '' : '\u2068$shown\u2069';
    final who = l10n.notifActors(name, (item.actorCount - 1).clamp(0, 1 << 30));
    final targetType = item.target?.type;
    final text = switch (item.type) {
      NotificationType.likePost => l10n.notifLikePost(who),
      NotificationType.likeComment => l10n.notifLikeComment(who),
      NotificationType.comment => l10n.notifComment(who),
      NotificationType.reply => l10n.notifReply(who),
      NotificationType.mention => switch (targetType) {
        NotificationTargetType.comment => l10n.notifMentionComment(who),
        NotificationTargetType.story => l10n.notifMentionStory(who),
        _ => l10n.notifMentionPost(who),
      },
      NotificationType.follow => l10n.notifFollow(who),
      NotificationType.repost => l10n.notifRepost(who),
      NotificationType.postPublished => l10n.notifPostPublished,
      NotificationType.liveScheduledSoon => switch (item.target?.startsAt) {
        final at? => l10n.notifLiveScheduled(
          who,
          KFormat.bidiIsolate(KFormat.time(at, localeTag)),
        ),
        // No start (not expected): still say it, without the time.
        null => l10n.notifLiveScheduled(who, ''),
      },
      NotificationType.contentRemoved => switch (targetType) {
        NotificationTargetType.comment => l10n.notifRemovedComment,
        NotificationTargetType.story => l10n.notifRemovedStory,
        _ => l10n.notifRemovedPost,
      },
      NotificationType.cpRequest => l10n.notifCpRequest(who),
      NotificationType.cpAccepted => l10n.notifCpAccepted(who),
      NotificationType.familyJoinAccepted => l10n.notifFamilyJoinAccepted(
        _familyName(l10n),
      ),
      NotificationType.familyJoinDeclined => l10n.notifFamilyJoinDeclined(
        _familyName(l10n),
      ),
      // v1.81-live (D291): above level 1 the medal levelled up.
      NotificationType.medalAwarded => switch ((
        medalName,
        item.target?.medalLevel,
      )) {
        (final name?, final level?) when level > 1 => l10n.notifMedalLevelUp(
          KFormat.bidiIsolate(name),
          level,
        ),
        (null, final level?) when level > 1 => l10n.notifMedalLevelUpUnnamed(
          level,
        ),
        (final name?, _) => l10n.notifMedalAwarded(KFormat.bidiIsolate(name)),
        (null, _) => l10n.notifMedalAwardedUnnamed,
      },
      NotificationType.premiumUsernameExpiring =>
        l10n.notificationPremiumExpiring(
          item.target?.id ?? '',
          premiumTimeLeft(
            l10n,
            (item.target?.endsAt ?? clock.now()).difference(clock.now()),
          ),
        ),
      NotificationType.premiumUsernameExpired =>
        l10n.notificationPremiumExpired(item.target?.id ?? ''),
      NotificationType.bagItemReceived => l10n.notifBagItemReceived(
        who,
        switch (item.target?.bagCategory) {
          'PROFILE_CARD' => l10n.notifBagItemProfileCard,
          _ => l10n.notifBagItemGeneric,
        },
      ),
      NotificationType.followRequest => l10n.notifFollowRequest(who),
      NotificationType.followRequestAccepted => l10n.notifFollowRequestAccepted(
        who,
      ),
      NotificationType.avatarRemoved => l10n.notifAvatarRemoved,
      NotificationType.coverRemoved => l10n.notifCoverRemoved,
      NotificationType.animatedAvatarRemoved => l10n.notifAnimatedAvatarRemoved,
      NotificationType.dataExportReady => l10n.notifDataExportReady,
      NotificationType.rechargeCoinsReceived => l10n.notifRechargeCoins(
        who,
        KFormat.bidiIsolate(KFormat.grouped(item.target?.coins ?? 0)),
      ),
      NotificationType.rechargeCherryRequest => l10n.notifRechargeCherry(who),
      NotificationType.contentGiftReceived => l10n.notifContentGiftReceived(
        who,
      ),
      NotificationType.rechargeOrderUpdate => rechargeOrderNotificationText(
        l10n,
        item.target?.orderEvent,
        item.target?.coins ?? 0,
      ),
      NotificationType.agencyOpened => l10n.notifAgencyOpened,
      NotificationType.agencyProbationReminder => l10n.notifAgencyReminder(
        KFormat.bidiIsolate('${item.target?.activatedHosts ?? 0}'),
        KFormat.bidiIsolate('${item.target?.requiredHosts ?? 0}'),
      ),
      NotificationType.agencyProbationPassed => l10n.notifAgencyPassed,
      NotificationType.agencyClosed => switch (item.target?.requiredHosts) {
        final int required => l10n.notifAgencyClosedProbation(
          l10n.agencyHostsCount(required),
          KFormat.bidiIsolate('${item.target?.activatedHosts ?? 0}'),
        ),
        null => l10n.notifAgencyClosedAdmin,
      },
      NotificationType.agencyHostReleased => l10n.notifAgencyHostReleased,
      NotificationType.hostApplicationApproved => l10n.notifHostApproved,
      NotificationType.hostApplicationRejected => l10n.notifHostRejected,
      NotificationType.referralRewardReversed => l10n.notifReferralReversed,
      NotificationType.ambassadorApplicationApproved =>
        l10n.notifAmbassadorApproved,
      NotificationType.ambassadorApplicationRejected =>
        l10n.notifAmbassadorRejected,
      NotificationType.ambassadorLevelUp => l10n.notifAmbassadorLevelUp,
      NotificationType.ambassadorRewardGranted => l10n.notifAmbassadorReward,
      NotificationType.ambassadorMembershipEnded => l10n.notifAmbassadorEnded,
      NotificationType.kycApproved => l10n.notifKycApproved,
      NotificationType.kycDeclined => l10n.notifKycDeclined,
      NotificationType.kycInReview => l10n.notifKycInReview,
      NotificationType.liveModerated => liveModeratedText(
        l10n,
        item.target,
        localeTag,
      ),
      // D273: the host's name only (never the reporter or the reason).
      NotificationType.liveStaffReport => l10n.notifLiveStaffReport(
        KFormat.bidiIsolate(item.target?.text ?? ''),
      ),
      // D288: never the reporter, the reason or the target.
      NotificationType.staffReportNew => l10n.notifStaffReportNew,
      // D290: a level-raise request's result.
      NotificationType.levelRaiseApproved => l10n.notifLevelRaiseApproved(
        KFormat.bidiIsolate('@${item.target?.text ?? ''}'),
        KFormat.bidiIsolate('${item.target?.level ?? ''}'),
      ),
      NotificationType.levelRaiseRejected => l10n.notifLevelRaiseRejected(
        KFormat.bidiIsolate('@${item.target?.text ?? ''}'),
      ),
      NotificationType.eventPrizeWon => l10n.notifEventPrizeWon,
      NotificationType.levelRaised => l10n.notifLevelRaised(
        KFormat.bidiIsolate('${item.target?.level ?? ''}'),
      ),
      // D301: a new item in «صندوق المؤسس» (the owner reads it in the panel).
      NotificationType.ownerFeedbackNew =>
        item.target?.feedbackKind == 'STAFF_REPORT'
            ? l10n.notifOwnerFeedbackReport
            : l10n.notifOwnerFeedbackFeature,
      // D301 follow-up: the owner's announcement, in this app's language.
      NotificationType.ownerAnnouncement => l10n.notifOwnerAnnouncement(
        KFormat.bidiIsolate(
          (localeTag.startsWith('ar')
                  ? item.target?.texts?.ar ?? item.target?.texts?.en
                  : item.target?.texts?.en ?? item.target?.texts?.ar) ??
              item.target?.text ??
              '',
        ),
      ),
      NotificationType.unknown => '',
    };
    return (text, item.type.isSystem ? null : who, name);
  }

  /// The family of a join answer (its name is the target's `text`).
  String _familyName(AppLocalizations l10n) =>
      KFormat.bidiIsolate(switch (item.target?.text) {
        final name? when name.isNotEmpty => name,
        _ => l10n.liveUserFamily,
      });

  /// Whether the target's `text` is already in the sentence (a family's
  /// name), so it is not repeated under it.
  bool get _textInSentence =>
      item.type == NotificationType.familyJoinAccepted ||
      item.type == NotificationType.familyJoinDeclined;

  @override
  Widget build(BuildContext context) {
    if (item.type != NotificationType.medalAwarded) {
      return _build(context, null);
    }
    // MEDAL_AWARDED carries only the code: the name and icon come from the
    // catalogue (`GET /medals`), when it loads.
    return Consumer(
      builder: (context, ref, _) {
        final code = item.target?.id;
        final medal = ref
            .watch(medalCatalogueProvider)
            .value
            ?.data
            .where((m) => m.code == code)
            .firstOrNull;
        return _build(context, medal);
      },
    );
  }

  Widget _build(BuildContext context, Medal? medal) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final (sentence, who, name) = _sentence(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      medalName: medal?.name,
    );
    final when =
        KFormat.relative(
          item.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    // D250: the team's full reason under the sentence («السبب: …»).
    final excerpt =
        item.type == NotificationType.liveModerated &&
            (item.target?.reason ?? item.target?.text) != null
        ? l10n.notifLiveModeratedReason(
            KFormat.bidiIsolate(item.target?.reason ?? item.target!.text!),
          )
        : item.target?.text;
    // D382: one paragraph (names bold) with the short time in grey after it.
    final body = t.body.copyWith(color: p.textPrimary, height: 1.35);
    const strong = TextStyle(fontWeight: FontWeight.w600);
    final bold = [
      if (who != null && name.isNotEmpty && who.startsWith(name)) name,
      ..._boldTargets(sentence),
    ];
    final spans = _emphasise(sentence, bold, strong);
    final shortWhen =
        KFormat.relativeShort(
          item.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    spans.add(
      TextSpan(
        text: ' \u2068$shortWhen\u2069',
        style: TextStyle(color: p.textTertiary),
      ),
    );
    final preview =
        excerpt != null &&
            item.type != NotificationType.follow &&
            !_textInSentence
        ? isolateHandles(excerpt)
        : null;
    final target = routeTo();
    final first = item.actors.firstOrNull;
    final kind = notificationKind(item.type, p);
    final Widget leading;
    if (item.type == NotificationType.medalAwarded) {
      leading = MedalIcon(iconKey: medal?.iconKey ?? '', size: avatar);
    } else if (first == null) {
      // No actor: the kind itself, in its colour.
      leading = Container(
        width: avatar,
        height: avatar,
        decoration: BoxDecoration(
          color: kind.color.withAlpha(36),
          shape: BoxShape.circle,
        ),
        child: Icon(kind.icon, size: 24, color: kind.color),
      );
    } else {
      leading = SizedBox.square(
        dimension: avatar,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            KAvatar(
              name: first.displayName.isEmpty
                  ? first.username
                  : first.displayName,
              imageUrl: first.avatarUrl,
              size: avatar,
            ),
            PositionedDirectional(
              end: -3,
              bottom: -3,
              child: _KindBadge(kind: kind),
            ),
          ],
        ),
      );
    }
    final thumbUrl = item.target?.thumbUrl;
    return Semantics(
      button: target != null,
      label: [
        if (!item.read) l10n.notifUnread,
        sentence,
        ?excerpt,
        when,
      ].join('. ').replaceAll(_isolates, ''),
      excludeSemantics: true,
      // A row is usable on any surface (the ink needs a Material).
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: target == null ? null : () => context.push(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.lg,
              vertical: KSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(style: body, children: spans),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: KSpacing.xs),
                        Text(
                          preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: body.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (thumbUrl != null) ...[
                  const SizedBox(width: KSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    child: ColoredBox(
                      color: p.surfaceRaised,
                      child: Image.network(
                        thumbUrl,
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) =>
                            const SizedBox.square(dimension: thumb),
                      ),
                    ),
                  ),
                ],
                // D382: unread is a small dot at the end of the first line.
                if (!item.read) ...[
                  const SizedBox(width: KSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      key: unreadDotKey,
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// D382: the target's name in the sentence (a family, a host), bold.
  List<String> _boldTargets(String sentence) {
    final text = switch (item.type) {
      NotificationType.familyJoinAccepted ||
      NotificationType.familyJoinDeclined ||
      NotificationType.liveStaffReport => item.target?.text,
      _ => null,
    };
    if (text == null || text.isEmpty) return const [];
    final isolated = KFormat.bidiIsolate(text);
    return sentence.contains(isolated) ? [isolated] : const [];
  }
}

/// [sentence] as spans, each of [terms] (its first occurrence) in [style].
List<InlineSpan> _emphasise(
  String sentence,
  List<String> terms,
  TextStyle style,
) {
  final marks = <(int, int)>[];
  for (final term in terms) {
    if (term.isEmpty) continue;
    final at = sentence.indexOf(term);
    if (at < 0) continue;
    final end = at + term.length;
    if (marks.any((m) => at < m.$2 && end > m.$1)) continue;
    marks.add((at, end));
  }
  marks.sort((a, b) => a.$1.compareTo(b.$1));
  final spans = <InlineSpan>[];
  var from = 0;
  for (final (start, end) in marks) {
    if (start > from) {
      spans.add(TextSpan(text: sentence.substring(from, start)));
    }
    spans.add(TextSpan(text: sentence.substring(start, end), style: style));
    from = end;
  }
  if (from < sentence.length) {
    spans.add(TextSpan(text: sentence.substring(from)));
  }
  return spans;
}

/// D382: a notification kind's badge colour and icon (palette tokens).
typedef NotificationKind = ({Color color, IconData icon});

/// D382: the colour and icon of [type] (green: accepted or done, red: likes,
/// blue: comments and mentions, orange: time and coins, error: removed or
/// refused).
NotificationKind notificationKind(
  NotificationType type,
  KPalette p,
) => switch (type) {
  NotificationType.likePost ||
  NotificationType.likeComment ||
  NotificationType.cpRequest ||
  NotificationType.cpAccepted => (
    color: p.primary,
    icon: Icons.favorite_rounded,
  ),
  NotificationType.comment ||
  NotificationType.reply => (color: p.info, icon: Icons.chat_bubble_rounded),
  NotificationType.mention => (
    color: p.info,
    icon: Icons.alternate_email_rounded,
  ),
  NotificationType.follow || NotificationType.followRequest => (
    color: p.success,
    icon: Icons.person_add_alt_1_rounded,
  ),
  NotificationType.repost => (color: p.success, icon: Icons.repeat_rounded),
  NotificationType.followRequestAccepted ||
  NotificationType.postPublished ||
  NotificationType.familyJoinAccepted ||
  NotificationType.agencyProbationPassed ||
  NotificationType.hostApplicationApproved ||
  NotificationType.ambassadorApplicationApproved ||
  NotificationType.kycApproved ||
  NotificationType.levelRaiseApproved => (
    color: p.success,
    icon: Icons.check_rounded,
  ),
  NotificationType.liveScheduledSoon ||
  NotificationType.kycInReview ||
  NotificationType.agencyProbationReminder ||
  NotificationType.premiumUsernameExpiring => (
    color: p.warning,
    icon: Icons.schedule_rounded,
  ),
  NotificationType.contentRemoved ||
  NotificationType.avatarRemoved ||
  NotificationType.coverRemoved ||
  NotificationType.animatedAvatarRemoved ||
  NotificationType.liveModerated => (
    color: p.error,
    icon: Icons.gpp_maybe_rounded,
  ),
  NotificationType.familyJoinDeclined ||
  NotificationType.hostApplicationRejected ||
  NotificationType.ambassadorApplicationRejected ||
  NotificationType.ambassadorMembershipEnded ||
  NotificationType.kycDeclined ||
  NotificationType.levelRaiseRejected ||
  NotificationType.agencyClosed => (color: p.error, icon: Icons.close_rounded),
  NotificationType.referralRewardReversed => (
    color: p.error,
    icon: Icons.undo_rounded,
  ),
  NotificationType.liveStaffReport ||
  NotificationType.staffReportNew => (color: p.error, icon: Icons.flag_rounded),
  NotificationType.medalAwarded ||
  NotificationType.eventPrizeWon ||
  NotificationType.ambassadorLevelUp ||
  NotificationType.ambassadorRewardGranted ||
  NotificationType.levelRaised ||
  NotificationType.premiumUsernameExpired => (
    color: p.warning,
    icon: Icons.workspace_premium_rounded,
  ),
  // D372: a gift on your post or reel «هدية الدعم» — the gift badge.
  NotificationType.bagItemReceived || NotificationType.contentGiftReceived => (
    color: p.primary,
    icon: Icons.card_giftcard_rounded,
  ),
  NotificationType.rechargeCoinsReceived ||
  NotificationType.rechargeCherryRequest ||
  NotificationType.rechargeOrderUpdate => (
    color: p.warning,
    icon: Icons.monetization_on_rounded,
  ),
  NotificationType.dataExportReady => (
    color: p.info,
    icon: Icons.download_rounded,
  ),
  NotificationType.agencyOpened || NotificationType.agencyHostReleased => (
    color: p.info,
    icon: Icons.business_center_rounded,
  ),
  NotificationType.ownerFeedbackNew => (
    color: p.info,
    icon: Icons.inbox_rounded,
  ),
  NotificationType.ownerAnnouncement => (
    color: p.primary,
    icon: Icons.campaign_rounded,
  ),
  NotificationType.unknown => (
    color: p.textTertiary,
    icon: Icons.notifications_rounded,
  ),
};

/// D382: the kind's small circle at the photo's bottom corner (a white
/// icon, ringed in the page colour).
class _KindBadge extends StatelessWidget {
  const new({required this.kind});

  final NotificationKind kind;

  static const double size = 20;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: kind.color,
      shape: BoxShape.circle,
      border: Border.all(color: context.palette.background, width: 2),
    ),
    alignment: Alignment.center,
    child: Icon(kind.icon, size: 11, color: const Color(0xFFFFFFFF)),
  );
}

final RegExp _isolates = RegExp('[\u2066-\u2069]');

/// `/settings/notifications` (CP-009): one switch per kind. Scheduled posts
/// and removed content always notify.
class NotificationSettingsScreen extends ConsumerWidget {
  const new({super.key});

  static Key switchKey(NotificationSetting s) =>
      Key('notificationSettings.${s.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.notificationsSettings)),
      body: switch (ref.watch(notificationSettingsProvider)) {
        AsyncValue(:final value?) => ListView(
          children: [
            // D152: pushes cannot show on this phone (permission off).
            const PushPermissionBanner(),
            for (final (s, title, subtitle) in [
              (
                NotificationSetting.likes,
                l10n.notifSettingLikes,
                l10n.notifSettingLikesBody,
              ),
              (NotificationSetting.comments, l10n.notifSettingComments, null),
              (NotificationSetting.mentions, l10n.notifSettingMentions, null),
              (NotificationSetting.follows, l10n.notifSettingFollows, null),
              (NotificationSetting.reposts, l10n.notifSettingReposts, null),
              (
                NotificationSetting.lives,
                l10n.notifSettingLives,
                l10n.notifSettingLivesBody,
              ),
              // D152: family chat pushes.
              (
                NotificationSetting.messages,
                l10n.notifSettingMessages,
                l10n.notifSettingMessagesBody,
              ),
              // v1.85-live (D305): the global strips in the lives (the same
              // switches as in every live's settings sheet).
              (
                NotificationSetting.giftStrip,
                l10n.liveStripShowGifts,
                l10n.liveStripSwitchHint,
              ),
              (
                NotificationSetting.gameStrip,
                l10n.liveStripShowGames,
                l10n.liveStripSwitchHint,
              ),
            ])
              SwitchListTile(
                key: switchKey(s),
                value: s.of(value),
                title: Text(title),
                subtitle: subtitle == null ? null : Text(subtitle),
                onChanged: (on) async {
                  try {
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .change(s, on: on);
                  } on Object catch (e) {
                    if (context.mounted) {
                      KSnack.error(
                        context,
                        failureMessage(l10n, toAppFailure(e)),
                      );
                    }
                  }
                },
              ),
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                l10n.notifSettingsHint,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// v1.69-social (D204): the sentence of a recharge order's latest event.
String rechargeOrderNotificationText(
  AppLocalizations l10n,
  String? event,
  int coins,
) {
  final c = KFormat.bidiIsolate(KFormat.grouped(coins));
  return switch (event) {
    'CREATED' => l10n.notifRechargeOrderCreated(c),
    'DETAILS_SENT' => l10n.notifRechargeOrderDetails,
    'PAID' => l10n.notifRechargeOrderPaid,
    'COMPLETED' || 'COMPLETED_BY_ADMIN' => l10n.notifRechargeOrderCompleted(c),
    'DISPUTED' => l10n.notifRechargeOrderDisputed,
    'REFUNDED_TO_AGENT' => l10n.notifRechargeOrderRefunded,
    'CANCELLED' => l10n.notifRechargeOrderCancelled,
    'EXPIRED' => l10n.notifRechargeOrderExpired,
    'ADMIN_MESSAGE' => l10n.notifRechargeOrderAdmin,
    _ => l10n.notifRechargeOrderMessage,
  };
}

/// v1.60-live (D250, §10.91.5): the sentence of a LIVE_MODERATED row — the
/// live ended, with the ban from going live / the suspension / the device ban
/// and its end (or «نهائياً»). The reason is shown under it.
String liveModeratedText(
  AppLocalizations l10n,
  NotificationTarget? target,
  String localeTag,
) {
  final at = target?.endsAt?.toLocal();
  final when = at == null
      ? null
      : KFormat.bidiIsolate(
          '${KFormat.date(at, localeTag)} ${KFormat.time(at, localeTag)}',
        );
  return switch ((target?.moderation, when)) {
    ('NO_LIVE', final String w) => l10n.notifLiveModeratedNoLive(w),
    ('SUSPEND', final String w) => l10n.notifLiveModeratedSuspend(w),
    ('DEVICE_BAN', final String w) => l10n.notifLiveModeratedDevice(w),
    ('DEVICE_BAN', null) when target?.permanent ?? false =>
      l10n.notifLiveModeratedDevicePermanent,
    _ => l10n.notifLiveModeratedEnd,
  };
}
