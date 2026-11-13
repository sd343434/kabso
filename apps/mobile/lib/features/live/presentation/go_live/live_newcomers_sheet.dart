import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_newcomers_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The people this phone already welcomed, per live (D154c: «رحّب» is
/// offered once per person per live).
class WelcomedNewcomers extends Notifier<Set<String>> {
  new(this.roomId);

  final String roomId;

  @override
  Set<String> build() => const {};

  void add(String username) => state = {...state, username};
}

final NotifierProviderFamily<WelcomedNewcomers, Set<String>, String>
welcomedNewcomersProvider =
    NotifierProvider.family<WelcomedNewcomers, Set<String>, String>(
      WelcomedNewcomers.new,
    );

/// D154c («الجدد», CONVENTIONS §10.35): for the host and moderators, the
/// people in this live now whose account is younger than the server's
/// window (owner: 30 days) — never their signup date — each with «رحّب»,
/// which sends a ready welcome line mentioning them through the room chat
/// (its own limits, blocked words and mute apply), once per person.
Future<void> showLiveNewcomers(
  BuildContext context, {
  required String roomId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF1F1D24),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
  ),
  builder: (_) => LiveNewcomersSheet(roomId: roomId),
);

class LiveNewcomersSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const sheetKey = Key('newcomers.sheet');
  static const emptyKey = Key('newcomers.empty');
  static Key welcomeKey(String username) => Key('newcomers.welcome.$username');

  @override
  ConsumerState<LiveNewcomersSheet> createState() => _LiveNewcomersSheetState();
}

class _LiveNewcomersSheetState extends ConsumerState<LiveNewcomersSheet> {
  LiveNewcomers? _data;
  Object? _error;
  String? _sending;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(liveNewcomersRepositoryProvider)
          .list(widget.roomId);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _welcome(UserSummary person) async {
    final l10n = context.l10n;
    setState(() => _sending = person.username);
    final failure = await ref
        .read(liveChatProvider(widget.roomId).notifier)
        .send(l10n.liveNewcomerWelcomeText(person.username));
    if (!mounted) return;
    setState(() => _sending = null);
    if (failure == null) {
      ref
          .read(welcomedNewcomersProvider(widget.roomId).notifier)
          .add(person.username);
    } else {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFFFFFFFF);
    const soft = Color(0xFFB9B6C2);
    final welcomed = ref.watch(welcomedNewcomersProvider(widget.roomId));
    final data = _data;
    Widget body;
    if (data == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : KErrorState(
                  title: l10n.liveNewcomersLoadError,
                  message: failureMessage(l10n, toAppFailure(_error!)),
                  retryLabel: l10n.actionRetry,
                  onRetry: () {
                    setState(() => _error = null);
                    unawaited(_load());
                  },
                  compact: true,
                ),
        ),
      );
    } else if (data.people.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
        child: Text(
          l10n.liveNewcomersEmpty,
          key: LiveNewcomersSheet.emptyKey,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: soft),
        ),
      );
    } else {
      body = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in data.people)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: KAvatar(
                  name: p.displayName,
                  imageUrl: p.avatarUrl,
                  size: 36,
                ),
                title: Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.copyWith(color: ink),
                ),
                subtitle: Text(
                  '${KFormat.bidiIsolate('@${p.username}')} · '
                  '${l10n.liveNewcomerBadge}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: soft),
                ),
                trailing: welcomed.contains(p.username)
                    ? Text(
                        l10n.liveNewcomerWelcomed,
                        style: t.caption.copyWith(
                          color: const Color(0xFF3DDC97),
                        ),
                      )
                    : FilledButton(
                        key: LiveNewcomersSheet.welcomeKey(p.username),
                        onPressed: _sending != null
                            ? null
                            : () => unawaited(_welcome(p)),
                        child: Text(l10n.liveNewcomerWelcome),
                      ),
              ),
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Semantics(
        key: LiveNewcomersSheet.sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveToolNewcomers,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            14,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveToolNewcomers,
                  style: t.title.copyWith(color: ink),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.liveNewcomersHint(data?.newcomerDays ?? 30),
                style: t.caption.copyWith(color: soft),
              ),
              const SizedBox(height: KSpacing.sm),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
