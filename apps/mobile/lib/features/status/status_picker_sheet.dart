import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/profile/application/profile_edit_controller.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/status/status_repository.dart';
import 'package:kabso_live/features/status/status_store_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// `PUT /me/status`, then the session and the own profile show it at once.
final saveStatusEmojiProvider = Provider<Future<User> Function(String?)>(
  (ref) => (id) async {
    final user = await ref.read(statusRepositoryProvider).setStatus(id);
    showUpdatedProfile(ref, user);
    return user;
  },
);

/// The picker's answer: [emoji] null is «بدون حالة».
@immutable
final class StatusPick {
  const new(this.emoji);

  final StatusEmoji? emoji;
}

/// Edit profile › «الحالة» (D376): opens the picker and saves the choice.
Future<void> editStatusEmoji(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final pick = await showModalBottomSheet<StatusPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => StatusPickerSheet(
      initialId: user.statusEmojiId,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    ),
  );
  if (pick == null || !context.mounted) return;
  final id = pick.emoji?.id;
  if (id == user.statusEmojiId) return;
  final l10n = context.l10n;
  try {
    await ref.read(saveStatusEmojiProvider)(id);
    if (context.mounted) {
      KSnack.success(
        context,
        id == null ? l10n.statusCleared : l10n.statusSaved,
      );
    }
  } on Object catch (e) {
    if (!context.mounted) return;
    final failure = toAppFailure(e);
    final notOwned =
        failure is ServerFailure &&
        failure.details.any((d) => d.issue == 'pack_not_owned');
    KSnack.error(
      context,
      notOwned ? l10n.statusNotOwned : failureMessage(l10n, failure),
    );
  }
}

/// «الحالة» (D376; the owner's pack, rewritten): a live preview of the
/// person's picture with the chosen status rising over it, one tab per pack
/// (Kabso's own, «عام», then «المميزة»), «بدون حالة», and Save. A store
/// pack the person does not hold is locked: its emoji can be previewed but
/// not saved — the button opens «متجر الحالة» instead.
class StatusPickerSheet extends ConsumerStatefulWidget {
  const new({
    required this.displayName,
    super.key,
    this.initialId,
    this.avatarUrl,
    this.avatar,
  });

  final String? initialId;
  final String displayName;
  final String? avatarUrl;

  /// Tests and goldens: a memory image instead of [avatarUrl].
  final ImageProvider? avatar;

  static const noneKey = Key('status.picker.none');
  static const saveKey = Key('status.picker.save');
  static const storeKey = Key('status.picker.store');
  static const previewKey = Key('status.picker.preview');
  static const lockedHintKey = Key('status.picker.lockedHint');
  static Key tabKey(String pack) => Key('status.picker.tab.$pack');
  static Key itemKey(String id) => Key('status.picker.item.$id');
  static Key lockKey(String pack) => Key('status.picker.lock.$pack');

  /// The preview's picture radius (bubbles get 5 radii of height).
  static const double previewRadius = 38;

  /// A cell's emoji.
  static const double cellEmoji = 44;

  @override
  ConsumerState<StatusPickerSheet> createState() => _StatusPickerSheetState();
}

class _StatusPickerSheetState extends ConsumerState<StatusPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StatusEmoji? _selected;

  @override
  void initState() {
    super.initState();
    _selected = StatusCatalogue.byId(widget.initialId);
    final packs = StatusCatalogue.packs;
    final selected = _selected;
    final start = selected == null
        ? 0
        : packs.indexWhere((p) => p.id == selected.packId);
    _tabs = TabController(
      length: packs.length,
      vsync: this,
      initialIndex: start < 0 ? 0 : start,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Whether [pack] can be worn now (a free pack always; a store pack while
  /// the server says it is held; unknown yet: locked).
  bool _open(StatusPack pack, StatusPackList? held) =>
      pack.kind == StatusPackKind.free ||
      (held?.pack(pack.id)?.heldAt(DateTime.now()) ?? false);

  Future<void> _openStore(StatusPack pack) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatusStoreScreen(
          packId: pack.id,
          displayName: widget.displayName,
          avatarUrl: widget.avatarUrl,
          avatar: widget.avatar,
          initialPreviewId: _selected?.packId == pack.id ? _selected?.id : null,
        ),
      ),
    );
    if (mounted) ref.invalidate(statusPacksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final held = ref.watch(statusPacksProvider).value;
    final selected = _selected;
    final selectedPack = selected == null
        ? null
        : StatusCatalogue.packOf(selected);
    final locked = selectedPack != null && !_open(selectedPack, held);
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.statusTitle, style: t.title),
                ),
              ),
              TextButton.icon(
                key: StatusPickerSheet.noneKey,
                onPressed: selected == null
                    ? null
                    : () => setState(() => _selected = null),
                icon: const Icon(Icons.block_rounded, size: 18),
                label: Text(l10n.statusNone),
              ),
            ],
          ),
          Text(
            l10n.statusPickerHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          // The live preview, with room above the picture for the bubbles.
          SizedBox(
            key: StatusPickerSheet.previewKey,
            height: StatusPickerSheet.previewRadius * 4.6,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox.square(
                dimension: StatusPickerSheet.previewRadius * 2,
                child: StatusAvatar(
                  radius: StatusPickerSheet.previewRadius,
                  statusEmojiId: selected?.id,
                  child: KAvatar(
                    name: widget.displayName,
                    imageUrl: widget.avatarUrl,
                    image: widget.avatar,
                    size: StatusPickerSheet.previewRadius * 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          SizedBox(
            height: 20,
            child: locked
                ? Row(
                    key: StatusPickerSheet.lockedHintKey,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: p.warning),
                      const SizedBox(width: KSpacing.xs),
                      Flexible(
                        child: Text(
                          l10n.statusLockedHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: p.warning),
                        ),
                      ),
                    ],
                  )
                : Text(
                    selected?.label(l10n) ?? l10n.statusNone,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: p.textPrimary,
            unselectedLabelColor: p.textSecondary,
            labelStyle: t.caption.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: t.caption,
            tabs: [
              for (final pack in StatusCatalogue.packs)
                Tab(
                  key: StatusPickerSheet.tabKey(pack.id),
                  height: 58,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Still(pack.icon, size: 30),
                      if (!_open(pack, held))
                        PositionedDirectional(
                          key: StatusPickerSheet.lockKey(pack.id),
                          end: -6,
                          bottom: -2,
                          child: _LockDot(color: p.warning),
                        ),
                    ],
                  ),
                  text: pack.label(l10n),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          SizedBox(
            height: (height * 0.34).clamp(180, 320),
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final pack in StatusCatalogue.packs)
                  _grid(pack, open: _open(pack, held)),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.md),
          if (locked)
            KButton(
              key: StatusPickerSheet.storeKey,
              label: l10n.statusOpenStore,
              icon: Icons.storefront_rounded,
              onPressed: () => unawaited(_openStore(selectedPack)),
            )
          else
            KButton(
              key: StatusPickerSheet.saveKey,
              label: l10n.statusSave,
              onPressed: () => Navigator.of(context).pop(StatusPick(_selected)),
            ),
        ],
      ),
    );
  }

  Widget _grid(StatusPack pack, {required bool open}) {
    final l10n = context.l10n;
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 76,
        mainAxisSpacing: KSpacing.sm,
        crossAxisSpacing: KSpacing.sm,
        childAspectRatio: 0.82,
      ),
      itemCount: pack.emojis.length,
      itemBuilder: (context, i) {
        final e = pack.emojis[i];
        return StatusEmojiCell(
          key: StatusPickerSheet.itemKey(e.id),
          emoji: e,
          selected: _selected == e,
          locked: !open,
          label: e.label(l10n),
          onTap: () => setState(() => _selected = e),
        );
      },
    );
  }
}

/// A status emoji's first frame (cells, tabs): the Lottie still.
class _Still extends StatelessWidget {
  const new(this.emoji, {required this.size, this.animate = false});

  final StatusEmoji emoji;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Lottie.asset(
      emoji.asset,
      width: size,
      height: size,
      animate: animate && !MediaQuery.disableAnimationsOf(context),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    ),
  );
}

class _LockDot extends StatelessWidget {
  const new({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.palette.surfaceRaised,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Icon(Icons.lock_rounded, size: 12, color: color),
    ),
  );
}

/// One emoji of a grid (the picker and the store): its still (it plays
/// while selected), its name, a lock when its pack is not held.
class StatusEmojiCell extends StatelessWidget {
  const new({
    required this.emoji,
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
    this.locked = false,
  });

  final StatusEmoji emoji;
  final bool selected;
  final bool locked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label · ${l10n.statusLockedLabel}' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? p.primary.withValues(alpha: 0.14) : p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.md),
              border: Border.all(
                color: selected ? p.primary : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: KSpacing.xs + 2,
                    horizontal: KSpacing.xxs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Still(
                        emoji,
                        size: StatusPickerSheet.cellEmoji,
                        animate: selected,
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          fontSize: 11,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  PositionedDirectional(
                    top: KSpacing.xs,
                    end: KSpacing.xs,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: p.textTertiary,
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
