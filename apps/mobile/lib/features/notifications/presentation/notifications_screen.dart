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
  static Key rowKey(String id) => Key('notifications.row.$id');
  static Key sectionKey(NotificationSection s) =>
      Key('notifications.section.${s.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // D152: the first visit is a moment to explain notifications.
      PushPermissionTrigger(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: KAppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          IconButton(
            key: settingsKey,
            tooltip: l10n.notificationsSettings,
            onPressed: () => context.push(AppRoutes.notificationSettings),
            icon: const Icon(Icons.settings_outlined),
          ),
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
    padding: const EdgeInsetsDirectional.fromSTEB(
      KSpacing.lg,
      KSpacing.lg,
      KSpacing.lg,
      KSpacing.xs,
    ),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: context.textStyles.bodyStrong.copyWith(
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

  static const double avatar = 44;
  static const double thumb = 44;

  /// Where a tap goes, or `null` (removed content, an unknown target).
  String? routeTo() {
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
      NotificationType.medalAwarded => switch (medalName) {
        final name? => l10n.notifMedalAwarded(KFormat.bidiIsolate(name)),
        null => l10n.notifMedalAwardedUnnamed,
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
    final excerpt = item.target?.text;
    final body = t.body.copyWith(color: p.textPrimary);
    final spans = <InlineSpan>[];
    final at = who == null || name.isEmpty || !who.startsWith(name)
        ? -1
        : sentence.indexOf(who);
    if (at < 0) {
      spans.add(TextSpan(text: sentence));
    } else {
      spans
        ..add(TextSpan(text: sentence.substring(0, at)))
        ..add(
          TextSpan(
            text: name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        )
        ..add(TextSpan(text: sentence.substring(at + name.length)));
    }
    if (excerpt != null &&
        item.type != NotificationType.follow &&
        !_textInSentence) {
      spans.add(
        TextSpan(
          text: '\n${isolateHandles(excerpt)}',
          style: TextStyle(color: p.textSecondary),
        ),
      );
    }
    final target = routeTo();
    final first = item.actors.firstOrNull;
    final leading = item.type == NotificationType.medalAwarded
        ? MedalIcon(iconKey: medal?.iconKey ?? '', size: avatar)
        : first == null
        ? Container(
            width: avatar,
            height: avatar,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.type == NotificationType.contentRemoved
                  ? Icons.gpp_maybe_outlined
                  : item.type.isSystem &&
                        item.type != NotificationType.postPublished
                  ? Icons.workspace_premium_rounded
                  : Icons.schedule_rounded,
              color: item.type == NotificationType.contentRemoved
                  ? p.error
                  : p.primary,
            ),
          )
        : KAvatar(
            name: first.displayName.isEmpty
                ? first.username
                : first.displayName,
            imageUrl: first.avatarUrl,
            size: avatar,
          );
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
      child: Material(
        color: item.read ? const Color(0x00000000) : p.primary.withAlpha(20),
        child: InkWell(
          onTap: target == null ? null : () => context.push(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.lg,
              vertical: KSpacing.sm,
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
                      const SizedBox(height: 2),
                      Text(
                        when,
                        style: t.caption.copyWith(color: p.textTertiary),
                      ),
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
                if (!item.read) ...[
                  const SizedBox(width: KSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: avatar / 2 - 4),
                    child: Container(
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
