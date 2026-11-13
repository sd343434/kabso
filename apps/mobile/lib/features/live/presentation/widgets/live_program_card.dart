import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154e («قائمة البرامج», CONVENTIONS §10.37): the live's program as a
/// small card under the room's header — the segment on now (or the next
/// one before the first starts), «بدأت الفقرة: …» for a few seconds when a
/// segment begins; a tap opens the whole list. Nothing while the program is
/// empty.
class LiveProgramCard extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const cardKey = Key('program.card');

  /// The card's widest.
  static const double maxWidth = 200;

  /// Under the header rows (the same line as the lucky ticker, which is
  /// centred and passing; this sits at the reading end).
  static const double top = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveProgramProvider(roomId));
    final program = view.program;
    if (program == null || program.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final started = view.started;
    final now = program.currentItem;
    final next = now == null ? program.nextItem : null;
    final (String head, String title) = switch ((started, now, next)) {
      (final s?, _, _) => (l10n.liveProgramStarted, s.title),
      (_, final n?, _) => (l10n.liveProgramNow, n.title),
      (_, _, final n?) => (
        l10n.liveProgramNext(KFormat.time(n.startsAt, locale)),
        n.title,
      ),
      _ => (l10n.liveProgramTitle, ''),
    };
    final t = context.textStyles;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        button: true,
        liveRegion: started != null,
        label: '$head ${KFormat.bidiIsolate(title)}',
        onTapHint: l10n.liveProgramOpenHint,
        excludeSemantics: true,
        child: GestureDetector(
          key: cardKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(showLiveProgramList(context, roomId: roomId)),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: const Color(0xB31B1A22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: started != null
                    ? const Color(0xCCFFD36E)
                    : const Color(0x33FFFFFF),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.view_list_rounded,
                  size: 16,
                  color: Color(0xFFFFD36E),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: const Color(0xFFFFD36E),
                          fontSize: 10,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The whole program of a live, the segment on now highlighted (anyone in
/// the room; it follows the program's changes while open).
Future<void> showLiveProgramList(
  BuildContext context, {
  required String roomId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF1F1D24),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
  ),
  builder: (_) => LiveProgramList(roomId: roomId),
);

class LiveProgramList extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const listKey = Key('program.list');
  static Key itemKey(int position) => Key('program.item.$position');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final program = ref.watch(liveProgramProvider(roomId)).program;
    final items = program?.items ?? const <LiveProgramItem>[];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.md,
        ),
        child: Column(
          key: listKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.liveProgramTitle,
              style: t.title.copyWith(color: const Color(0xFFFFFFFF)),
            ),
            const SizedBox(height: KSpacing.md),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
                child: Text(
                  l10n.liveProgramEmpty,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: const Color(0xFFB9B6C2)),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in items)
                      _Row(
                        key: itemKey(item.position),
                        time: KFormat.time(item.startsAt, locale),
                        title: item.title,
                        current: item.position == program!.current,
                        nowLabel: l10n.liveProgramNow,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({
    required this.time,
    required this.title,
    required this.current,
    required this.nowLabel,
    super.key,
  });

  final String time;
  final String title;
  final bool current;
  final String nowLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    const gold = Color(0xFFFFD36E);
    return Semantics(
      selected: current,
      child: Container(
        margin: const EdgeInsets.only(bottom: KSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: current ? const Color(0x26FFD36E) : const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: current ? Border.all(color: gold) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                KFormat.bidiIsolate(time),
                style: t.caption.copyWith(
                  color: current ? gold : const Color(0xFFB9B6C2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: t.body.copyWith(color: const Color(0xFFFFFFFF)),
              ),
            ),
            if (current)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: KSpacing.sm),
                child: Text(
                  nowLabel,
                  style: t.caption.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
