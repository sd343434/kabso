import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/create/create_mode_bar.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/application/media_library_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Step 1 of Create (owner's reference, KL-060): the device photo library
/// as a grid. A tap selects or unselects a photo (at most 10, in tap
/// order = post order); the tray under the grid lists the selection.
/// Without a library (web) or without access, the system picker is
/// offered instead, and limited access says so with a way to change it.
/// Video has no upload API before M2: its filter says "soon".
class CreateMediaStep extends ConsumerStatefulWidget {
  const new({
    required this.onNext,
    required this.onClose,
    required this.onPickFromDevice,
    super.key,
  });

  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onPickFromDevice;

  static const nextKey = Key('create.next');
  static const gridKey = Key('create.media.grid');
  static const trayKey = Key('create.media.tray');
  static const pickDeviceKey = Key('create.media.device');
  static const allowKey = Key('create.media.allow');
  static const manageKey = Key('create.media.manage');
  static const tabAllKey = Key('create.media.tab.all');
  static const tabPhotosKey = Key('create.media.tab.photos');
  static const tabVideoKey = Key('create.media.tab.video');
  static Key itemKey(String id) => Key('create.media.item.$id');
  static Key trayRemoveKey(int localId) =>
      Key('create.media.tray.$localId.remove');
  static Key trayPhotoKey(int localId) => Key('create.media.tray.$localId');

  @override
  ConsumerState<CreateMediaStep> createState() => _CreateMediaStepState();
}

enum _Filter { photos, all }

class _CreateMediaStepState extends ConsumerState<CreateMediaStep> {
  _Filter _filter = _Filter.all;
  final Set<String> _loading = {};

  Future<void> _toggle(String id) async {
    final l10n = context.l10n;
    final compose = ref.read(composeControllerProvider.notifier);
    final draft = ref.read(composeControllerProvider);
    if (draft.busy || _loading.contains(id)) return;
    if (librarySelectionIndex(draft.photos, id) >= 0) {
      compose.removeLibraryPhoto(id);
      return;
    }
    if (draft.photos.length >= maxPostPhotos) {
      KSnack.info(context, l10n.createPhotoTooMany(maxPostPhotos));
      return;
    }
    setState(() => _loading.add(id));
    try {
      final bytes = await ref.read(mediaLibraryProvider).photoBytes(id);
      if (!mounted) return;
      if (bytes == null) {
        KSnack.error(context, l10n.createPhotoUnsupported);
        return;
      }
      final rejection = compose.addLibraryPhoto(id, bytes);
      switch (rejection) {
        case PhotoRejection.unsupportedType:
          KSnack.error(context, l10n.createPhotoUnsupported);
        case PhotoRejection.tooLarge:
          KSnack.error(context, l10n.createPhotoTooLarge);
        case PhotoRejection.tooMany:
          KSnack.info(context, l10n.createPhotoTooMany(maxPostPhotos));
        case null:
          break;
      }
    } on Object {
      if (mounted) KSnack.error(context, l10n.createLibraryFailed);
    } finally {
      if (mounted) setState(() => _loading.remove(id));
    }
  }

  Future<void> _manage(LibraryAccess access) async {
    await ref.read(mediaLibraryProvider).manageAccess(access);
    if (mounted) ref.invalidate(mediaLibraryControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final draft = ref.watch(composeControllerProvider);
    final library = ref.watch(mediaLibraryControllerProvider);
    return Column(
      children: [
        ComposeHeader(
          action: ComposeActionPill(
            key: CreateMediaStep.nextKey,
            label: l10n.createNext,
            glyph: const Icon(Icons.arrow_forward_rounded),
            enabled: !draft.busy,
            onTap: widget.onNext,
          ),
          subtitle: l10n.createMediaSubtitle,
          endButton: ComposeRoundButton(
            key: const Key('create.close'),
            tooltip: l10n.createClose,
            onPressed: draft.busy ? null : widget.onClose,
            icon: const AppIcon(AppIcons.close),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KCompose.mediaInset,
            KSpacing.sm,
            KCompose.mediaInset,
            KSpacing.md,
          ),
          child: _Segments(
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
        ),
        Expanded(
          child: switch (library) {
            AsyncData(:final value) when value.access.canBrowse => _Grid(
              state: value,
              draft: draft,
              loading: _loading,
              onToggle: _toggle,
              onManage: () => _manage(value.access),
            ),
            AsyncData(:final value) => _NoLibrary(
              message: value.access == LibraryAccess.denied
                  ? l10n.createLibraryDenied
                  : l10n.createLibraryUnsupported,
              onAllow: value.access == LibraryAccess.denied
                  ? () => _manage(value.access)
                  : null,
              onPick: draft.busy ? null : widget.onPickFromDevice,
            ),
            AsyncError() => _NoLibrary(
              message: l10n.createLibraryFailed,
              onPick: draft.busy ? null : widget.onPickFromDevice,
              onRetry: () => ref.invalidate(mediaLibraryControllerProvider),
            ),
            _ => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(p.primary),
              ),
            ),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KCompose.mediaInset,
            KSpacing.sm,
            KCompose.mediaInset,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (draft.photos.isNotEmpty) ...[
                _Tray(draft: draft),
                const SizedBox(height: KSpacing.sm),
              ],
              const _UpToNote(),
              const SizedBox(height: KSpacing.xs),
              CreateModeBar(
                selected: CreateMode.post,
                onSelect: (mode) => switch (mode) {
                  CreateMode.post => null,
                  CreateMode.story => context.push(AppRoutes.newStory),
                  CreateMode.live => context.push(AppRoutes.goLive),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// All · Video · Photos. The library holds photos only for now, so "All"
/// and "Photos" show the same grid; Video says "soon".
class _Segments extends StatelessWidget {
  const new({required this.filter, required this.onFilter});

  final _Filter filter;
  final ValueChanged<_Filter> onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    Widget segment({
      required Key key,
      required String label,
      required Widget icon,
      required bool selected,
      VoidCallback? onTap,
      String? hint,
    }) {
      final fg = selected
          ? p.primary
          : (onTap == null ? p.textTertiary : p.textPrimary);
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          enabled: onTap != null,
          hint: hint,
          child: Material(
            key: key,
            color: selected ? p.primary.withValues(alpha: 0.07) : null,
            type: selected ? MaterialType.canvas : MaterialType.transparency,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KRadius.md),
              side: selected
                  ? BorderSide(color: p.primary.withValues(alpha: 0.25))
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(KRadius.md),
              onTap: onTap,
              child: SizedBox(
                height: KCompose.segmentHeight - 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: context.textStyles.label.copyWith(
                          color: fg,
                          fontWeight: selected ? FontWeight.w700 : null,
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      IconTheme.merge(
                        data: IconThemeData(color: fg, size: 22),
                        child: icon,
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

    return Container(
      height: KCompose.segmentHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceOverlay.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KCompose.panelRadius),
      ),
      child: Row(
        children: [
          segment(
            key: CreateMediaStep.tabPhotosKey,
            label: l10n.createTypePhotos,
            icon: const Icon(Icons.image_outlined),
            selected: filter == _Filter.photos,
            onTap: () => onFilter(_Filter.photos),
          ),
          segment(
            key: CreateMediaStep.tabVideoKey,
            label: l10n.createTabVideo,
            icon: const Icon(Icons.smart_display_outlined),
            selected: false,
            hint: l10n.createSoon,
          ),
          segment(
            key: CreateMediaStep.tabAllKey,
            label: l10n.createTabAll,
            icon: const Icon(Icons.photo_library_outlined),
            selected: filter == _Filter.all,
            onTap: () => onFilter(_Filter.all),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const new({
    required this.state,
    required this.draft,
    required this.loading,
    required this.onToggle,
    required this.onManage,
  });

  final LibraryState state;
  final ComposeState draft;
  final Set<String> loading;
  final ValueChanged<String> onToggle;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final items = state.items;
    final limited = state.access == LibraryAccess.limited;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) {
          unawaited(
            ref.read(mediaLibraryControllerProvider.notifier).loadMore(),
          );
        }
        return false;
      },
      child: CustomScrollView(
        key: CreateMediaStep.gridKey,
        slivers: [
          if (limited)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KCompose.mediaInset,
                0,
                KCompose.mediaInset,
                KSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.createLibraryLimited,
                        style: context.textStyles.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      key: CreateMediaStep.manageKey,
                      onPressed: onManage,
                      child: Text(l10n.createLibraryManage),
                    ),
                  ],
                ),
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  l10n.createLibraryEmpty,
                  style: context.textStyles.body.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: KCompose.mediaInset,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: KCompose.gridGap,
                crossAxisSpacing: KCompose.gridGap,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final id = items[i].id;
                return _Tile(
                  key: CreateMediaStep.itemKey(id),
                  id: id,
                  selected: librarySelectionIndex(draft.photos, id) >= 0,
                  loading: loading.contains(id),
                  onTap: draft.busy ? null : () => onToggle(id),
                );
              },
            ),
          ),
          if (state.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: KSpacing.sm)),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const new({
    required this.id,
    required this.selected,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final String id;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final thumb = ref.watch(libraryThumbnailProvider(id)).value;
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.createLibraryPhoto,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KCompose.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb != null)
                Image.memory(thumb, fit: BoxFit.cover, gaplessPlayback: true)
              else
                ColoredBox(color: p.surfaceOverlay),
              if (selected)
                ColoredBox(color: p.primary.withValues(alpha: 0.12)),
              PositionedDirectional(
                top: KSpacing.sm,
                start: KSpacing.sm,
                child: _Check(selected: selected),
              ),
              PositionedDirectional(
                bottom: KSpacing.sm,
                start: KSpacing.sm,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KStatusColors.onStatus.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(KRadius.sm),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
              if (loading)
                ColoredBox(
                  color: const Color(0x55000000),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const new({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.primary : const Color(0x33000000),
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// The selection: count, then the photos in post order (× removes, a tap
/// opens them full screen).
class _Tray extends ConsumerWidget {
  const new({required this.draft});

  final ComposeState draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      key: CreateMediaStep.trayKey,
      height: 72,
      padding: const EdgeInsetsDirectional.only(start: KSpacing.lg),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KCompose.panelRadius),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.createPhotoNumber(draft.photos.length),
                style: t.title.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.createSelected,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            color: p.primary.withValues(alpha: 0.15),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
              itemCount: draft.photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
              itemBuilder: (context, i) {
                final photo = draft.photos[i];
                return Center(
                  child: SizedBox.square(
                    dimension: KCompose.trayThumb + 8,
                    child: Stack(
                      children: [
                        PositionedDirectional(
                          top: 8,
                          start: 0,
                          // A tap opens the selection full screen (swipe
                          // between the photos, remove one).
                          child: Semantics(
                            button: true,
                            label: l10n.createPhotoLabel(
                              i + 1,
                              draft.photos.length,
                            ),
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: CreateMediaStep.trayPhotoKey(photo.localId),
                              onTap: () => unawaited(
                                showComposePhotoPreview(context, i),
                              ),
                              // Sized here, so a photo that cannot be
                              // decoded still fills its square.
                              child: SizedBox.square(
                                dimension: KCompose.trayThumb,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    KRadius.sm,
                                  ),
                                  child: Image(
                                    image: composeThumb(
                                      context,
                                      photo.bytes,
                                      KCompose.trayThumb,
                                    ),
                                    width: KCompose.trayThumb,
                                    height: KCompose.trayThumb,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    excludeFromSemantics: true,
                                    errorBuilder: (_, _, _) =>
                                        ColoredBox(color: p.surfaceOverlay),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: Semantics(
                            button: true,
                            label: l10n.createRemovePhoto,
                            excludeSemantics: true,
                            child: InkResponse(
                              key: CreateMediaStep.trayRemoveKey(photo.localId),
                              radius: 18,
                              onTap: draft.busy
                                  ? null
                                  : () => ref
                                        .read(
                                          composeControllerProvider.notifier,
                                        )
                                        .removePhoto(photo.localId),
                              child: Container(
                                width: KCompose.numberBadge,
                                height: KCompose.numberBadge,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: KStatusColors.onStatus.withValues(
                                    alpha: 0.75,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(
                                  AppIcons.close,
                                  size: 10,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpToNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(KCompose.panelRadius),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline_rounded,
              size: 22,
              color: p.textTertiary,
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 8,
            child: Text(
              context.l10n.createSelectUpTo(maxPostPhotos),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.textStyles.caption.copyWith(
                color: p.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          const ComposeIconDisc(size: 30, child: Icon(Icons.auto_awesome)),
        ],
      ),
    );
  }
}

/// No library to browse: why, and the system picker instead.
class _NoLibrary extends StatelessWidget {
  const new({
    required this.message,
    required this.onPick,
    this.onAllow,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onPick;
  final VoidCallback? onAllow;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KCompose.mediaInset),
      child: Column(
        children: [
          const SizedBox(height: KSpacing.xl),
          const ComposeIconDisc(
            size: 64,
            child: Icon(Icons.photo_library_outlined),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textStyles.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: CreateMediaStep.pickDeviceKey,
            label: l10n.createPickFromDevice,
            onPressed: onPick,
          ),
          if (onAllow != null) ...[
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: CreateMediaStep.allowKey,
              label: l10n.createLibraryAllow,
              variant: KButtonVariant.secondary,
              onPressed: onAllow,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: KSpacing.sm),
            KButton(
              label: l10n.actionRetry,
              variant: KButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
