import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/application/family_chat_controller.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/families/presentation/family_widgets.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families/:familyId/chat` (مراسلة العائلة, CP-022, §10.25): the family's
/// text chat, members only. There is no push: while the screen is open it
/// reads the newest page every [pollEvery]. A long press offers delete
/// (own messages; the leader and deputies for others, by the server's
/// rules) and report (others' messages). A muted member reads only.
class FamilyChatScreen extends ConsumerStatefulWidget {
  const new({required this.familyId, super.key});

  final String familyId;

  /// How often the open chat reads the newest messages again.
  static Duration pollEvery = const Duration(seconds: 5);

  static const inputKey = Key('familyChat.input');
  static const sendKey = Key('familyChat.send');
  static const mutedKey = Key('familyChat.muted');
  static const notMemberKey = Key('familyChat.notMember');
  static const emptyKey = Key('familyChat.empty');
  static const deleteKey = Key('familyChat.delete');
  static const reportKey = Key('familyChat.report');

  static Key messageKey(String id) => Key('familyChat.message.$id');

  @override
  ConsumerState<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends ConsumerState<FamilyChatScreen> {
  final _input = TextEditingController();
  Timer? _poll;
  bool _sending = false;

  String get familyId => widget.familyId;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(FamilyChatScreen.pollEvery, (_) {
      if (!mounted) return;
      final chat = ref.read(familyChatProvider(familyId).notifier);
      unawaited(chat.refresh().catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      await ref.read(familyChatProvider(familyId).notifier).send(text);
      if (mounted) _input.clear();
    } on Object catch (e) {
      if (!mounted) return;
      if (isErrorCode(e, ErrorCode.familyChatMuted)) {
        ref.read(familyChatProvider(familyId).notifier).markMuted();
      }
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _actions(FamilyChatMessage m, FamilyChatState s) async {
    final l10n = context.l10n;
    final me = ref.read(currentUserProvider)?.id;
    final own = m.author.id == me;
    final canDelete =
        own ||
        (s.canModerate &&
            (m.authorRole == null || m.authorRole == FamilyRole.member)) ||
        (s.canModerate && _iAmLeader());
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                key: FamilyChatScreen.deleteKey,
                leading: Icon(Icons.delete_outline, color: sheet.palette.error),
                title: Text(l10n.familyChatDelete),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
            if (!own)
              ListTile(
                key: FamilyChatScreen.reportKey,
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.familyChatReport),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'delete') {
        await ref.read(familyChatProvider(familyId).notifier).delete(m.id);
        if (mounted) KSnack.success(context, l10n.familyChatDeleted);
      } else {
        final reason = await pickReportReason(context, l10n.familyChatReport);
        if (reason == null || !mounted) return;
        await ref.read(familiesRepositoryProvider).reportChat(m.id, reason);
        if (mounted) KSnack.success(context, l10n.familyChatReported);
      }
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  bool _iAmLeader() =>
      ref.read(familyProvider(familyId)).value?.myRole == FamilyRole.leader;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final family = ref.watch(familyProvider(familyId)).value;
    final load = ref.watch(familyChatProvider(familyId));
    final notifier = ref.read(familyChatProvider(familyId).notifier);
    final me = ref.watch(currentUserProvider)?.id;
    final body = switch (load) {
      AsyncValue(:final error?, isLoading: false)
          when isErrorCode(error, ErrorCode.authForbidden) =>
        Center(
          key: FamilyChatScreen.notMemberKey,
          child: KEmptyState(
            icon: Icons.lock_outline,
            title: l10n.familyChatMembersOnly,
            message: l10n.familyChatMembersOnlyBody,
          ),
        ),
      AsyncValue(:final error?, isLoading: false) when !load.hasValue =>
        FailureErrorState(
          title: l10n.familyChatLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(familyChatProvider(familyId)),
        ),
      AsyncValue(:final value?) => Column(
        children: [
          Expanded(
            child: value.messages.isEmpty
                ? Center(
                    key: FamilyChatScreen.emptyKey,
                    child: KEmptyState(
                      icon: Icons.forum_outlined,
                      title: l10n.familyChatEmpty,
                      message: l10n.familyChatEmptyBody,
                      compact: true,
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 200) {
                        unawaited(
                          notifier.loadMore().catchError((Object _) {}),
                        );
                      }
                      return false;
                    },
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.sm,
                      ),
                      itemCount:
                          value.messages.length + (value.loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= value.messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(KSpacing.md),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final m = value.messages[i];
                        return _Bubble(
                          key: FamilyChatScreen.messageKey(m.id),
                          message: m,
                          own: m.author.id == me,
                          onLongPress: () => unawaited(_actions(m, value)),
                        );
                      },
                    ),
                  ),
          ),
          if (value.muted)
            Container(
              key: FamilyChatScreen.mutedKey,
              width: double.infinity,
              padding: const EdgeInsets.all(KSpacing.md),
              color: p.surfaceRaised,
              child: SafeArea(
                top: false,
                child: Text(
                  l10n.errorFamilyChatMuted,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
              ),
            )
          else
            _Composer(
              controller: _input,
              sending: _sending,
              onSend: () => unawaited(_send()),
            ),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        titleSpacing: 0,
        title: Row(
          children: [
            FamilyEmblem(url: family?.emblemUrl, size: 34),
            const SizedBox(width: KSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    family?.name ?? l10n.familyChatTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  if (family != null)
                    Text(
                      l10n.familyMembersShort(
                        familyCount(context, family.memberCount),
                      ),
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}

class _Bubble extends StatelessWidget {
  const new({
    required this.message,
    required this.own,
    required this.onLongPress,
    super.key,
  });

  final FamilyChatMessage message;
  final bool own;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final author = message.author;
    final name = author.displayName.isEmpty
        ? author.username
        : author.displayName;
    final role = message.authorRole;
    final time = KFormat.time(
      message.createdAt,
      Localizations.localeOf(context).toLanguageTag(),
    );
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: own ? FamilyColors.goldGradient : null,
          color: own ? null : p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!own)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (role != null && role != FamilyRole.member) ...[
                    const SizedBox(width: KSpacing.xs),
                    FamilyRoleChip(role: role),
                  ],
                ],
              ),
            Text(
              message.text,
              textDirection: KFormat.firstStrongDirection(message.text),
              style: t.body.copyWith(
                color: own ? FamilyColors.onGold : p.textPrimary,
              ),
            ),
            Text(
              time,
              style: t.caption.copyWith(
                color: own
                    ? FamilyColors.onGold.withValues(alpha: 0.7)
                    : p.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!own) ...[
            KAvatar(name: name, imageUrl: author.avatarUrl, size: 32),
            const SizedBox(width: KSpacing.xs),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const new({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.md,
          KSpacing.sm,
          KSpacing.md,
          KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: p.background,
          border: Border(top: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: FamilyChatScreen.inputKey,
                controller: controller,
                maxLength: 200,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l10n.familyChatHint,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: p.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            IconButton.filled(
              key: FamilyChatScreen.sendKey,
              tooltip: l10n.familyChatSend,
              style: IconButton.styleFrom(
                backgroundColor: FamilyColors.goldDeep,
                foregroundColor: const Color(0xFFFFFFFF),
              ),
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.send_rounded
                          : Icons.send_rounded,
                      textDirection: Directionality.of(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
