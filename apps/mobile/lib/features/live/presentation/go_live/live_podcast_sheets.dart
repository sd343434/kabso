import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The host's change of the hands switch and/or the question time
/// ([seconds] returns the new time; null inside = no limit).
typedef PodcastSettingsChange = Future<void> Function({
  bool? questionsOpen,
  int? Function()? seconds,
});

/// The Kabso white sheet's colours (as the seat count and category sheets).
abstract final class KPodcastSheet {
  static const ink = Color(0xFF1C1B1F);
  static const soft = Color(0xFF6B6B76);
  static const field = Color(0xFFF4F6FA);
  static const line = Color(0xFFE9EAEE);
}

/// D212: the question durations offered (null = no limit), in order.
List<int?> podcastQuestionChoices(LivePodcastConfig config) => [
  ...config.questionSeconds,
  null,
];

String podcastQuestionLabel(AppLocalizations l10n, int? seconds) =>
    seconds == null ? l10n.podcastNoLimit : l10n.podcastMinutes(seconds ~/ 60);

/// D212 (owner): the host's WHITE sheet «رفع الأيدي ✋» — «N طلبات · مقعد
/// واحد متاح», then each hand (picture, name, the optional question) with
/// «لاحقاً» and «اصعد»; under them the question time and the hands switch.
Future<void> showPodcastHandsSheet(
  BuildContext context, {
  required Future<List<LiveSeatRequest>> Function() load,
  required int freeSeats,
  required LivePodcast podcast,
  required LivePodcastConfig config,
  required Future<void> Function(LiveSeatRequest request) onBringUp,
  required Future<void> Function(LiveSeatRequest request) onLater,
  PodcastSettingsChange? onSettings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) => PodcastHandsSheet(
    load: load,
    freeSeats: freeSeats,
    podcast: podcast,
    config: config,
    onBringUp: onBringUp,
    onLater: onLater,
    onSettings: onSettings,
  ),
);

class PodcastHandsSheet extends StatefulWidget {
  const new({
    required this.load,
    required this.freeSeats,
    required this.podcast,
    required this.config,
    required this.onBringUp,
    required this.onLater,
    super.key,
    this.onSettings,
  });

  /// The pending hands in queue order (`listLiveSeatRequests`).
  final Future<List<LiveSeatRequest>> Function() load;
  final int freeSeats;
  final LivePodcast podcast;
  final LivePodcastConfig config;
  final Future<void> Function(LiveSeatRequest request) onBringUp;
  final Future<void> Function(LiveSeatRequest request) onLater;

  /// The host's switch and question time; null (a moderator): not shown.
  final PodcastSettingsChange? onSettings;

  static const sheetKey = Key('podcast.hands');
  static const summaryKey = Key('podcast.hands.summary');
  static const openKey = Key('podcast.hands.open');
  static Key laterKey(String id) => Key('podcast.hands.$id.later');
  static Key upKey(String id) => Key('podcast.hands.$id.up');
  static Key secondsKey(int? s) => Key('podcast.hands.seconds.${s ?? 'none'}');

  @override
  State<PodcastHandsSheet> createState() => _PodcastHandsSheetState();
}

class _PodcastHandsSheetState extends State<PodcastHandsSheet> {
  late Future<List<LiveSeatRequest>> _load = _fetch();
  late bool _open = widget.podcast.questionsOpen;
  late int? _seconds = widget.podcast.questionSeconds;
  late int _free = widget.freeSeats;

  Future<List<LiveSeatRequest>> _fetch() => widget.load();

  Future<void> _act(Future<void> Function() action, {bool up = false}) async {
    var ok = false;
    await runSeatAction(context, () async {
      await action();
      ok = true;
    });
    if (!mounted) return;
    if (ok && up) setState(() => _free = (_free - 1).clamp(0, 3));
    final next = _fetch();
    setState(() {
      _load = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return SafeArea(
      key: PodcastHandsSheet.sheetKey,
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: FutureBuilder<List<LiveSeatRequest>>(
          future: _load,
          builder: (context, snap) {
            final items = snap.data;
            final Widget list;
            if (items == null) {
              list = snap.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(KSpacing.lg),
                      child: Text(
                        failureMessage(l10n, toAppFailure(snap.error!)),
                        style: text.body.copyWith(color: KPodcastSheet.ink),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(KSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
            } else if (items.isEmpty) {
              list = Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Text(
                  l10n.podcastNoHands,
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: KPodcastSheet.soft),
                ),
              );
            } else {
              list = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in items)
                    _HandRow(
                      request: r,
                      onLater: r.deferred
                          ? null
                          : () => unawaited(_act(() => widget.onLater(r))),
                      onUp: _free <= 0
                          ? null
                          : () => unawaited(
                              _act(() => widget.onBringUp(r), up: true),
                            ),
                    ),
                ],
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                LiveWhiteSheetHeader(
                  title: l10n.podcastHandsTitle,
                  centred: true,
                ),
                Center(
                  child: Text(
                    '${l10n.podcastHandsRequests(items?.length ?? 0)} · '
                    '${l10n.podcastHandsSeats(_free)}',
                    key: PodcastHandsSheet.summaryKey,
                    style: text.caption.copyWith(
                      color: KPodcastSheet.soft,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_free <= 0 && (items?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l10n.podcastSeatsFull,
                      textAlign: TextAlign.center,
                      style: text.caption.copyWith(color: KPodcast.liveTag),
                    ),
                  ),
                const SizedBox(height: 8),
                list,
                if (widget.onSettings case final settings?) ...[
                  const Divider(color: KPodcastSheet.line, height: 24),
                  SwitchListTile(
                    key: PodcastHandsSheet.openKey,
                    value: _open,
                    activeThumbColor: KPodcast.liveTag,
                    title: Text(
                      l10n.podcastQuestionsOpen,
                      style: text.body.copyWith(color: KPodcastSheet.ink),
                    ),
                    onChanged: (v) {
                      setState(() => _open = v);
                      unawaited(
                        runSeatAction(
                          context,
                          () => settings(questionsOpen: v),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      l10n.podcastQuestionTime,
                      style: text.bodyStrong.copyWith(color: KPodcastSheet.ink),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in podcastQuestionChoices(widget.config))
                          ChoiceChip(
                            key: PodcastHandsSheet.secondsKey(s),
                            label: Text(podcastQuestionLabel(l10n, s)),
                            selected: s == _seconds,
                            selectedColor: KPodcast.liveTag,
                            backgroundColor: KPodcastSheet.field,
                            side: BorderSide(
                              color: s == _seconds
                                  ? KPodcast.liveTag
                                  : KPodcastSheet.line,
                            ),
                            showCheckmark: false,
                            labelStyle: text.label.copyWith(
                              color: s == _seconds
                                  ? const Color(0xFFFFFFFF)
                                  : KPodcastSheet.ink,
                            ),
                            onSelected: (_) {
                              setState(() => _seconds = s);
                              unawaited(
                                runSeatAction(
                                  context,
                                  () => settings(seconds: () => s),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HandRow extends StatelessWidget {
  const new({required this.request, required this.onLater, required this.onUp});

  final LiveSeatRequest request;
  final VoidCallback? onLater;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final user = request.user;
    final question = request.question;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          KAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong.copyWith(color: KPodcastSheet.ink),
                ),
                if (question != null && question.isNotEmpty)
                  Text(
                    question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: KPodcastSheet.soft),
                  )
                else if (request.deferred)
                  Text(
                    l10n.podcastDeferred,
                    style: text.caption.copyWith(color: KPodcastSheet.soft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: PodcastHandsSheet.laterKey(request.id),
            onPressed: onLater,
            style: OutlinedButton.styleFrom(
              foregroundColor: KPodcastSheet.ink,
              side: const BorderSide(color: KPodcastSheet.line),
              shape: const StadiumBorder(),
              minimumSize: const Size(64, 36),
            ),
            child: Text(l10n.podcastLater),
          ),
          const SizedBox(width: 6),
          FilledButton(
            key: PodcastHandsSheet.upKey(request.id),
            onPressed: onUp,
            style: FilledButton.styleFrom(
              backgroundColor: KPodcast.liveTag,
              foregroundColor: const Color(0xFFFFFFFF),
              // No free seat: greyed, still readable.
              disabledBackgroundColor: KPodcastSheet.line,
              disabledForegroundColor: KPodcastSheet.soft,
              shape: const StadiumBorder(),
              minimumSize: const Size(64, 36),
            ),
            child: Text(l10n.podcastBringUp),
          ),
        ],
      ),
    );
  }
}

/// D212: a listener raises a hand — an optional short question (80
/// characters), then «ارفع يدي». Returns null when dismissed, else the
/// question ('' = none).
Future<String?> showPodcastAskSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => const _AskSheet(),
    );

class _AskSheet extends StatefulWidget {
  const new();

  static const fieldKey = Key('podcast.ask.field');
  static const sendKey = Key('podcast.ask.send');

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiveWhiteSheetHeader(title: l10n.podcastAskTitle, centred: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: _AskSheet.fieldKey,
                controller: _field,
                maxLength: PodcastAsk.maxLength,
                style: text.body.copyWith(color: KPodcastSheet.ink),
                decoration: InputDecoration(
                  hintText: l10n.podcastAskHint,
                  filled: true,
                  fillColor: KPodcastSheet.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: FilledButton.icon(
                key: _AskSheet.sendKey,
                style: FilledButton.styleFrom(
                  backgroundColor: KPodcast.liveTag,
                  foregroundColor: const Color(0xFFFFFFFF),
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).pop(_field.text.trim()),
                icon: const Icon(Icons.front_hand_rounded),
                label: Text(l10n.podcastAskSend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keys and limits of the ask sheet.
abstract final class PodcastAsk {
  static const maxLength = 80;
  static const Key fieldKey = _AskSheet.fieldKey;
  static const Key sendKey = _AskSheet.sendKey;
}

/// D212 setup: pick up to 3 guests (search by username). Returns the new
/// list, or null when dismissed.
Future<List<UserSummary>?> showPodcastGuestPicker(
  BuildContext context, {
  required List<UserSummary> selected,
}) => showModalBottomSheet<List<UserSummary>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) => _GuestPicker(selected: selected),
);

class _GuestPicker extends ConsumerStatefulWidget {
  const new({required this.selected});

  final List<UserSummary> selected;

  static const fieldKey = Key('podcast.guests.field');
  static const doneKey = Key('podcast.guests.done');

  @override
  ConsumerState<_GuestPicker> createState() => _GuestPickerState();
}

class _GuestPickerState extends ConsumerState<_GuestPicker> {
  late final List<UserSummary> _picked = [...widget.selected];
  Timer? _debounce;
  Future<List<UserSummary>>? _results;

  void _changed(String raw) {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(
        () => _results = q.isEmpty
            ? null
            : ref.read(postsRepositoryProvider).searchUsers(q),
      );
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
    final text = context.textStyles;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveWhiteSheetHeader(
                title: l10n.podcastSetupGuests,
                centred: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: _GuestPicker.fieldKey,
                  onChanged: _changed,
                  style: text.body.copyWith(color: KPodcastSheet.ink),
                  decoration: InputDecoration(
                    hintText: l10n.podcastSetupGuestSearch,
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: KPodcastSheet.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_picked.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final u in _picked)
                        InputChip(
                          label: Text(u.displayName),
                          onDeleted: () => setState(() => _picked.remove(u)),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: FutureBuilder<List<UserSummary>>(
                  future: _results,
                  builder: (context, snap) {
                    final users = snap.data ?? const <UserSummary>[];
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final u in users)
                          CheckboxListTile(
                            value: _picked.any((p) => p.id == u.id),
                            onChanged:
                                _picked.length >= 3 &&
                                    !_picked.any((p) => p.id == u.id)
                                ? null
                                : (on) => setState(() {
                                    if (on ?? false) {
                                      _picked.add(u);
                                    } else {
                                      _picked.removeWhere((p) => p.id == u.id);
                                    }
                                  }),
                            secondary: KAvatar(
                              name: u.displayName,
                              imageUrl: u.avatarUrl,
                              size: 36,
                            ),
                            title: Text(
                              u.displayName,
                              style: text.body.copyWith(
                                color: KPodcastSheet.ink,
                              ),
                            ),
                            subtitle: Text(
                              '@${u.username}',
                              textDirection: TextDirection.ltr,
                              style: text.caption.copyWith(
                                color: KPodcastSheet.soft,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l10n.podcastSetupGuestsNote,
                  style: text.caption.copyWith(color: KPodcastSheet.soft),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: FilledButton(
                  key: _GuestPicker.doneKey,
                  style: FilledButton.styleFrom(
                    backgroundColor: KPodcast.liveTag,
                    foregroundColor: const Color(0xFFFFFFFF),
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.of(context).pop(_picked),
                  child: Text(l10n.goLiveDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
