import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/application/my_posts_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/posts/:postId/edit` (KL-060): the author edits a post's caption,
/// place and settings (`PATCH /posts/{postId}`). Photos never change.
/// Save sends only what changed; editing a published caption marks the
/// post "Edited" (server). Leaving with changes asks first.
///
/// A draft or scheduled post (from Drafts) also offers Post now, Schedule
/// (or Change time) and, when scheduled, Move to drafts; each sends the
/// new `status` with any changes (CONVENTIONS §11.2).
class EditPostScreen extends ConsumerWidget {
  const new({required this.postId, super.key});

  final String postId;

  static const textKey = Key('editPost.text');
  static const saveKey = Key('editPost.save');
  static const placeKey = Key('editPost.place');
  static const removePlaceKey = Key('editPost.place.remove');
  static const settingsKey = Key('editPost.settings');
  static const discardKey = Key('editPost.discard');
  static const publishNowKey = Key('editPost.publishNow');
  static const scheduleKey = Key('editPost.schedule');
  static const toDraftsKey = Key('editPost.toDrafts');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final edited = ref.watch(postEditsProvider.select((e) => e[postId]));
    return switch (ref.watch(postProvider(postId))) {
      AsyncData(:final value) => _EditPostForm(post: edited ?? value),
      AsyncError(:final error) => Scaffold(
        appBar: KAppBar(title: Text(l10n.editPostTitle)),
        body: switch (toAppFailure(error)) {
          ServerFailure(code: ErrorCode.notFound) => KEmptyState(
            icon: Icons.visibility_off_outlined,
            title: l10n.postUnavailableTitle,
            message: l10n.postUnavailableBody,
          ),
          final failure => FailureErrorState(
            title: l10n.errorTitle,
            failure: failure,
            onRetry: () => ref.invalidate(postProvider(postId)),
          ),
        },
      ),
      _ => Scaffold(
        appBar: KAppBar(title: Text(l10n.editPostTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _EditPostForm extends ConsumerStatefulWidget {
  const new({required this.post});

  final Post post;

  @override
  ConsumerState<_EditPostForm> createState() => _EditPostFormState();
}

class _EditPostFormState extends ConsumerState<_EditPostForm> {
  late final _text = CaptionController(text: widget.post.text);
  late String _place = widget.post.location ?? '';
  late PostSettingsDraft _settings = PostSettingsDraft(
    commentsEnabled: widget.post.commentsEnabled,
    whoCanComment: widget.post.whoCanComment,
    hideLikeCount: widget.post.hideLikeCount,
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// What differs from the post as loaded.
  PostUpdate get _update {
    final p = widget.post;
    final text = _text.text.trim();
    return PostUpdate(
      text: text == p.text ? null : text,
      location: _place == (p.location ?? '') ? null : _place,
      commentsEnabled: _settings.commentsEnabled == p.commentsEnabled
          ? null
          : _settings.commentsEnabled,
      whoCanComment: _settings.whoCanComment == p.whoCanComment
          ? null
          : _settings.whoCanComment,
      hideLikeCount: _settings.hideLikeCount == p.hideLikeCount
          ? null
          : _settings.hideLikeCount,
    );
  }

  /// A text-only post cannot be emptied; the caption has a limit.
  bool get _valid {
    final text = _text.text.trim();
    return (text.isNotEmpty || widget.post.media.isNotEmpty) &&
        text.characters.length <= maxPostText;
  }

  Future<void> _save() => _submit(done: context.l10n.editPostSaved);

  /// Sends the changes, with [status] (and [publishAt]) when the post
  /// moves; says [done] and leaves.
  Future<void> _submit({
    required String done,
    String? status,
    DateTime? publishAt,
  }) async {
    final changes = _update;
    final update = PostUpdate(
      text: changes.text,
      location: changes.location,
      commentsEnabled: changes.commentsEnabled,
      whoCanComment: changes.whoCanComment,
      hideLikeCount: changes.hideLikeCount,
      status: status,
      publishAt: publishAt,
    );
    if (_saving || update.isEmpty || !_valid) return;
    setState(() => _saving = true);
    try {
      final post = await ref
          .read(postsRepositoryProvider)
          .updatePost(widget.post.id, update);
      if (!mounted) return;
      ref.read(postEditsProvider.notifier).put(post);
      if (status != null) {
        ref.invalidate(myPostsProvider);
        if (post.status == 'PUBLISHED') {
          for (final feed in HomeFeed.values) {
            ref.invalidate(postsFeedProvider(feed));
          }
        }
      }
      KSnack.success(context, done);
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    }
  }

  Future<void> _schedule() async {
    final l10n = context.l10n;
    final at = await pickScheduleTime(context, widget.post.publishAt);
    if (at == null || !mounted) return;
    if (!isSchedulable(at, clock.now())) {
      KSnack.error(context, l10n.createScheduleWindow);
      return;
    }
    await _submit(
      done: l10n.createScheduled(scheduleLabel(context, at)),
      status: 'SCHEDULED',
      publishAt: at,
    );
  }

  Future<void> _editPlace() async {
    final place = await showPlaceSheet(context, _place);
    if (place != null && mounted) setState(() => _place = place);
  }

  Future<void> _editSettings() async {
    final next = await showAdvancedSheet(context, _settings);
    if (next != null && mounted) setState(() => _settings = next);
  }

  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.editPostDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.editPostKeep),
          ),
          TextButton(
            key: EditPostScreen.discardKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.editPostDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    _text.entityColor = p.primary;
    final post = widget.post;
    final dirty = !_update.isEmpty;
    final draft = post.status == 'DRAFT';
    final scheduled = post.status == 'SCHEDULED';
    final textEmpty = _text.text.trim().isEmpty && post.media.isEmpty;
    return PopScope(
      canPop: !dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        appBar: KAppBar(
          title: Text(l10n.editPostTitle),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(KSpacing.sm),
                      child: SizedBox.square(
                        dimension: KMetrics.iconMd,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      key: EditPostScreen.saveKey,
                      onPressed: dirty && _valid ? _save : null,
                      child: Text(l10n.editPostSave),
                    ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(KSpacing.md),
          children: [
            if (draft || scheduled) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(
                  avatar: Icon(
                    draft ? Icons.drafts_outlined : Icons.schedule_rounded,
                    size: KMetrics.iconSm,
                  ),
                  label: Text(
                    draft
                        ? l10n.editPostDraftBadge
                        : l10n.editPostScheduledBadge(
                            scheduleLabel(context, post.publishAt!),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            if (post.media.isNotEmpty) ...[
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.media.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: KSpacing.sm),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.md),
                    child: ColoredBox(
                      color: p.surfaceRaised,
                      child: Image.network(
                        post.media[i].thumbUrl,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) =>
                            const SizedBox.square(dimension: 88),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.editPostPhotosFixed,
                style: t.caption.copyWith(color: p.textTertiary),
              ),
              const SizedBox(height: KSpacing.md),
            ],
            TextField(
              key: EditPostScreen.textKey,
              textDirection: KFormat.inputDirection(_text.text),
              controller: _text,
              enabled: !_saving,
              minLines: 4,
              maxLines: 10,
              maxLength: maxPostText,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: l10n.createTextHint,
                errorText: textEmpty ? l10n.editPostTextRequired : null,
              ),
            ),
            const SizedBox(height: KSpacing.md),
            ComposeOptionRow(
              key: EditPostScreen.placeKey,
              icon: const AppIcon(AppIcons.location),
              title: l10n.createPlaceTitle,
              subtitle: _place.isEmpty ? l10n.editPostNoPlace : _place,
              trailing: _place.isEmpty
                  ? null
                  : IconButton(
                      key: EditPostScreen.removePlaceKey,
                      tooltip: l10n.editPostRemovePlace,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _place = ''),
                      icon: AppIcon(
                        AppIcons.close,
                        size: KMetrics.iconSm,
                        color: p.textSecondary,
                      ),
                    ),
              onTap: _saving ? null : _editPlace,
            ),
            const SizedBox(height: KSpacing.sm),
            ComposeOptionRow(
              key: EditPostScreen.settingsKey,
              neutralIcon: true,
              icon: const Icon(Icons.tune_rounded),
              title: l10n.createAdvancedTitle,
              subtitle: l10n.createAdvancedSubtitle,
              onTap: _saving ? null : _editSettings,
            ),
            if (draft || scheduled) ...[
              const SizedBox(height: KSpacing.lg),
              KButton(
                key: EditPostScreen.publishNowKey,
                label: l10n.editPostPublishNow,
                onPressed: _saving || !_valid
                    ? null
                    : () => _submit(
                        done: l10n.editPostPublished,
                        status: 'PUBLISHED',
                      ),
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: EditPostScreen.scheduleKey,
                label: scheduled
                    ? l10n.editPostReschedule
                    : l10n.editPostSchedule,
                variant: KButtonVariant.secondary,
                onPressed: _saving || !_valid ? null : _schedule,
              ),
              if (scheduled) ...[
                const SizedBox(height: KSpacing.sm),
                KButton(
                  key: EditPostScreen.toDraftsKey,
                  label: l10n.editPostToDrafts,
                  variant: KButtonVariant.secondary,
                  onPressed: _saving || !_valid
                      ? null
                      : () => _submit(
                          done: l10n.editPostMovedToDrafts,
                          status: 'DRAFT',
                        ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
