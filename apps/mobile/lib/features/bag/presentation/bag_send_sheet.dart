import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/bag_labels.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// How a recipient is named in the bag's sentences (`@sara` or a premium
/// name without `@`, D158).
String bagRecipientHandle(AppLocalizations l10n, UserSummary user) =>
    KHandle.text(l10n, user.username, premiumTier: user.premiumTier);

/// D171 «إرسال»: send [item] to someone — the whole item or, for an item
/// with an end, some whole days of its time (owner amendment «يمكن أن
/// تجزّئ المدة»; a permanent item goes whole only). The person is found
/// with the people search (`GET /search?type=users`); a confirmation names
/// the item, the amount and the person. Returns the transfer, or null.
Future<BagTransfer?> showBagSendSheet(BuildContext context, BagItem item) =>
    showModalBottomSheet<BagTransfer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => BagSendSheet(item: item),
    );

class BagSendSheet extends ConsumerStatefulWidget {
  const new({required this.item, super.key});

  final BagItem item;

  static const fieldKey = Key('bag.send.field');
  static const allKey = Key('bag.send.all');
  static const submitKey = Key('bag.send.submit');
  static const confirmKey = Key('bag.send.confirm');
  static const changeKey = Key('bag.send.change');
  static const errorKey = Key('bag.send.error');
  static const haveKey = Key('bag.send.have');
  static const noteKey = Key('bag.send.note');
  static Key daysKey(int days) => Key('bag.send.days.$days');
  static Key personKey(String username) => Key('bag.send.person.$username');

  @override
  ConsumerState<BagSendSheet> createState() => _BagSendSheetState();
}

class _BagSendSheetState extends ConsumerState<BagSendSheet> {
  Timer? _debounce;
  String _query = '';
  Future<List<UserSummary>>? _results;
  UserSummary? _to;

  /// Whole days to send; null = all.
  int? _days;
  bool _busy = false;
  String? _error;

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

  String _amount(AppLocalizations l10n) =>
      _days == null ? l10n.bagSendAll : l10n.bagDays(_days!);

  Future<void> _submit() async {
    final to = _to;
    if (to == null || _busy) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.bagSendConfirmTitle),
        content: Text(
          l10n.bagSendConfirmBody(
            KFormat.bidiIsolate(widget.item.name),
            _amount(l10n),
            bagRecipientHandle(l10n, to),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: BagSendSheet.confirmKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.bagSend),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref
          .read(bagRepositoryProvider)
          .send(code: widget.item.code, username: to.username, days: _days);
      if (mounted) Navigator.of(context).pop(sent);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final item = widget.item;
    final now = clock.now();
    final left = item.expiresAt?.difference(now);
    final options = left == null ? const <int>[] : bagSendDayOptions(left);
    final note = switch ((left, _days)) {
      (null, _) => l10n.bagSendPermanentNote,
      (_, null) => l10n.bagSendWholeNote,
      (final l?, final d?) => l10n.bagSendPartNote(
        bagDurationText(l10n, l - bagDay * d),
      ),
    };
    Widget chip(
      String text, {
      required bool selected,
      required Key key,
      required VoidCallback onTap,
    }) => ChoiceChip(
      key: key,
      label: Text(text),
      selected: selected,
      onSelected: _busy ? null : (_) => setState(onTap),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              children: [
                Text(
                  l10n.bagSendTitle(KFormat.bidiIsolate(item.name)),
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  left == null
                      ? l10n.bagSendYouHave(l10n.bagPermanent)
                      : l10n.bagSendYouHave(bagDurationText(l10n, left)),
                  key: BagSendSheet.haveKey,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.md),
                Text(
                  l10n.bagSendAmount,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.sm),
                Wrap(
                  spacing: KSpacing.sm,
                  runSpacing: KSpacing.sm,
                  children: [
                    for (final d in options)
                      chip(
                        l10n.bagDays(d),
                        key: BagSendSheet.daysKey(d),
                        selected: _days == d,
                        onTap: () => _days = d,
                      ),
                    chip(
                      l10n.bagSendAll,
                      key: BagSendSheet.allKey,
                      selected: _days == null,
                      onTap: () => _days = null,
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  note,
                  key: BagSendSheet.noteKey,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.lg),
                Text(
                  l10n.bagSendTo,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.sm),
                if (_to case final to?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: KAvatar(
                      name: to.displayName,
                      imageUrl: to.avatarUrl,
                      size: KSizes.avatarSm,
                    ),
                    title: Text(
                      to.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(bagRecipientHandle(l10n, to), maxLines: 1),
                    trailing: TextButton(
                      key: BagSendSheet.changeKey,
                      onPressed: _busy
                          ? null
                          : () => setState(() => _to = null),
                      child: Text(l10n.bagSendChange),
                    ),
                  )
                else ...[
                  TextField(
                    key: BagSendSheet.fieldKey,
                    maxLength: 64,
                    textInputAction: TextInputAction.search,
                    onChanged: _changed,
                    decoration: InputDecoration(
                      hintText: l10n.bagSendSearchHint,
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
                  _people(l10n),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    error,
                    key: BagSendSheet.errorKey,
                    style: t.caption.copyWith(color: p.error),
                  ),
                ],
                const SizedBox(height: KSpacing.md),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: FilledButton(
              key: BagSendSheet.submitKey,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(KSizes.minTouchTarget),
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
              ),
              onPressed: _to == null || _busy
                  ? null
                  : () => unawaited(_submit()),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.bagSend),
            ),
          ),
        ],
      ),
    );
  }

  Widget _people(AppLocalizations l10n) {
    final p = context.palette;
    final results = _results;
    final me = ref.watch(currentUserProvider.select((u) => u?.id));
    Widget note(String text) => Padding(
      padding: const EdgeInsets.all(KSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.textStyles.body.copyWith(color: p.textSecondary),
      ),
    );
    if (results == null) return note(l10n.bagSendSearchStart);
    return FutureBuilder<List<UserSummary>>(
      key: ValueKey(_query),
      future: results,
      builder: (context, snap) {
        if (snap.hasError) {
          return note(failureMessage(l10n, toAppFailure(snap.error!)));
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(KSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final people = [
          for (final u in snap.data ?? const <UserSummary>[])
            if (u.id != me) u,
        ];
        if (people.isEmpty) return note(l10n.bagSendSearchEmpty);
        return Column(
          children: [
            for (final u in people)
              ListTile(
                key: BagSendSheet.personKey(u.username),
                contentPadding: EdgeInsets.zero,
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
                subtitle: Text(bagRecipientHandle(l10n, u), maxLines: 1),
                onTap: () => setState(() => _to = u),
              ),
          ],
        );
      },
    );
  }
}
