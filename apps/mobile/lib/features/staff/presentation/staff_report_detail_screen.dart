import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/domain/staff_report_view.dart';
import 'package:kabso_live/features/staff/presentation/staff_reports_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.93-social (D296, CONVENTIONS §10.109; owner: «يجب عند الضغط عليه الدخول
/// إلى البوست، ويكون له أزرار صلاحية للتحذير والحظر ومنع النشر … عندما يضغط على
/// البلاغ يدخل إلى الشات المبلغ عنه ويكون عنده إجراء»): one report of «بلاغات»
/// opened — the reported content as the Kabso Team sees it, whatever its
/// state (hidden, deleted, private, blocked: the «محتوى مُبلّغ عنه» banner says
/// which), a reported DM as a read-only view of the report's frozen snapshot
/// (never the conversation), and the action bar: only the actions the
/// server allows the caller's role, each confirmed in a dialog with a reason;
/// an action resolves the report automatically (owner). «تم حله» stays for a
/// report that needs no action.
class StaffReportDetailScreen extends ConsumerStatefulWidget {
  const new({required this.reportId, super.key});

  final String reportId;

  static const bannerKey = Key('staffReport.banner');
  static const actionBarKey = Key('staffReport.actions');
  static const dmViewKey = Key('staffReport.dm');
  static const threadKey = Key('staffReport.thread');
  static const reportedMessageKey = Key('staffReport.thread.reported');
  static const postViewKey = Key('staffReport.post');
  static const commentKey = Key('staffReport.comment');
  static const deletedKey = Key('staffReport.deleted');
  static const resolveKey = Key('staffReport.resolve');
  static const openProfileKey = Key('staffReport.openProfile');
  static const enterLiveKey = Key('staffReport.enterLive');
  static Key action(StaffReportAction a) => Key('staffReport.action.${a.wire}');

  @override
  ConsumerState<StaffReportDetailScreen> createState() =>
      _StaffReportDetailScreenState();
}

class _StaffReportDetailScreenState
    extends ConsumerState<StaffReportDetailScreen> {
  bool _busy = false;

  void _reload() {
    ref
      ..invalidate(staffReportViewProvider(widget.reportId))
      ..invalidate(staffSharedReportsProvider(SharedReportTab.open))
      ..invalidate(staffSharedReportsProvider(SharedReportTab.resolved));
    if (ref.exists(staffOpenReportsProvider)) {
      unawaited(ref.read(staffOpenReportsProvider.notifier).refresh());
    }
  }

  Future<void> _guarded(Future<void> Function() run, String done) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await run();
      if (mounted) KSnack.success(context, done);
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!mounted) return;
      if (failure.code == ErrorCode.reportAlreadyResolved) {
        KSnack.info(context, l10n.staffSharedAlreadyResolved);
      } else {
        KSnack.error(context, failureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _reload();
    }
  }

  Future<void> _act(StaffReportView view, StaffReportAction action) async {
    final input = await showDialog<StaffReportActionInput>(
      context: context,
      builder: (_) => StaffReportActionDialog(
        action: action,
        targetName: _nameOf(view.target.author),
        targetType: view.target.type,
        restrictions: view.restrictions,
      ),
    );
    if (input == null || !mounted) return;
    await _guarded(
      () => ref
          .read(staffRepositoryProvider)
          .actOnReport(
            widget.reportId,
            action,
            reason: input.reason,
            restriction: input.restriction,
            days: input.days,
          ),
      context.l10n.staffReportActionDone,
    );
  }

  Future<void> _resolve() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const SharedReportResolveDialog(),
    );
    if (note == null || !mounted) return;
    await _guarded(
      () => ref
          .read(staffRepositoryProvider)
          .resolveReport(widget.reportId, note: note),
      context.l10n.staffSharedDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = ref.watch(staffReportViewProvider(widget.reportId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffReportViewTitle)),
      body: switch (page) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async {
            _reload();
            await ref.read(staffReportViewProvider(widget.reportId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.xl,
            ),
            children: [
              _ReportedBanner(view: value),
              const SizedBox(height: KSpacing.md),
              _TargetView(view: value),
              const SizedBox(height: KSpacing.md),
              SharedReportCard(report: value.report),
            ],
          ),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Text(
              failureMessage(l10n, toAppFailure(error)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: switch (page) {
        AsyncData(:final value) when value.report.isOpen => _ActionBar(
          view: value,
          busy: _busy,
          onAction: (a) => unawaited(_act(value, a)),
          onResolve: value.canResolve ? () => unawaited(_resolve()) : null,
        ),
        _ => null,
      },
    );
  }
}

String _nameOf(UserSummary? u) {
  if (u == null) return '';
  return u.displayName.isNotEmpty ? u.displayName : '@${u.username}';
}

/// The words of an action's button (REMOVE_CONTENT ends a reported live).
String staffReportActionLabel(
  AppLocalizations l10n,
  StaffReportAction a, {
  String targetType = '',
}) => switch (a) {
  StaffReportAction.warn => l10n.staffReportActionWarn,
  StaffReportAction.restrict => l10n.staffReportActionRestrict,
  StaffReportAction.suspend => l10n.staffReportActionSuspend,
  StaffReportAction.ban => l10n.staffReportActionBan,
  StaffReportAction.removeContent =>
    targetType == 'LIVE_ROOM'
        ? l10n.staffReportActionEndLive
        : l10n.staffReportActionRemove,
  StaffReportAction.deleteContent => l10n.staffReportActionDeleteContent,
  StaffReportAction.deleteAccount => l10n.staffReportActionDeleteAccount,
};

String staffRestrictionLabel(AppLocalizations l10n, StaffRestriction r) =>
    switch (r) {
      StaffRestriction.noPosting => l10n.staffReportRestrictNoPosting,
      StaffRestriction.noLive => l10n.staffReportRestrictNoLive,
      StaffRestriction.chatMute => l10n.staffReportRestrictChat,
    };

String staffTargetStateLabel(AppLocalizations l10n, StaffTargetState s) =>
    switch (s) {
      StaffTargetState.visible => l10n.staffReportStateVisible,
      StaffTargetState.hidden => l10n.staffReportStateHidden,
      StaffTargetState.deleted => l10n.staffReportStateDeleted,
      StaffTargetState.expired => l10n.staffReportStateExpired,
      StaffTargetState.live => l10n.staffReportStateLive,
      StaffTargetState.ended => l10n.staffReportStateEnded,
      StaffTargetState.gone => l10n.staffReportStateGone,
    };

/// «محتوى مُبلّغ عنه» with the item's type, the reason and its state.
class _ReportedBanner extends StatelessWidget {
  const new({required this.view});

  final StaffReportView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final state = view.target.state;
    final stateColor = switch (state) {
      StaffTargetState.visible || StaffTargetState.live => p.success,
      StaffTargetState.hidden || StaffTargetState.expired => p.warning,
      _ => p.error,
    };
    Widget chip(String label, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: t.caption.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Container(
      key: StaffReportDetailScreen.bannerKey,
      decoration: BoxDecoration(
        color: KBrandColors.red600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KRadius.md),
        border: const BorderDirectional(
          start: BorderSide(color: KBrandColors.red600, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: KBrandColors.red600,
                size: 20,
              ),
              const SizedBox(width: KSpacing.xs),
              Expanded(
                child: Text(
                  l10n.staffReportBanner,
                  style: t.bodyStrong.copyWith(color: KBrandColors.red600),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Wrap(
            spacing: KSpacing.xs,
            runSpacing: KSpacing.xxs,
            children: [
              chip(sharedReportTypeLabel(l10n, view.target.type), p.primary),
              chip(
                sharedReportReasonLabel(l10n, view.report.reason),
                KBrandColors.red600,
              ),
              chip(staffTargetStateLabel(l10n, state), stateColor),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.staffReportBannerHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The person who wrote the item.
class _AuthorRow extends StatelessWidget {
  const new({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Row(
      children: [
        KAvatar(name: _nameOf(user), imageUrl: user.avatarUrl, size: 40),
        const SizedBox(width: KSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameOf(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong,
              ),
              Text(
                KHandle.isolated(user.username),
                style: t.caption.copyWith(color: context.palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A box like the feed's card.
class _Panel extends StatelessWidget {
  const new({required this.child, this.highlighted = false, super.key});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(
          color: highlighted ? KBrandColors.red600 : p.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(KSpacing.md), child: child),
    );
  }
}

/// One picture or video poster (a failed load shows the blank frame).
class _MediaTile extends StatelessWidget {
  const new({required this.media, this.reel = false});

  final MediaAsset media;
  final bool reel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final video = media.type == MediaType.video;
    final url = video ? (media.posterUrl ?? media.thumbUrl) : media.url;
    final ratio = media.width > 0 && media.height > 0
        ? media.width / media.height
        : 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.md),
      child: AspectRatio(
        aspectRatio: ratio.clamp(0.56, 1.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.palette.surfaceRaised),
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            if (video)
              Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            if (video)
              PositionedDirectional(
                top: KSpacing.sm,
                start: KSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: 2,
                    ),
                    child: Text(
                      reel
                          ? l10n.staffReportReelMark
                          : l10n.staffReportVideoMark,
                      style: context.textStyles.caption.copyWith(
                        color: Colors.white,
                      ),
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

/// The reported post or reel as the staff see it (read-only: no like, no
/// view counted).
class _PostView extends StatelessWidget {
  const new({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final at = post.createdAt.toLocal();
    return _Panel(
      key: StaffReportDetailScreen.postViewKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorRow(user: post.author),
          const SizedBox(height: KSpacing.sm),
          if (post.text.isNotEmpty)
            Text(post.text, style: t.body.copyWith(height: 1.5)),
          for (final m in post.media) ...[
            const SizedBox(height: KSpacing.sm),
            _MediaTile(media: m, reel: post.isReel),
          ],
          const SizedBox(height: KSpacing.xs),
          Text(
            '${KFormat.date(at, locale)} ${KFormat.time(at, locale)}',
            style: t.caption.copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// D155: the reported message as a read-only conversation built only from the
/// report's snapshot — the sender's bubble with its time, the two people,
/// and the privacy line (every opening is audited by the server).
class _DmSnapshotView extends StatelessWidget {
  const new({required this.target});

  final StaffReportedItem target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final s = target.dmSnapshot;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sender = target.author != null
        ? _nameOf(target.author)
        : (s?.sender == null ? '' : '@${s!.sender}');
    final recipient = _nameOf(target.dmRecipient);
    final Widget content;
    if (s == null || s.purged) {
      content = Text(
        l10n.staffReportDmPurged,
        style: t.body.copyWith(fontStyle: FontStyle.italic),
      );
    } else if (s.kind == 'IMAGE' && s.mediaUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Image.network(
            s.mediaUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Center(child: Text(l10n.staffReportDmImage)),
          ),
        ),
      );
    } else if (s.kind == 'IMAGE') {
      content = Text(l10n.staffReportDmImage, style: t.body);
    } else if (s.kind == 'VOICE') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, size: 18),
          const SizedBox(width: KSpacing.xs),
          Text(l10n.staffReportDmVoice, style: t.body),
        ],
      );
    } else if (s.kind == 'GIFT') {
      content = Text(
        l10n.staffReportDmGift(s.giftCode ?? '', '${s.quantity ?? 1}'),
        style: t.body,
      );
    } else {
      content = Text(
        s.text ?? s.token ?? '',
        style: t.body.copyWith(height: 1.45),
      );
    }
    return _Panel(
      key: StaffReportDetailScreen.dmViewKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: p.textSecondary,
              ),
              const SizedBox(width: KSpacing.xs),
              Expanded(
                child: Text(l10n.staffReportDmTitle, style: t.bodyStrong),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
          Text(
            l10n.staffReportDmBetween(
              KFormat.bidiIsolate(sender),
              KFormat.bidiIsolate(recipient),
            ),
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          if (target.author != null) ...[
            Row(
              children: [
                KAvatar(
                  name: _nameOf(target.author),
                  imageUrl: target.author!.avatarUrl,
                  size: 28,
                ),
                const SizedBox(width: KSpacing.xs),
                Text(
                  KHandle.isolated(target.author!.username),
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.lg),
                border: Border.all(color: KBrandColors.red600, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  content,
                  if (s != null) ...[
                    const SizedBox(height: KSpacing.xxs),
                    Text(
                      '${KFormat.date(s.sentAt.toLocal(), locale)} '
                      '${KFormat.time(s.sentAt.toLocal(), locale)}',
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.staffReportDmPrivacy,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (target.state == StaffTargetState.expired)
            Text(
              l10n.staffReportDmExpired,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// D296 (owner: «مثل طريقة نزاع وكيل الشحن»): the whole conversation between
/// the two people as the report froze it — every message that existed then,
/// oldest first, the reported person on one side and the reporter on the
/// other, the reported message outlined in red. Read only; the server audits
/// every opening.
class _ThreadView extends StatelessWidget {
  const new({required this.target, required this.thread, this.framed = true});

  final StaffReportedItem target;
  final StaffThread thread;

  /// Inside its own panel (a DM report) or inside the profile's (a person).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(DateTime at) {
      final local = at.toLocal();
      return '${KFormat.date(local, locale)} ${KFormat.time(local, locale)}';
    }

    final reported = _nameOf(target.author);
    final reporter = _nameOf(target.dmRecipient);
    final body = Column(
      key: StaffReportDetailScreen.threadKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: p.textSecondary),
            const SizedBox(width: KSpacing.xs),
            Expanded(
              child: Text(l10n.staffReportThreadTitle, style: t.bodyStrong),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          l10n.staffReportDmBetween(
            KFormat.bidiIsolate(reported),
            KFormat.bidiIsolate(reporter),
          ),
          style: t.caption.copyWith(color: p.textSecondary),
        ),
        Text(
          l10n.staffReportThreadCaptured(when(thread.capturedAt)),
          style: t.caption.copyWith(color: p.textSecondary),
        ),
        if (thread.truncated)
          Text(
            l10n.staffReportThreadTruncated('${thread.messages.length}'),
            style: t.caption.copyWith(color: p.warning),
          ),
        const SizedBox(height: KSpacing.sm),
        if (thread.messages.isEmpty)
          Text(l10n.staffReportThreadEmpty, style: t.body)
        else
          for (final m in thread.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.xs),
              child: _ThreadBubble(message: m, time: when(m.sentAt)),
            ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.staffReportThreadPrivacy,
          style: t.caption.copyWith(color: p.textSecondary),
        ),
        if (target.state == StaffTargetState.expired)
          Text(
            l10n.staffReportDmExpired,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
      ],
    );
    return framed
        ? _Panel(key: StaffReportDetailScreen.dmViewKey, child: body)
        : body;
  }
}

/// One message of the frozen conversation: the reported person at the start,
/// the reporter at the end (as their own chat shows it).
class _ThreadBubble extends StatelessWidget {
  const new({required this.message, required this.time});

  final StaffThreadMessage message;
  final String time;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final m = message;
    final reporterSide = !m.fromReported;
    final Widget content;
    if (m.kind == 'IMAGE' && m.mediaUrl != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: SizedBox(
          width: 180,
          height: 180,
          child: Image.network(
            m.mediaUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Center(child: Text(l10n.staffReportDmImage)),
          ),
        ),
      );
    } else if (m.kind == 'IMAGE' || m.kind == 'VOICE') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            m.kind == 'VOICE' ? Icons.mic_rounded : Icons.image_outlined,
            size: 18,
          ),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Text(
              m.mediaMissing
                  ? l10n.staffReportThreadMediaMissing
                  : (m.kind == 'VOICE'
                        ? l10n.staffReportDmVoice
                        : l10n.staffReportDmImage),
              style: t.body,
            ),
          ),
        ],
      );
    } else if (m.kind == 'GIFT') {
      content = Text(
        l10n.staffReportDmGift(m.giftCode ?? '', '${m.quantity ?? 1}'),
        style: t.body,
      );
    } else {
      content = Text(
        m.text ?? m.token ?? '',
        style: t.body.copyWith(height: 1.4),
      );
    }
    return Align(
      alignment: reporterSide
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        key: m.reported ? StaffReportDetailScreen.reportedMessageKey : null,
        constraints: const BoxConstraints(maxWidth: 270),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: reporterSide
              ? p.primary.withValues(alpha: 0.10)
              : p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.lg),
          border: m.reported
              ? Border.all(color: KBrandColors.red600, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.reported)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.xxs),
                child: Text(
                  l10n.staffReportThreadReported,
                  style: t.caption.copyWith(
                    color: KBrandColors.red600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            content,
            const SizedBox(height: KSpacing.xxs),
            Text(
              '${m.sender == null ? '' : '${KHandle.isolated(m.sender!)} · '}'
              '$time',
              style: t.caption.copyWith(color: p.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// What was reported, by type.
class _TargetView extends StatelessWidget {
  const new({required this.view});

  final StaffReportView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final target = view.target;
    final muted = t.caption.copyWith(color: p.textSecondary);
    Widget deleted() => _Panel(
      key: StaffReportDetailScreen.deletedKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.staffReportContentDeleted, style: t.bodyStrong),
          if (view.report.previewText case final text?
              when text.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xs),
            Text(l10n.staffReportSnapshotShown, style: muted),
            const SizedBox(height: KSpacing.xs),
            Text(text, style: t.body),
          ],
        ],
      ),
    );
    if (target.type == 'DM_MESSAGE') {
      // D296 (owner): the whole conversation as frozen by the report; an
      // older report has the reported message only.
      final thread = target.dmThread;
      return thread == null
          ? _DmSnapshotView(target: target)
          : _ThreadView(target: target, thread: thread);
    }
    if (target.state.removed && target.post == null && target.story == null) {
      return deleted();
    }
    switch (target.type) {
      case 'POST':
        final post = target.post;
        if (post == null) return deleted();
        return _PostView(post: post);
      case 'COMMENT':
        final c = target.comment;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c != null)
              _Panel(
                key: StaffReportDetailScreen.commentKey,
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.staffReportReportedComment, style: muted),
                    const SizedBox(height: KSpacing.xs),
                    if (target.author != null) _AuthorRow(user: target.author!),
                    const SizedBox(height: KSpacing.xs),
                    Text(c.text, style: t.body),
                  ],
                ),
              ),
            if (target.post != null) ...[
              const SizedBox(height: KSpacing.md),
              Text(l10n.staffReportOnPost, style: muted),
              const SizedBox(height: KSpacing.xs),
              _PostView(post: target.post!),
            ],
          ],
        );
      case 'STORY':
        final s = target.story;
        if (s == null) return deleted();
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (target.author != null) _AuthorRow(user: target.author!),
              if (s.media != null) ...[
                const SizedBox(height: KSpacing.sm),
                _MediaTile(media: s.media!),
              ],
              if (s.text.isNotEmpty) ...[
                const SizedBox(height: KSpacing.xs),
                Text(s.text, style: t.body),
              ],
            ],
          ),
        );
      case 'USER' || 'PROFILE_LINK':
        final u = target.author;
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (u != null) _AuthorRow(user: u),
              if (target.text case final text? when text.isNotEmpty) ...[
                const SizedBox(height: KSpacing.xs),
                Text(text, style: t.body),
              ],
              if (u != null && !target.state.removed) ...[
                const SizedBox(height: KSpacing.sm),
                OutlinedButton.icon(
                  key: StaffReportDetailScreen.openProfileKey,
                  onPressed: () =>
                      context.push(AppRoutes.userProfile(u.username)),
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(l10n.staffReportOpenProfile),
                ),
              ],
              // D296: reported from the conversation — the conversation too.
              if (target.dmThread case final thread?) ...[
                const SizedBox(height: KSpacing.md),
                _ThreadView(target: target, thread: thread, framed: false),
              ],
            ],
          ),
        );
      case 'LIVE_ROOM' || 'LIVE_CHAT_MESSAGE':
        final live = target.live;
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (target.author != null) _AuthorRow(user: target.author!),
              if (target.text case final text? when text.isNotEmpty) ...[
                const SizedBox(height: KSpacing.sm),
                Text(text, style: t.body),
              ],
              if (live != null) ...[
                const SizedBox(height: KSpacing.sm),
                Text(live.title, style: t.bodyStrong),
                if (live.isLive)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.sm),
                    child: FilledButton.icon(
                      key: StaffReportDetailScreen.enterLiveKey,
                      onPressed: () => context.push(
                        AppRoutes.liveRoomStaffReports(live.roomId),
                      ),
                      icon: const Icon(Icons.live_tv_rounded, size: 18),
                      label: Text(l10n.staffReportEnterLive),
                    ),
                  )
                else
                  Text(l10n.staffReportLiveEnded, style: muted),
              ],
            ],
          ),
        );
      default:
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (target.author != null) _AuthorRow(user: target.author!),
              const SizedBox(height: KSpacing.xs),
              Text(target.text ?? view.report.previewText ?? '', style: t.body),
            ],
          ),
        );
    }
  }
}

/// The staff action bar: only what the caller's role allows, and «تم حله».
class _ActionBar extends StatelessWidget {
  const new({
    required this.view,
    required this.busy,
    required this.onAction,
    this.onResolve,
  });

  final StaffReportView view;
  final bool busy;
  final ValueChanged<StaffReportAction> onAction;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    IconData icon(StaffReportAction a) => switch (a) {
      StaffReportAction.warn => Icons.warning_amber_rounded,
      StaffReportAction.restrict => Icons.block_rounded,
      StaffReportAction.suspend => Icons.timer_outlined,
      StaffReportAction.ban => Icons.gavel_rounded,
      StaffReportAction.removeContent => Icons.visibility_off_outlined,
      StaffReportAction.deleteContent => Icons.delete_forever_rounded,
      StaffReportAction.deleteAccount => Icons.person_remove_rounded,
    };
    return DecoratedBox(
      key: StaffReportDetailScreen.actionBarKey,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                view.actions.isEmpty
                    ? l10n.staffReportNoActions
                    : l10n.staffReportAutoResolve,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.xs),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final a in view.actions)
                    OutlinedButton.icon(
                      key: StaffReportDetailScreen.action(a),
                      onPressed: busy ? null : () => onAction(a),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: a == StaffReportAction.warn
                            ? p.textPrimary
                            : KBrandColors.red600,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(icon(a), size: 18),
                      label: Text(
                        staffReportActionLabel(
                          l10n,
                          a,
                          targetType: view.target.type,
                        ),
                      ),
                    ),
                  if (onResolve != null)
                    FilledButton.icon(
                      key: StaffReportDetailScreen.resolveKey,
                      onPressed: busy ? null : onResolve,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(l10n.staffSharedResolve),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What an action dialog returns.
@immutable
class StaffReportActionInput {
  const new({required this.reason, this.restriction, this.days});

  final String reason;
  final StaffRestriction? restriction;
  final int? days;
}

/// D296: the confirmation of an action — what it does to whom, the
/// restriction and the duration where they apply, and the reason (required,
/// kept in the log; the person sees it for a restriction). Pops the input,
/// or null.
class StaffReportActionDialog extends StatefulWidget {
  const new({
    required this.action,
    required this.targetName,
    this.targetType = '',
    this.restrictions = const [],
    super.key,
  });

  final StaffReportAction action;
  final String targetName;
  final String targetType;
  final List<StaffRestriction> restrictions;

  static const reasonKey = Key('staffReport.dialog.reason');
  static const applyKey = Key('staffReport.dialog.apply');
  static const confirmKey = Key('staffReport.dialog.confirm');
  static Key days(int d) => Key('staffReport.dialog.days.$d');
  static Key restriction(StaffRestriction r) =>
      Key('staffReport.dialog.restriction.${r.wire}');

  /// The durations offered (days).
  static const durations = [1, 3, 7, 30];

  @override
  State<StaffReportActionDialog> createState() =>
      _StaffReportActionDialogState();
}

class _StaffReportActionDialogState extends State<StaffReportActionDialog> {
  final _reason = TextEditingController();
  final _confirm = TextEditingController();
  late StaffRestriction? _restriction = widget.restrictions.firstOrNull;
  int _days = 7;
  bool _tried = false;

  /// The typed word matches (the localized word, or DELETE in any language).
  bool _confirmed(String word) {
    final typed = _confirm.text.trim();
    return typed == word ||
        typed.toUpperCase() == StaffReportAction.confirmWire;
  }

  @override
  void dispose() {
    _reason.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final name = KFormat.bidiIsolate(widget.targetName);
    final a = widget.action;
    final title = switch (a) {
      StaffReportAction.warn => l10n.staffReportConfirmWarn(name),
      StaffReportAction.restrict => l10n.staffReportConfirmRestrict(name),
      StaffReportAction.suspend => l10n.staffReportConfirmSuspend(name),
      StaffReportAction.ban => l10n.staffReportConfirmBan(name),
      StaffReportAction.removeContent => l10n.staffReportConfirmRemove,
      StaffReportAction.deleteContent => l10n.staffReportConfirmDeleteContent,
      StaffReportAction.deleteAccount => l10n.staffReportConfirmDeleteAccount(
        name,
      ),
    };
    final hint = switch (a) {
      StaffReportAction.ban => l10n.staffReportConfirmBanHint,
      StaffReportAction.suspend => l10n.staffReportConfirmSuspendHint,
      StaffReportAction.deleteContent =>
        l10n.staffReportConfirmDeleteContentHint,
      StaffReportAction.deleteAccount =>
        l10n.staffReportConfirmDeleteAccountHint,
      _ => null,
    };
    final empty = _reason.text.trim().isEmpty;
    final word = l10n.staffReportConfirmWord;
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint != null) ...[
              Text(hint, style: t.caption.copyWith(color: p.error)),
              const SizedBox(height: KSpacing.sm),
            ],
            if (a == StaffReportAction.restrict) ...[
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final r in widget.restrictions)
                    ChoiceChip(
                      key: StaffReportActionDialog.restriction(r),
                      label: Text(staffRestrictionLabel(l10n, r)),
                      selected: _restriction == r,
                      onSelected: (_) => setState(() => _restriction = r),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            if (a.timed) ...[
              Text(l10n.staffReportDuration, style: t.caption),
              const SizedBox(height: KSpacing.xxs),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final d in StaffReportActionDialog.durations)
                    ChoiceChip(
                      key: StaffReportActionDialog.days(d),
                      label: Text(l10n.staffReportDays(d)),
                      selected: _days == d,
                      onSelected: (_) => setState(() => _days = d),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            TextField(
              key: StaffReportActionDialog.reasonKey,
              controller: _reason,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.staffReportReason,
                errorText: _tried && empty
                    ? l10n.staffReportReasonRequired
                    : null,
              ),
            ),
            // Owner (2026-11-06): a permanent deletion is typed out first.
            if (a.permanent) ...[
              const SizedBox(height: KSpacing.xs),
              TextField(
                key: StaffReportActionDialog.confirmKey,
                controller: _confirm,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.staffReportTypeToConfirm(word),
                  errorText: _tried && !_confirmed(word)
                      ? l10n.staffReportConfirmMismatch
                      : null,
                ),
              ),
              const SizedBox(height: KSpacing.xs),
            ],
            Text(
              l10n.staffReportAutoResolve,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: StaffReportActionDialog.applyKey,
          style: a.destructive
              ? FilledButton.styleFrom(backgroundColor: KBrandColors.red600)
              : null,
          onPressed: () {
            // Read now, not the last build's value: the text just changed.
            if (_reason.text.trim().isEmpty ||
                (a == StaffReportAction.restrict && _restriction == null) ||
                (a.permanent && !_confirmed(word))) {
              setState(() => _tried = true);
              return;
            }
            Navigator.of(context).pop(
              StaffReportActionInput(
                reason: _reason.text.trim(),
                restriction: a == StaffReportAction.restrict
                    ? _restriction
                    : null,
                days: a.timed ? _days : null,
              ),
            );
          },
          child: Text(
            a == StaffReportAction.warn
                ? l10n.staffReportApply
                : staffReportActionLabel(
                    l10n,
                    a,
                    targetType: widget.targetType,
                  ),
          ),
        ),
      ],
    );
  }
}
