import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
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
  Future<void> Function(LiveSeatRequest request)? onHotSeat,
  Future<void> Function(LiveSeatRequest request)? onShowOnScreen,
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
    onHotSeat: onHotSeat,
    onShowOnScreen: onShowOnScreen,
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
    this.onHotSeat,
    this.onShowOnScreen,
  });

  /// D363 scope extension: the host shows a hand's question over the video
  /// (the hand stays up); null — not the host, or an audio podcast.
  final Future<void> Function(LiveSeatRequest request)? onShowOnScreen;

  /// D363 (§10.157): a video podcast — «الكرسي الساخن» on a hand with a
  /// question, and the hands listed by their upvotes (most first).
  final Future<void> Function(LiveSeatRequest request)? onHotSeat;

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
  static Key hotSeatKey(String id) => Key('podcast.hands.$id.hotSeat');
  static Key onScreenKey(String id) => Key('podcast.hands.$id.onScreen');
  static Key secondsKey(int? s) => Key('podcast.hands.seconds.${s ?? 'none'}');

  @override
  State<PodcastHandsSheet> createState() => _PodcastHandsSheetState();
}

class _PodcastHandsSheetState extends State<PodcastHandsSheet> {
  late Future<List<LiveSeatRequest>> _load = _fetch();
  late bool _open = widget.podcast.questionsOpen;
  late int? _seconds = widget.podcast.questionSeconds;
  late int _free = widget.freeSeats;

  Future<List<LiveSeatRequest>> _fetch() async {
    final items = await widget.load();
    if (widget.onHotSeat == null) return items;
    // D363: most votes first, the queue order among equals (a stable sort).
    final order = {for (final (i, r) in items.indexed) r.id: i};
    return [...items]..sort((a, b) {
      final v = b.votes.compareTo(a.votes);
      return v != 0 ? v : order[a.id]!.compareTo(order[b.id]!);
    });
  }

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
                      onHotSeat:
                          widget.onHotSeat == null ||
                              _free <= 0 ||
                              (r.question ?? '').isEmpty
                          ? null
                          : () => unawaited(
                              _act(() => widget.onHotSeat!(r), up: true),
                            ),
                      votes: widget.onHotSeat == null ? null : r.votes,
                      onShowOnScreen:
                          widget.onShowOnScreen == null ||
                              (r.question ?? '').isEmpty
                          ? null
                          : () => unawaited(
                              _act(() => widget.onShowOnScreen!(r)),
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
  const new({
    required this.request,
    required this.onLater,
    required this.onUp,
    this.onHotSeat,
    this.votes,
    this.onShowOnScreen,
  });

  /// D363 scope extension: «اعرض على الشاشة».
  final VoidCallback? onShowOnScreen;

  final LiveSeatRequest request;
  final VoidCallback? onLater;
  final VoidCallback? onUp;

  /// D363: «الكرسي الساخن» (a video podcast's hand with a question).
  final VoidCallback? onHotSeat;

  /// D363: the question's upvotes (a video podcast), else null.
  final int? votes;

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
                  ),
                if (votes case final v?)
                  Semantics(
                    label: l10n.podcastVotes(v),
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded,
                          size: 13,
                          color: KPodcast.liveTag,
                        ),
                        Text(
                          KFormat.compactLatin(v),
                          style: text.caption.copyWith(
                            fontFamily: KFonts.latin,
                            color: KPodcast.liveTag,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
          if (onShowOnScreen != null) ...[
            IconButton(
              key: PodcastHandsSheet.onScreenKey(request.id),
              tooltip: l10n.podcastShowOnScreen,
              onPressed: onShowOnScreen,
              style: IconButton.styleFrom(
                backgroundColor: KPodcastSheet.field,
                foregroundColor: KPodcastSheet.ink,
              ),
              icon: const Icon(Icons.present_to_all_rounded, size: 20),
            ),
            const SizedBox(width: 6),
          ],
          if (onHotSeat != null) ...[
            IconButton(
              key: PodcastHandsSheet.hotSeatKey(request.id),
              tooltip: l10n.podcastShotHotSeat,
              onPressed: onHotSeat,
              style: IconButton.styleFrom(
                backgroundColor: KPodcast.speakingRing,
                foregroundColor: KPodcastSheet.ink,
              ),
              icon: const Icon(Icons.local_fire_department_rounded, size: 20),
            ),
            const SizedBox(width: 6),
          ],
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

/// D363 (§10.157): the host's short title for a video podcast guest when
/// inviting (the lower third «الضيف: الاسم — اللقب»), the ask sheet's look:
/// 40 characters, optional. Returns null when dismissed, else the title
/// ('' = none).
Future<String?> showPodcastGuestTitleSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => const _AskSheet(guestTitle: true),
    );

class _AskSheet extends StatefulWidget {
  const new({this.guestTitle = false});

  /// D363: the guest's title (40 characters, the invite's words).
  final bool guestTitle;

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
            LiveWhiteSheetHeader(
              title: widget.guestTitle
                  ? l10n.liveSeatInvite
                  : l10n.podcastAskTitle,
              centred: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: _AskSheet.fieldKey,
                controller: _field,
                maxLength: widget.guestTitle
                    ? PodcastAsk.guestTitleMaxLength
                    : PodcastAsk.maxLength,
                style: text.body.copyWith(color: KPodcastSheet.ink),
                decoration: InputDecoration(
                  hintText: widget.guestTitle
                      ? l10n.podcastGuestTitleHint
                      : l10n.podcastAskHint,
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
                icon: Icon(
                  widget.guestTitle
                      ? Icons.person_add_alt_1_rounded
                      : Icons.front_hand_rounded,
                ),
                label: Text(
                  widget.guestTitle
                      ? l10n.liveSeatInviteAccept
                      : l10n.podcastAskSend,
                ),
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

  /// D363: a video podcast guest's title (§10.157: 1–40 code points).
  static const guestTitleMaxLength = 40;
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

/// D363 (§10.157): a video podcast's questions for every listener — most
/// votes first; a listener upvotes others' questions (one vote each, tap
/// again to take it back). [questions] is `LiveSeats.questions`; [onVote]
/// answers the new count. The asker's own question has no vote button.
Future<void> showPodcastQuestionsSheet(
  BuildContext context, {
  required List<LivePodcastQuestion> questions,
  required String? me,
  required Future<LivePodcastQuestionVotes> Function(
    LivePodcastQuestion question, {
    required bool vote,
  })
  onVote,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) =>
      PodcastQuestionsSheet(questions: questions, me: me, onVote: onVote),
);

class PodcastQuestionsSheet extends StatefulWidget {
  const new({
    required this.questions,
    required this.me,
    required this.onVote,
    super.key,
  });

  final List<LivePodcastQuestion> questions;
  final String? me;
  final Future<LivePodcastQuestionVotes> Function(
    LivePodcastQuestion question, {
    required bool vote,
  })
  onVote;

  static const sheetKey = Key('podcast.questions');
  static Key voteKey(String id) => Key('podcast.questions.$id.vote');

  @override
  State<PodcastQuestionsSheet> createState() => _PodcastQuestionsSheetState();
}

class _PodcastQuestionsSheetState extends State<PodcastQuestionsSheet> {
  late List<LivePodcastQuestion> _items = widget.questions;
  final Set<String> _busy = {};

  Future<void> _toggle(LivePodcastQuestion q) async {
    if (_busy.contains(q.requestId)) return;
    setState(() => _busy.add(q.requestId));
    await runSeatAction(context, () async {
      final r = await widget.onVote(q, vote: !q.votedByMe);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final x in _items)
            if (x.requestId == r.requestId)
              x.copyWith(votes: r.votes, votedByMe: r.votedByMe)
            else
              x,
        ];
      });
    });
    if (mounted) setState(() => _busy.remove(q.requestId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return SafeArea(
      key: PodcastQuestionsSheet.sheetKey,
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            LiveWhiteSheetHeader(
              title: l10n.podcastQuestionsTitle,
              centred: true,
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Text(
                  l10n.podcastNoQuestions,
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: KPodcastSheet.soft),
                ),
              ),
            for (final q in _items)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    KAvatar(
                      name: q.user.displayName,
                      imageUrl: q.user.avatarUrl,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            q.user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.caption.copyWith(
                              color: KPodcastSheet.soft,
                            ),
                          ),
                          Text(
                            q.question,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: text.body.copyWith(color: KPodcastSheet.ink),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _VoteButton(
                      key: PodcastQuestionsSheet.voteKey(q.requestId),
                      votes: q.votes,
                      on: q.votedByMe,
                      onTap: widget.me == null || q.user.id == widget.me
                          ? null
                          : () => unawaited(_toggle(q)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: KSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const new({
    required this.votes,
    required this.on,
    required this.onTap,
    super.key,
  });

  final int votes;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = on ? const Color(0xFFFFFFFF) : KPodcast.liveTag;
    return Semantics(
      button: onTap != null,
      selected: on,
      label:
          '${on ? l10n.podcastUnvote : l10n.podcastVote}، '
          '${l10n.podcastVotes(votes)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KSizes.minTouchTarget,
            minHeight: KSizes.minTouchTarget,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: on ? KPodcast.liveTag : const Color(0x00000000),
                borderRadius: BorderRadius.circular(KRadius.pill),
                border: Border.all(color: KPodcast.liveTag),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward_rounded, size: 16, color: color),
                  Text(
                    KFormat.compactLatin(votes),
                    style: context.textStyles.caption.copyWith(
                      fontFamily: KFonts.latin,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D363 (§10.157) + scope extension: the host's director controls —
/// «تلقائي», the shot kept on one person ([people] on air, the host
/// first), and a layout kept (speaker / split / hot seat, the last only
/// with a hot seat). Returns the new control (both null = «تلقائي»), or
/// nothing when dismissed.
Future<({String? pin, PodcastShotKind? layout})?> showPodcastDirectorSheet(
  BuildContext context, {
  required List<({String id, String name})> people,
  required String? pin,
  required PodcastShotKind? layout,
  bool hotSeat = false,
}) => showModalBottomSheet<({String? pin, PodcastShotKind? layout})>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) {
    final l10n = sheet.l10n;
    final text = sheet.textStyles;
    Widget option(
      Key key,
      String label,
      IconData icon, {
      required bool on,
      required ({String? pin, PodcastShotKind? layout}) choice,
    }) => ListTile(
      key: key,
      dense: true,
      leading: Icon(icon, color: KPodcastSheet.ink),
      title: Text(label, style: text.body.copyWith(color: KPodcastSheet.ink)),
      trailing: on
          ? const Icon(Icons.check_rounded, color: KPodcast.liveTag)
          : null,
      onTap: () => Navigator.of(sheet).pop(choice),
    );
    Widget section(String label) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 2),
      child: Text(
        label,
        style: text.caption.copyWith(
          color: KPodcastSheet.soft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            LiveWhiteSheetHeader(title: l10n.podcastDirector, centred: true),
            option(
              PodcastDirectorSheet.optionKey(null),
              l10n.podcastDirectorAuto,
              Icons.movie_filter_rounded,
              on: pin == null && layout == null,
              choice: (pin: null, layout: null),
            ),
            section(l10n.podcastDirectorPeople),
            for (final p in people)
              option(
                PodcastDirectorSheet.optionKey(p.id),
                l10n.podcastDirectorPinned(p.name),
                Icons.push_pin_rounded,
                on: pin == p.id,
                choice: (pin: pin == p.id ? null : p.id, layout: layout),
              ),
            section(l10n.podcastDirectorLayout),
            for (final kind in [
              PodcastShotKind.speaker,
              PodcastShotKind.split,
              if (hotSeat) PodcastShotKind.hotSeat,
            ])
              option(
                PodcastDirectorSheet.layoutKey(kind),
                podcastShotLabel(l10n, kind),
                switch (kind) {
                  PodcastShotKind.split => Icons.view_agenda_rounded,
                  PodcastShotKind.hotSeat =>
                    Icons.local_fire_department_rounded,
                  _ => Icons.person_rounded,
                },
                on: layout == kind,
                choice: (pin: pin, layout: layout == kind ? null : kind),
              ),
            const SizedBox(height: KSpacing.sm),
          ],
        ),
      ),
    );
  },
);

/// The shot's name (the chips, the director sheet).
String podcastShotLabel(AppLocalizations l10n, PodcastShotKind kind) =>
    switch (kind) {
      PodcastShotKind.speaker => l10n.podcastShotSpeaker,
      PodcastShotKind.split => l10n.podcastShotSplit,
      PodcastShotKind.grid => l10n.podcastShotGrid,
      PodcastShotKind.hotSeat => l10n.podcastShotHotSeat,
    };

/// D363 scope extension: who answers the question on screen ([people] on
/// air, the host first). Null when dismissed.
Future<String?> showPodcastAnswerPicker(
  BuildContext context, {
  required List<({String id, String name})> people,
}) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveWhiteSheetHeader(
          title: sheet.l10n.podcastShowOnScreen,
          centred: true,
        ),
        for (final p in people)
          ListTile(
            key: Key('podcast.answer.${p.id}'),
            leading: const Icon(
              Icons.record_voice_over_rounded,
              color: KPodcastSheet.ink,
            ),
            title: Text(
              p.name,
              style: sheet.textStyles.body.copyWith(color: KPodcastSheet.ink),
            ),
            onTap: () => Navigator.of(sheet).pop(p.id),
          ),
        const SizedBox(height: KSpacing.sm),
      ],
    ),
  ),
);

/// D363 scope extension: the host's segments editor «فقرات الحلقة» — up to
/// [LivePodcastSegment.max] rows of a title (1–40 characters) and optional
/// minutes; «حفظ الفقرات» returns the list (null when dismissed).
Future<List<LivePodcastSegment>?> showPodcastSegmentsSheet(
  BuildContext context, {
  required List<LivePodcastSegment> segments,
}) => showModalBottomSheet<List<LivePodcastSegment>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (sheet) => PodcastSegmentsSheet(segments: segments),
);

class PodcastSegmentsSheet extends StatefulWidget {
  const new({required this.segments, super.key});

  final List<LivePodcastSegment> segments;

  static const sheetKey = Key('podcast.segments');
  static const addKey = Key('podcast.segments.add');
  static const saveKey = Key('podcast.segments.save');
  static Key titleKey(int i) => Key('podcast.segments.$i.title');
  static Key minutesKey(int i) => Key('podcast.segments.$i.minutes');
  static Key removeKey(int i) => Key('podcast.segments.$i.remove');

  @override
  State<PodcastSegmentsSheet> createState() => _PodcastSegmentsSheetState();
}

class _PodcastSegmentsSheetState extends State<PodcastSegmentsSheet> {
  late final List<
    ({TextEditingController title, TextEditingController minutes})
  >
  _rows = [
    for (final g in widget.segments) _row(g.title, g.minutes),
    if (widget.segments.isEmpty) _row('', null),
  ];

  ({TextEditingController title, TextEditingController minutes}) _row(
    String title,
    int? minutes,
  ) => (
    title: TextEditingController(text: title),
    minutes: TextEditingController(text: minutes?.toString() ?? ''),
  );

  @override
  void dispose() {
    for (final r in _rows) {
      r.title.dispose();
      r.minutes.dispose();
    }
    super.dispose();
  }

  List<LivePodcastSegment> get _segments => [
    for (final r in _rows)
      if (r.title.text.trim().isNotEmpty)
        LivePodcastSegment(
          title: r.title.text.trim(),
          minutes: switch (int.tryParse(r.minutes.text.trim())) {
            final m? when m >= 1 && m <= 180 => m,
            _ => null,
          },
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: KPodcastSheet.field,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KRadius.md),
        borderSide: BorderSide.none,
      ),
    );
    return Padding(
      key: PodcastSegmentsSheet.sheetKey,
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: KSpacing.md),
            children: [
              LiveWhiteSheetHeader(title: l10n.podcastSegments, centred: true),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          style: text.bodyStrong.copyWith(
                            fontFamily: KFonts.latin,
                            color: KPodcastSheet.soft,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: PodcastSegmentsSheet.titleKey(i),
                          controller: r.title,
                          maxLength: LivePodcastSegment.titleMax,
                          style: text.body.copyWith(color: KPodcastSheet.ink),
                          decoration: field(l10n.podcastSegmentTitleHint),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          key: PodcastSegmentsSheet.minutesKey(i),
                          controller: r.minutes,
                          maxLength: 3,
                          keyboardType: TextInputType.number,
                          style: text.body.copyWith(
                            color: KPodcastSheet.ink,
                            fontFamily: KFonts.latin,
                          ),
                          decoration: field(l10n.podcastSegmentMinutesHint),
                        ),
                      ),
                      IconButton(
                        key: PodcastSegmentsSheet.removeKey(i),
                        tooltip: l10n.podcastSegmentRemove,
                        onPressed: () => setState(() {
                          final row = _rows.removeAt(i);
                          row.title.dispose();
                          row.minutes.dispose();
                        }),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: KPodcastSheet.soft,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_rows.length < LivePodcastSegment.max)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: TextButton.icon(
                      key: PodcastSegmentsSheet.addKey,
                      onPressed: () =>
                          setState(() => _rows.add(_row('', null))),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.podcastSegmentAdd),
                      style: TextButton.styleFrom(
                        foregroundColor: KPodcast.liveTag,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton(
                  key: PodcastSegmentsSheet.saveKey,
                  onPressed: () => Navigator.of(context).pop(_segments),
                  style: FilledButton.styleFrom(
                    backgroundColor: KPodcast.liveTag,
                    foregroundColor: const Color(0xFFFFFFFF),
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(l10n.podcastSegmentsSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keys of the director sheet.
abstract final class PodcastDirectorSheet {
  static Key optionKey(String? userId) =>
      Key('podcast.director.${userId ?? 'auto'}');
  static Key layoutKey(PodcastShotKind kind) =>
      Key('podcast.director.layout.${kind.wire}');
}
