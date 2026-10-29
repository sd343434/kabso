import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D165: «رسالة جديدة» — find someone by name or username (the people
/// search, `GET /search?type=users`, CONVENTIONS §11.6) and open the
/// conversation with them. Whether the person accepts messages is decided
/// by the conversation itself (`getDmPeer`), which explains a refusal.
Future<void> showDmNewMessageSheet(BuildContext context) async {
  final picked = await showModalBottomSheet<UserSummary>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const DmNewMessageSheet(),
  );
  if (picked == null || !context.mounted) return;
  unawaited(
    context.push(
      AppRoutes.chat(picked.username),
      extra: (
        displayName: picked.displayName,
        premiumTier: picked.premiumTier,
      ) as ChatPeer,
    ),
  );
}

/// The sheet's content: a search field and the people found.
class DmNewMessageSheet extends ConsumerStatefulWidget {
  const new({super.key});

  static const fieldKey = Key('dm.new.field');
  static const emptyKey = Key('dm.new.empty');
  static const startKey = Key('dm.new.start');
  static Key personKey(String username) => Key('dm.new.person.$username');

  @override
  ConsumerState<DmNewMessageSheet> createState() => _DmNewMessageSheetState();
}

class _DmNewMessageSheetState extends ConsumerState<DmNewMessageSheet> {
  Timer? _debounce;
  String _query = '';
  Future<List<UserSummary>>? _results;

  void _changed(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = q;
        _results = q.isEmpty
            ? null
            : ref.read(postsRepositoryProvider).searchUsers(q);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final me = ref.watch(currentUserProvider.select((u) => u?.id));
    final results = _results;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              l10n.conversationsNewMessage,
              style: context.textStyles.title.copyWith(color: p.textPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: TextField(
              key: DmNewMessageSheet.fieldKey,
              autofocus: true,
              maxLength: 64,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              decoration: InputDecoration(
                hintText: l10n.dmNewMessageHint,
                counterText: '',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: p.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: results == null
                ? _Note(
                    key: DmNewMessageSheet.startKey,
                    text: l10n.dmNewMessageStart,
                  )
                : FutureBuilder<List<UserSummary>>(
                    key: ValueKey(_query),
                    future: results,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _Note(
                          text: failureMessage(l10n, toAppFailure(snap.error!)),
                        );
                      }
                      final people = [
                        for (final u in snap.data ?? const <UserSummary>[])
                          if (u.id != me) u,
                      ];
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (people.isEmpty) {
                        return _Note(
                          key: DmNewMessageSheet.emptyKey,
                          text: l10n.dmNewMessageEmpty,
                        );
                      }
                      return ListView(
                        children: [
                          for (final u in people)
                            ListTile(
                              key: DmNewMessageSheet.personKey(u.username),
                              leading: KAvatar(
                                name: u.displayName,
                                imageUrl: u.avatarUrl,
                                size: KSizes.avatarSm,
                              ),
                              title: Text(
                                u.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                KHandle.text(
                                  l10n,
                                  u.username,
                                  premiumTier: u.premiumTier,
                                ),
                                maxLines: 1,
                                textDirection: TextDirection.ltr,
                              ),
                              onTap: () => Navigator.of(context).pop(u),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(KSpacing.xl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.textStyles.body.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}
