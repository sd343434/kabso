import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Who saw your [story] (`GET /stories/{id}/viewers`, the author only, for
/// 48 hours), newest first, paged as the list scrolls.
Future<void> showStoryViewersSheet(BuildContext context, Story story) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: StoryViewersSheet(story: story),
      ),
    );

class StoryViewersSheet extends ConsumerStatefulWidget {
  const new({required this.story, super.key});

  final Story story;

  static const emptyKey = Key('story.viewers.empty');
  static Key userKey(String username) => Key('story.viewers.$username');

  @override
  ConsumerState<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends ConsumerState<StoryViewersSheet> {
  final List<UserSummary> _users = [];
  String? _next;
  bool _done = false;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(storiesRepositoryProvider)
          .viewers(widget.story.id, cursor: _next);
      if (!mounted) return;
      setState(() {
        final known = {for (final u in _users) u.id};
        _users.addAll(page.items.where((u) => !known.contains(u.id)));
        _next = page.next;
        _done = _next == null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          child: Text(
            l10n.storyViewCount(widget.story.viewCount ?? 0),
            style: context.textStyles.title,
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        Expanded(
          child: _users.isEmpty && _done
              ? KEmptyState(
                  key: StoryViewersSheet.emptyKey,
                  icon: Icons.visibility_outlined,
                  title: l10n.storyNoViewers,
                  message: l10n.storyNoViewersBody,
                  compact: true,
                )
              : _users.isEmpty && _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(failureMessage(l10n, toAppFailure(_error!))),
                      TextButton(
                        onPressed: _load,
                        child: Text(l10n.actionRetry),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollEndNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 200) unawaited(_load());
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: _users.length + (_done ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (i == _users.length) {
                        return Padding(
                          padding: const EdgeInsets.all(KSpacing.md),
                          child: Center(
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _load,
                                    child: Text(l10n.actionRetry),
                                  ),
                          ),
                        );
                      }
                      final u = _users[i];
                      final name = u.displayName.isEmpty
                          ? u.username
                          : u.displayName;
                      return ListTile(
                        key: StoryViewersSheet.userKey(u.username),
                        leading: ExcludeSemantics(
                          child: KAvatar(name: name, imageUrl: u.avatarUrl),
                        ),
                        title: Text(name, maxLines: 1),
                        subtitle: Text(
                          KHandle.text(
                            l10n,
                            u.username,
                            premiumTier: u.premiumTier,
                          ),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          style: TextStyle(color: p.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
