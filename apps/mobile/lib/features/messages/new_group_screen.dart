import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/messages/application/dm_group_providers.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `GET /dm/group-candidates` for the picker: one search (null: all),
/// optionally without the members of the group `groupId`.
typedef DmCandidateQuery = ({String? query, String? groupId});

/// The people the caller may add (mutual follows who accept messages),
/// the first page of one search.
final FutureProviderFamily<DmCandidatePage, DmCandidateQuery>
dmGroupCandidatesProvider = FutureProvider.autoDispose
    .family<DmCandidatePage, DmCandidateQuery>(
      (ref, q) => ref
          .watch(dmGroupsRepositoryProvider)
          .candidates(query: q.query, groupId: q.groupId),
    );

/// `/message-groups/new` (D339, CONVENTIONS §10.133) «مجموعة جديدة»: an
/// optional photo (`DM_GROUP_PHOTO`), the name (1–50), and the people from
/// `listDmGroupCandidates` (mutual follows who accept messages) with search;
/// «إنشاء» creates the group with one `clientId` per attempt (a retry is
/// never a second group) and opens it. With [addTo] (admins,
/// `/message-groups/{id}/add`) only the people step, adding to that group.
class NewGroupScreen extends ConsumerStatefulWidget {
  const new({super.key, this.addTo});

  /// The group to add people to (null: a new group).
  final String? addTo;

  static const nameKey = Key('dm.group.new.name');
  static const photoKey = Key('dm.group.new.photo');
  static const searchKey = Key('dm.group.new.search');
  static const submitKey = Key('dm.group.new.submit');
  static const countKey = Key('dm.group.new.count');
  static const emptyKey = Key('dm.group.new.empty');
  static Key personKey(String username) => Key('dm.group.new.$username');

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupState();
}

class _NewGroupState extends ConsumerState<NewGroupScreen> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  late String _clientId = newClientId();
  Timer? _debounce;
  String? _query;
  Uint8List? _photo;
  late String _photoType;
  String? _photoId;
  String? _nameError;
  bool _busy = false;

  /// Chosen people by username, in the order chosen.
  final Map<String, UserSummary> _chosen = {};

  bool get _adding => widget.addTo != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _queryChanged(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    if (q.length > 30) q = q.substring(0, 30);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = q.isEmpty ? null : q);
    });
  }

  Future<void> _pickPhoto() async {
    final l10n = context.l10n;
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (!mounted || picked.isEmpty) return;
    final bytes = picked.first;
    final type = sniffImageType(bytes);
    if (type == null) {
      KSnack.error(context, l10n.createPhotoUnsupported);
      return;
    }
    if (bytes.length > maxPhotoBytes) {
      KSnack.error(context, l10n.createPhotoTooLarge);
      return;
    }
    setState(() {
      _photo = bytes;
      _photoType = type;
      _photoId = null;
    });
  }

  void _toggle(UserSummary u) => setState(() {
    if (_chosen.remove(u.username) == null) _chosen[u.username] = u;
  });

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (!_adding && name.isEmpty) {
      setState(() => _nameError = l10n.dmGroupNameRequired);
      return;
    }
    if (_chosen.isEmpty) {
      KSnack.error(context, l10n.dmGroupPickAtLeastOne);
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    final repo = ref.read(dmGroupsRepositoryProvider);
    try {
      final addTo = widget.addTo;
      if (addTo != null) {
        await repo.addMembers(addTo, _chosen.keys.toList());
        if (!mounted) return;
        ref.invalidate(dmGroupDetailProvider(addTo));
        KSnack.success(context, l10n.dmGroupMembersAdded);
        context.pop();
        return;
      }
      var photoId = _photoId;
      if (_photo case final bytes? when photoId == null) {
        photoId =
            (await ref
                    .read(mediaRepositoryProvider)
                    .uploadDmGroupPhoto(bytes, _photoType))
                .id;
        _photoId = photoId;
      }
      final detail = await repo.create(
        name: name,
        members: _chosen.keys.toList(),
        clientId: _clientId,
        photoMediaId: photoId,
      );
      if (!mounted) return;
      _clientId = newClientId();
      invalidateDmBoxes(ref);
      context.pushReplacement(
        AppRoutes.groupChat(detail.group.id),
        extra: detail.group.name,
      );
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      // A definite refusal: the next attempt is a new group.
      if (failure is ServerFailure) _clientId = newClientId();
      if (failure.code == ErrorCode.validationFailed &&
          failure is ServerFailure &&
          failure.details.any((d) => d.field == 'name')) {
        setState(() => _nameError = l10n.dmGroupNameRequired);
      } else {
        KSnack.error(context, failureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final candidates = ref.watch(
      dmGroupCandidatesProvider((query: _query, groupId: widget.addTo)),
    );
    final photo = _photo;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        title: Text(_adding ? l10n.dmGroupAddMembers : l10n.dmNewGroup),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
            child: TextButton(
              key: NewGroupScreen.submitKey,
              onPressed: _busy ? null : () => unawaited(_submit()),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_adding ? l10n.dmGroupAddMembers : l10n.dmGroupCreate),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (!_adding)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KSpacing.lg,
                  KSpacing.md,
                  KSpacing.lg,
                  KSpacing.sm,
                ),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: photo == null
                          ? l10n.dmGroupAddPhoto
                          : l10n.dmGroupChangePhoto,
                      excludeSemantics: true,
                      child: InkWell(
                        key: NewGroupScreen.photoKey,
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : () => unawaited(_pickPhoto()),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: p.primary.withValues(alpha: 0.12),
                          backgroundImage: photo == null
                              ? null
                              : MemoryImage(photo),
                          child: photo == null
                              ? Icon(
                                  Icons.add_a_photo_outlined,
                                  color: p.primary,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpacing.md),
                    Expanded(
                      child: TextField(
                        key: NewGroupScreen.nameKey,
                        controller: _name,
                        maxLength: 50,
                        textInputAction: TextInputAction.next,
                        style: t.body.copyWith(color: p.textPrimary),
                        decoration: InputDecoration(
                          labelText: l10n.dmGroupNameLabel,
                          hintText: l10n.dmGroupNameHint,
                          errorText: _nameError,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                KSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.dmGroupPickMembers,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ),
                  if (!_adding)
                    Text(
                      l10n.dmGroupSelected(
                        KFormat.compact(_chosen.length, l10n),
                      ),
                      key: NewGroupScreen.countKey,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: Text(
                l10n.dmGroupPickHint,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.sm,
                KSpacing.lg,
                KSpacing.xs,
              ),
              child: TextField(
                key: NewGroupScreen.searchKey,
                controller: _search,
                maxLength: 31,
                onChanged: _queryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.dmGroupSearchPeople,
                  counterText: '',
                  isDense: true,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (_chosen.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
                  children: [
                    for (final u in _chosen.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpacing.xs,
                        ),
                        child: InputChip(
                          label: Text(u.displayName),
                          avatar: KAvatar(
                            name: u.displayName,
                            imageUrl: u.avatarUrl,
                            size: 24,
                          ),
                          onDeleted: () => _toggle(u),
                          deleteButtonTooltipMessage: l10n.actionCancel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ...switch (candidates) {
            AsyncValue(:final value?) when value.data.isEmpty => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: KEmptyState(
                  key: NewGroupScreen.emptyKey,
                  icon: Icons.group_add_outlined,
                  title: _query == null
                      ? l10n.dmGroupCandidatesEmpty
                      : l10n.dmSearchEmpty(KFormat.bidiIsolate(_query!)),
                  message: l10n.dmGroupCandidatesEmptyBody,
                ),
              ),
            ],
            AsyncValue(:final value?) => [
              SliverList.list(
                children: [
                  for (final u in value.data)
                    CheckboxListTile(
                      key: NewGroupScreen.personKey(u.username),
                      value: _chosen.containsKey(u.username),
                      onChanged: _busy ? null : (_) => _toggle(u),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: KAvatar(
                        name: u.displayName,
                        imageUrl: u.avatarUrl,
                        size: KSizes.avatarSm,
                      ),
                      title: Text(
                        u.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // The handle reads left to right at the reading start.

                      subtitle: Align(
                        alignment: AlignmentDirectional.centerStart,

                        child: Text(
                          '@${u.username}',

                          maxLines: 1,

                          textDirection: TextDirection.ltr,

                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const SizedBox(height: KSpacing.xl),
                ],
              ),
            ],
            AsyncValue(:final error?) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: FailureErrorState(
                  title: l10n.errorTitle,
                  failure: toAppFailure(error),
                  onRetry: () => ref.invalidate(
                    dmGroupCandidatesProvider((
                      query: _query,
                      groupId: widget.addTo,
                    )),
                  ),
                ),
              ),
            ],
            _ => [
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(top: KSpacing.xl),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ],
          },
        ],
      ),
    );
  }
}
