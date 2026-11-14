import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_lists_repository.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The person a store gift goes to.
@immutable
final class StoreGiftRecipient {
  const new({
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
}

/// D270 «إهداء»: pick who receives a store gift — by username (the people
/// search) or from the people the caller follows. Returns null when closed.
/// The server refuses a blocked or inactive account (404) and oneself.
Future<StoreGiftRecipient?> showStoreGiftPicker(BuildContext context) =>
    showModalBottomSheet<StoreGiftRecipient>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const StoreGiftPicker(),
    );

/// The caller's following list (the picker's first page).
final FutureProvider<List<StoreGiftRecipient>> storeGiftFollowingProvider =
    FutureProvider.autoDispose((ref) async {
      final me = ref.watch(currentUserProvider);
      if (me == null) return const [];
      final page = await ref
          .watch(followListsRepositoryProvider)
          .list(me.username, FollowListKind.following);
      return [
        for (final f in page.items)
          if (!f.isSelf)
            StoreGiftRecipient(
              username: f.username,
              displayName: f.displayName,
              avatarUrl: f.avatarUrl,
            ),
      ];
    });

class StoreGiftPicker extends ConsumerStatefulWidget {
  const new({super.key});

  static const fieldKey = Key('store.gift.field');
  static Key personKey(String username) => Key('store.gift.person.$username');

  @override
  ConsumerState<StoreGiftPicker> createState() => _StoreGiftPickerState();
}

class _StoreGiftPickerState extends ConsumerState<StoreGiftPicker> {
  Timer? _debounce;
  Future<List<StoreGiftRecipient>>? _results;

  void _changed(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final me = ref.read(currentUserProvider)?.id;
      setState(() {
        _results = q.isEmpty
            ? null
            : ref
                  .read(postsRepositoryProvider)
                  .searchUsers(q)
                  .then(
                    (users) => [
                      for (final u in users)
                        if (u.id != me)
                          StoreGiftRecipient(
                            username: u.username,
                            displayName: u.displayName,
                            avatarUrl: u.avatarUrl,
                          ),
                    ],
                  );
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
    final t = context.textStyles;
    final results = _results;
    final list = results == null
        ? switch (ref.watch(storeGiftFollowingProvider)) {
            AsyncData(:final value) => _people(value, l10n.storeGiftFollowing),
            AsyncError() => _people(const [], l10n.storeGiftFollowing),
            _ => const Center(child: CircularProgressIndicator()),
          }
        : FutureBuilder<List<StoreGiftRecipient>>(
            future: results,
            builder: (context, snap) => snap.hasData
                ? _people(snap.data!, null)
                : snap.hasError
                ? _people(const [], null)
                : const Center(child: CircularProgressIndicator()),
          );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.storeGiftTitle,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.md),
            TextField(
              key: StoreGiftPicker.fieldKey,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.storeGiftSearch,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              onChanged: _changed,
            ),
            const SizedBox(height: KSpacing.sm),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }

  Widget _people(List<StoreGiftRecipient> people, String? header) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return ListView(
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            child: Text(
              header,
              style: t.label.copyWith(color: p.textSecondary),
            ),
          ),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Text(
              l10n.storeGiftNone,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
          ),
        for (final person in people)
          ListTile(
            key: StoreGiftPicker.personKey(person.username),
            contentPadding: EdgeInsets.zero,
            leading: KAvatar(
              name: person.displayName,
              imageUrl: person.avatarUrl,
              size: 40,
            ),
            title: Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(KHandle.text(l10n, person.username)),
            onTap: () => Navigator.of(context).pop(person),
          ),
      ],
    );
  }
}
