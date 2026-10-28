import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_assistant.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The words of [hint] (D154f).
String liveAssistantText(AppLocalizations l10n, LiveAssistantHint hint) {
  final name = KFormat.bidiIsolate(hint.name ?? '');
  return switch (hint.kind) {
    LiveAssistantKind.welcome =>
      hint.count == 0
          ? l10n.liveAssistantWelcomeOne(name)
          : l10n.liveAssistantWelcomeMany(name, hint.count),
    LiveAssistantKind.thank => l10n.liveAssistantThank(
      name,
      KFormat.compact(hint.count, l10n),
    ),
    LiveAssistantKind.silence => l10n.liveAssistantSilence(hint.count),
    LiveAssistantKind.audience =>
      hint.count > hint.other
          ? l10n.liveAssistantRising(hint.other, hint.count)
          : l10n.liveAssistantFalling(hint.other, hint.count),
    LiveAssistantKind.rest => l10n.liveAssistantRest(hint.count),
    LiveAssistantKind.question => l10n.liveAssistantQuestion,
  };
}

/// The name of a [kind] in the settings.
String liveAssistantKindName(AppLocalizations l10n, LiveAssistantKind kind) =>
    switch (kind) {
      LiveAssistantKind.welcome => l10n.liveAssistantKindWelcome,
      LiveAssistantKind.thank => l10n.liveAssistantKindThank,
      LiveAssistantKind.silence => l10n.liveAssistantKindSilence,
      LiveAssistantKind.audience => l10n.liveAssistantKindAudience,
      LiveAssistantKind.rest => l10n.liveAssistantKindRest,
      LiveAssistantKind.question => l10n.liveAssistantKindQuestion,
    };

/// D154f: the assistant's hint in the host's live, just above the chat at
/// the reading start; only the host sees it. A tap hides it. Feeds the
/// assistant the viewers the host screen polls (while it is on).
class LiveAssistantHintLayer extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const hintKey = Key('assistant.hint');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(liveAssistantSettingsProvider).enabled) {
      final viewers = ref.watch(liveViewersPreviewProvider(roomId)).value;
      if (viewers != null) {
        ref.read(liveAssistantProvider(roomId).notifier).viewers =
            viewers.items.length;
      }
    }
    final hint = ref.watch(liveAssistantProvider(roomId));
    final floor = ref.watch(liveChatTopProvider(roomId));
    final height = MediaQuery.sizeOf(context).height;
    final l10n = context.l10n;
    final still = MediaQuery.disableAnimationsOf(context);
    return PositionedDirectional(
      start: KSpacing.sm,
      end: KSpacing.xl * 2,
      bottom: floor == null ? 220 : height - floor + KSpacing.sm,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 220),
          child: hint == null
              ? const SizedBox.shrink()
              : Semantics(
                  key: ValueKey(hint),
                  liveRegion: true,
                  button: true,
                  onTapHint: l10n.liveAssistantDismiss,
                  child: GestureDetector(
                    key: hintKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref
                        .read(liveAssistantProvider(roomId).notifier)
                        .dismiss(),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 300,
                        minHeight: 40,
                      ),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        8,
                        12,
                        8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9262433),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x667FD6FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            size: 18,
                            color: Color(0xFF7FD6FF),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              liveAssistantText(l10n, hint),
                              style: context.textStyles.caption.copyWith(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// D154f: the assistant's settings (Room Tools «مساعد البث»): on/off and
/// each kind of hint; kept on this phone.
Future<void> showLiveAssistantSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LiveAssistantSettingsSheet(),
    );

class LiveAssistantSettingsSheet extends ConsumerWidget {
  const new({super.key});

  static const enabledKey = Key('assistant.enabled');
  static Key kindKey(LiveAssistantKind kind) => Key('assistant.${kind.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final settings = ref.watch(liveAssistantSettingsProvider);
    final notifier = ref.read(liveAssistantSettingsProvider.notifier);
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.liveToolAssistance, style: t.title.copyWith(color: ink)),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.liveAssistantAbout,
              style: t.caption.copyWith(color: soft),
            ),
            const SizedBox(height: KSpacing.sm),
            SwitchListTile(
              key: enabledKey,
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.liveAssistantOn,
                style: t.bodyStrong.copyWith(color: ink),
              ),
              value: settings.enabled,
              onChanged: (v) => notifier.setEnabled(enabled: v),
            ),
            const Divider(height: 1),
            for (final kind in LiveAssistantKind.values)
              SwitchListTile(
                key: kindKey(kind),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  liveAssistantKindName(l10n, kind),
                  style: t.body.copyWith(color: ink),
                ),
                value: !settings.off.contains(kind),
                onChanged: settings.enabled
                    ? (v) => notifier.setKind(kind, on: v)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
