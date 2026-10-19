import 'package:clock/clock.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/debug/preview_state_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 conversation list, measured from the owner's Figma
/// reference (UI kit "Direct messages", node 1347:5329, 417x904). Only
/// geometry and type sizes are taken from it; colours are Kabso's and
/// avatars are initials, never the kit's photos.
abstract final class KConversations {
  static const double rowHeight = 73;

  /// The unread row is taller and tinted (81 vs 73).
  static const double unreadRowHeight = 81;
  static const double avatar = 57;
  static const double startInset = 16;
  static const double avatarGap = 12;
  static const double endInset = 16;
  static const double nameSize = 14.5;
  static const double previewSize = 13.7;
  static const double timeSize = 12.2;
  static const double titleSize = 17.3;
}

/// What the last message of a conversation was (drives the preview line).
enum ConversationLast { text, sharedVideo, none }

/// One row of the conversation list (labelled test data, D46).
class ConversationSummary {
  const new({
    required this.peer,
    required this.at,
    this.last = ConversationLast.none,
    this.text = '',
    this.unread = false,
  });

  final String peer;
  final DateTime at;
  final ConversationLast last;
  final String text;
  final bool unread;
}

List<ConversationSummary> conversationsPreviewFixture({
  required bool ar,
  required DateTime now,
}) => [
  ConversationSummary(
    peer: ar ? 'نور (تجربة)' : 'Nour (test)',
    at: now.subtract(const Duration(minutes: 5)),
    last: ConversationLast.sharedVideo,
    unread: true,
  ),
  ConversationSummary(
    peer: ar ? 'سامي (تجربة)' : 'Sami (test)',
    at: now.subtract(const Duration(hours: 3)),
    last: ConversationLast.text,
    text: ar ? 'رسالة تجريبية' : 'A test message',
  ),
  ConversationSummary(
    peer: ar ? 'هند (تجربة)' : 'Hind (test)',
    at: now.subtract(const Duration(days: 2)),
  ),
  ConversationSummary(
    peer: ar ? 'عمر (تجربة)' : 'Omar (test)',
    at: now.subtract(const Duration(days: 3)),
  ),
  ConversationSummary(
    peer: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    at: now.subtract(const Duration(days: 12)),
  ),
];

/// The states the preview can show. Production has no messaging API yet
/// (contract has no conversations endpoint), so its honest state today is
/// [unavailable]; the others show how the screen will behave once it has
/// one.
enum ConversationsPreviewState { loading, error, unavailable, empty, populated }

/// `/debug/conversations-preview` — KL-056 conversation list with a state
/// switcher. Opening a conversation shows the messages preview; a
/// conversation without messages opens on the first-time greeting.
class ConversationsPreviewScreen extends StatefulWidget {
  const new({
    super.key,
    this.initialState = ConversationsPreviewState.populated,
  });

  final ConversationsPreviewState initialState;

  static const testDataKey = Key('conversations-preview-test-data');
  static const listKey = Key('conversations-preview-list');
  static const stateBarKey = Key('conversations-preview-states');

  @override
  State<ConversationsPreviewScreen> createState() =>
      _ConversationsPreviewScreenState();
}

class _ConversationsPreviewScreenState
    extends State<ConversationsPreviewScreen> {
  late ConversationsPreviewState _state = widget.initialState;

  void _open(ConversationSummary c) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesPreviewScreen(
          peer: c.peer,
          // A conversation with a last message opens on the test thread;
          // one with none opens on the first-time greeting.
          initialMessages: c.last == ConversationLast.none
              ? const []
              : messagesPreviewFixture(ar: ar),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(
          l10n.conversationsTitle,
          style: context.textStyles.bodyStrong.copyWith(
            fontSize: KConversations.titleSize,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        shape: Border(bottom: BorderSide(color: p.border, width: 0.7)),
      ),
      body: Column(
        children: [
          PreviewStateBar<ConversationsPreviewState>(
            key: ConversationsPreviewScreen.stateBarKey,
            testDataKey: ConversationsPreviewScreen.testDataKey,
            values: ConversationsPreviewState.values,
            value: _state,
            label: (s) => _stateLabel(context.l10n, s),
            onChanged: (s) => setState(() => _state = s),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  static String _stateLabel(
    AppLocalizations l10n,
    ConversationsPreviewState s,
  ) => switch (s) {
    ConversationsPreviewState.loading => l10n.previewStateLoading,
    ConversationsPreviewState.error => l10n.previewStateError,
    ConversationsPreviewState.unavailable => l10n.previewStateUnavailable,
    ConversationsPreviewState.empty => l10n.previewStateEmpty,
    ConversationsPreviewState.populated => l10n.previewStatePopulated,
  };

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    switch (_state) {
      case ConversationsPreviewState.loading:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 6; i++) const _SkeletonRow()],
        );
      case ConversationsPreviewState.error:
        return FailureErrorState(
          title: l10n.errorTitle,
          failure: const NetworkFailure.offline(),
          onRetry: () =>
              setState(() => _state = ConversationsPreviewState.loading),
        );
      case ConversationsPreviewState.unavailable:
        return KEmptyState(
          icon: Icons.forum_outlined,
          title: l10n.conversationsUnavailableTitle,
          message: l10n.conversationsUnavailableBody,
        );
      case ConversationsPreviewState.empty:
        return KEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.conversationsEmptyTitle,
          message: l10n.conversationsEmptyBody,
        );
      case ConversationsPreviewState.populated:
        final items = conversationsPreviewFixture(
          ar: Directionality.of(context) == TextDirection.rtl,
          now: clock.now(),
        );
        return ListView.builder(
          key: ConversationsPreviewScreen.listKey,
          itemCount: items.length,
          itemBuilder: (_, i) =>
              _ConversationRow(item: items[i], onTap: () => _open(items[i])),
        );
    }
  }
}

class _ConversationRow extends StatelessWidget {
  const new({required this.item, required this.onTap});

  final ConversationSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final preview = switch (item.last) {
      ConversationLast.text => item.text,
      ConversationLast.sharedVideo => l10n.conversationsSharedVideo,
      ConversationLast.none => l10n.conversationsSayHi(
        KFormat.bidiIsolate(item.peer),
      ),
    };
    final time =
        KFormat.relative(
          item.at,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return Semantics(
      button: true,
      label: item.unread ? l10n.conversationsUnread(item.peer) : item.peer,
      value: '$preview, $time',
      excludeSemantics: true,
      child: Material(
        color: item.unread ? p.surface : p.background,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: item.unread
                  ? KConversations.unreadRowHeight
                  : KConversations.rowHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KConversations.startInset,
                end: KConversations.endInset,
                top: KSpacing.sm,
                bottom: KSpacing.sm,
              ),
              child: Row(
                children: [
                  KAvatar(name: item.peer, size: KConversations.avatar),
                  const SizedBox(width: KConversations.avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.peer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            fontSize: KConversations.nameSize,
                            fontWeight: item.unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xxs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: KConversations.previewSize,
                            color: item.unread
                                ? p.textPrimary
                                : p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  // The time sits at the top of the row, as measured.
                  SizedBox(
                    height: KConversations.avatar,
                    child: Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: Text(
                        time,
                        style: t.caption.copyWith(
                          fontSize: KConversations.timeSize,
                          color: p.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: KConversations.rowHeight,
    child: Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: KConversations.startInset,
      ),
      child: Row(
        children: [
          KSkeleton(
            width: KConversations.avatar,
            height: KConversations.avatar,
            circle: true,
          ),
          SizedBox(width: KConversations.avatarGap),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KSkeleton(width: 120, height: 14),
                SizedBox(height: KSpacing.sm),
                KSkeleton(width: 180, height: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
