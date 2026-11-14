import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/live_watch_repository.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => child,
    );

/// D154i («يوتيوب», CONVENTIONS §10.39): the host's watch-together — a
/// YouTube link (or a search, when the server has a key) to show, what is
/// showing and «إيقاف العرض», and the viewers' waiting suggestions to show
/// or dismiss.
Future<void> showLiveWatchSheet(
  BuildContext context, {
  required String roomId,
}) => _sheet(context, LiveWatchSheet(roomId: roomId));

/// D154i: a viewer suggests a video (a link, or a search when on).
Future<void> showLiveWatchSuggestSheet(
  BuildContext context, {
  required String roomId,
}) => _sheet(context, LiveWatchSheet(roomId: roomId, suggest: true));

class LiveWatchSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, this.suggest = false, super.key});

  final String roomId;

  /// A viewer's suggestion instead of the host's sheet.
  final bool suggest;

  static const linkKey = Key('watch.link');
  static const sendKey = Key('watch.send');
  static const searchKey = Key('watch.search');
  static const searchOffKey = Key('watch.searchOff');
  static const stopKey = Key('watch.stop');
  static Key resultKey(String videoId) => Key('watch.result.$videoId');
  static Key approveKey(String id) => Key('watch.approve.$id');
  static Key rejectKey(String id) => Key('watch.reject.$id');

  @override
  ConsumerState<LiveWatchSheet> createState() => _LiveWatchSheetState();
}

class _LiveWatchSheetState extends ConsumerState<LiveWatchSheet> {
  final _link = TextEditingController();
  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  List<LiveWatchVideo>? _results;

  LiveWatchController get _controller =>
      ref.read(liveWatchProvider(widget.roomId).notifier);

  @override
  void dispose() {
    _link.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<AppFailure?> Function() call, {
    bool close = false,
  }) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure == null ? null : failureMessage(l10n, failure);
    });
    if (failure == null && close) {
      if (widget.suggest) KSnack.success(context, l10n.liveWatchSuggestSent);
      Navigator.of(context).pop();
    }
  }

  void _pick(String ref) {
    if (youtubeVideoId(ref) == null) {
      setState(() => _error = context.l10n.liveWatchBadLink);
      return;
    }
    unawaited(
      _run(
        () =>
            widget.suggest ? _controller.suggest(ref) : _controller.start(ref),
        close: true,
      ),
    );
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final items = await ref.read(liveWatchRepositoryProvider).search(q);
      if (mounted) setState(() => _results = items);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    final view = ref.watch(liveWatchProvider(widget.roomId));
    final watch = view.watch;
    final searchOn = watch?.searchEnabled ?? false;
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
    Widget videoRow(
      LiveWatchVideo v, {
      Key? key,
      String? subtitle,
      List<Widget> actions = const [],
      VoidCallback? onTap,
    }) => InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                v.thumbnailUrl,
                width: 80,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 80,
                  height: 45,
                  child: ColoredBox(color: Color(0xFFE9E9EF)),
                ),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    KFormat.bidiIsolate(v.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: ink, height: 1.25),
                  ),
                  if (subtitle ?? v.channel case final s?)
                    Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: soft),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.suggest ? l10n.liveWatchSuggest : l10n.liveWatchTitle,
                  style: t.title.copyWith(color: ink),
                ),
                const SizedBox(height: KSpacing.md),
                if (!widget.suggest && watch?.video != null) ...[
                  Text(
                    l10n.liveWatchNowPlaying,
                    style: t.caption.copyWith(color: soft),
                  ),
                  videoRow(
                    watch!.video!,
                    actions: [
                      TextButton(
                        key: LiveWatchSheet.stopKey,
                        onPressed: _busy
                            ? null
                            : () => unawaited(_run(_controller.stop)),
                        child: Text(l10n.liveWatchStop),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: LiveWatchSheet.linkKey,
                        controller: _link,
                        enabled: !_busy,
                        keyboardType: TextInputType.url,
                        textDirection: TextDirection.ltr,
                        style: t.body.copyWith(color: ink),
                        decoration: field(l10n.liveWatchLinkHint),
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    FilledButton(
                      key: LiveWatchSheet.sendKey,
                      onPressed: _busy ? null : () => _pick(_link.text.trim()),
                      child: Text(
                        widget.suggest
                            ? l10n.liveWatchSuggestSend
                            : l10n.liveWatchPlay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.md),
                if (searchOn)
                  TextField(
                    key: LiveWatchSheet.searchKey,
                    controller: _query,
                    enabled: !_busy,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                    style: t.body.copyWith(color: ink),
                    decoration: field(l10n.liveWatchSearchHint)
                        .copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                  )
                else
                  Text(
                    l10n.liveWatchSearchOff,
                    key: LiveWatchSheet.searchOffKey,
                    style: t.caption.copyWith(color: soft),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: KSpacing.sm),
                    child: LinearProgressIndicator(),
                  ),
                if (_error case final e?)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.sm),
                    child: Text(
                      e,
                      style: t.caption.copyWith(color: const Color(0xFFD93A4A)),
                    ),
                  ),
                for (final v in _results ?? const <LiveWatchVideo>[])
                  videoRow(
                    v,
                    key: LiveWatchSheet.resultKey(v.videoId),
                    onTap: _busy ? null : () => _pick(v.videoId),
                  ),
                if (!widget.suggest) ...[
                  const SizedBox(height: KSpacing.md),
                  Text(
                    l10n.liveWatchSuggestions(view.suggestions.length),
                    style: t.bodyStrong.copyWith(color: ink),
                  ),
                  if (view.suggestions.isEmpty)
                    Text(
                      l10n.liveWatchNoSuggestions,
                      style: t.caption.copyWith(color: soft),
                    ),
                  for (final s in view.suggestions)
                    videoRow(
                      s.video,
                      subtitle: l10n.liveWatchSuggestedBy(
                        KFormat.bidiIsolate(s.suggester.displayName),
                      ),
                      actions: [
                        IconButton(
                          key: LiveWatchSheet.rejectKey(s.id),
                          tooltip: l10n.liveWatchReject,
                          onPressed: _busy
                              ? null
                              : () => unawaited(
                                  _run(
                                    () => _controller.decide(
                                      s.id,
                                      approve: false,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.close_rounded, color: soft),
                        ),
                        IconButton(
                          key: LiveWatchSheet.approveKey(s.id),
                          tooltip: l10n.liveWatchApprove,
                          onPressed: _busy
                              ? null
                              : () => unawaited(
                                  _run(
                                    () =>
                                        _controller.decide(s.id, approve: true),
                                  ),
                                ),
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFFF4D4D),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
