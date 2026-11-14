import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.2): «عرض الكل» — every official announcement
/// of the owner, pinned first then newest, page by page.
class OfficialPostsScreen extends ConsumerStatefulWidget {
  const new({required this.username, super.key});

  final String username;

  static const listKey = Key('owner.official.all');

  @override
  ConsumerState<OfficialPostsScreen> createState() =>
      _OfficialPostsScreenState();
}

class _OfficialPostsScreenState extends ConsumerState<OfficialPostsScreen> {
  final List<Post> _posts = [];
  String? _next;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_more());
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(ownerProfileRepositoryProvider)
          .officialPosts(widget.username, cursor: _next);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.items);
        _next = page.next;
        _done = _next == null;
        _error = null;
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
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text(l10n.ownerOfficialTitle)),
      body: _posts.isEmpty && _error != null
          ? Center(
              child: TextButton(
                onPressed: () => unawaited(_more()),
                child: Text(failureMessage(l10n, toAppFailure(_error!))),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) unawaited(_more());
                return false;
              },
              child: ListView.separated(
                key: OfficialPostsScreen.listKey,
                padding: const EdgeInsets.all(KSpacing.lg),
                itemCount: _posts.length + (_done ? 0 : 1),
                separatorBuilder: (_, _) => Divider(height: 1, color: p.border),
                itemBuilder: (context, i) => i == _posts.length
                    ? const Padding(
                        padding: EdgeInsets.all(KSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : OfficialPostRow(post: _posts[i], first: i == 0),
              ),
            ),
    );
  }
}
