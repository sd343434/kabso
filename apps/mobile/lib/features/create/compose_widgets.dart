import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the Create flow (owner's references, KL-060; values on the
/// Kabso scale, see the reference spec in the PR notes).
abstract final class KCompose {
  /// D168: a library video over the limit is shown faded.
  static const double tooLongOpacity = 0.45;

  /// Media step page inset; the details step is a little tighter.
  static const double mediaInset = 20;
  static const double inset = KSpacing.md;
  static const double headerButton = 36;
  static const double pillHeight = 36;
  static const double photoWidth = 70;
  static const double addWidth = 64;
  static const double stripHeight = 112;
  static const double stripGap = 6;
  static const double cardRadius = KRadius.md;
  static const double panelRadius = 16;
  static const double badge = 20;
  static const double numberBadge = 18;
  static const double dot = 5;
  static const double captionMinHeight = 120;
  static const double tool = 32;
  static const double rowIcon = 36;
  static const double rowGap = KSpacing.sm;
  static const double segmentHeight = 44;
  static const double gridGap = 10;
  static const double trayThumb = 46;
  static const double step = 22;
}

/// The white card of the details step (caption box, option rows).
BoxDecoration composeCard(KPalette p, {Color? border}) => BoxDecoration(
  color: p.surfaceRaised,
  borderRadius: BorderRadius.circular(KCompose.panelRadius),
  border: Border.all(color: border ?? p.border.withValues(alpha: 0.5)),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3)),
  ],
);

/// The header of both steps: the red action pill at the start, the title
/// and its line centred, and a round button at the end (Close or Back).
class ComposeHeader extends StatelessWidget {
  const new({
    required this.action,
    required this.subtitle,
    required this.endButton,
    super.key,
  });

  final Widget action;
  final String subtitle;
  final Widget endButton;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KCompose.inset + 4,
        vertical: KSpacing.sm,
      ),
      // The title is centred on the screen: both sides take the same
      // width, and the middle at most half of it.
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(fit: BoxFit.scaleDown, child: action),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.createTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: endButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The red action pill of the header (Next, Share): label then glyph.
class ComposeActionPill extends StatelessWidget {
  const new({
    required this.label,
    required this.glyph,
    required this.enabled,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final String label;
  final Widget glyph;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Material(
        color: enabled || busy ? p.primary : p.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: KCompose.pillHeight,
              minWidth: 72,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: context.textStyles.label.copyWith(
                      color: p.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  if (busy)
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onPrimary,
                      ),
                    )
                  else
                    IconTheme.merge(
                      data: IconThemeData(color: p.onPrimary, size: 18),
                      child: glyph,
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

/// The round end button of the header (Close, Back).
class ComposeRoundButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.raised = false,
    super.key,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  /// White with a shadow (Back) instead of the grey square (Close).
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: raised ? BoxShape.circle : BoxShape.rectangle,
        boxShadow: raised
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(
          width: KCompose.headerButton,
          height: KCompose.headerButton,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: raised ? p.surfaceRaised : p.surfaceOverlay,
          shape: raised
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadius.md),
                ),
        ),
        icon: IconTheme.merge(
          data: IconThemeData(color: p.textPrimary, size: KMetrics.iconMd),
          child: icon,
        ),
      ),
    );
  }
}

/// Hashtags and mentions in the caption are drawn in the brand colour (the
/// server links them, §11.6).
class CaptionController extends TextEditingController {
  new({super.text});

  static final RegExp entityPattern = RegExp(
    r'(?<![\p{L}\p{N}_])[#@][\p{L}\p{M}\p{N}_.]+',
    unicode: true,
  );

  /// Set by the screen from the theme.
  Color entityColor = const Color(0xFFC8080F);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final source = text;
    final children = <InlineSpan>[];
    var last = 0;
    for (final m in entityPattern.allMatches(source)) {
      if (m.start > last) {
        children.add(TextSpan(text: source.substring(last, m.start)));
      }
      children.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(color: entityColor, fontWeight: FontWeight.w600),
        ),
      );
      last = m.end;
    }
    if (last < source.length) {
      children.add(TextSpan(text: source.substring(last)));
    }
    return TextSpan(style: style, children: children);
  }

  /// Inserts [insert] at the cursor (or the end), with a space before it
  /// when needed.
  void insertAtCursor(String insert) {
    final sel = selection;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final before = text.substring(0, at);
    final pad = before.isEmpty || before.endsWith(' ') || before.endsWith('\n')
        ? ''
        : ' ';
    final next = '$before$pad$insert${text.substring(end)}';
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: at + pad.length + insert.length,
      ),
    );
  }

  /// The distinct hashtags of the caption (without `#`), in order.
  List<String> get hashtags => [
    ...{
      for (final m in entityPattern.allMatches(text))
        if (m.group(0)!.startsWith('#') && m.group(0)!.length > 1)
          m.group(0)!.substring(1),
    },
  ];
}

/// A pink-tinted disc with a brand-coloured glyph (header sparkle, option
/// row icons).
class ComposeIconDisc extends StatelessWidget {
  const new({
    required this.child,
    this.size = KCompose.rowIcon,
    this.neutral = false,
    super.key,
  });

  final Widget child;
  final double size;

  /// Grey disc with a dark glyph (secondary rows such as "More options").
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: neutral ? p.surfaceOverlay : p.primary.withValues(alpha: 0.09),
        shape: BoxShape.circle,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: neutral ? p.textPrimary : p.primary,
          size: size * 0.55,
        ),
        child: child,
      ),
    );
  }
}

/// One option row: icon disc, title, subtitle (or [body]), optional
/// [trailing] action, and the chevron at the reading end.
class ComposeOptionRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.body,
    this.trailing,
    this.neutralIcon = false,
    super.key,
  });

  final bool neutralIcon;
  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? body;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final card = composeCard(p);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: card.borderRadius,
        boxShadow: card.boxShadow,
      ),
      child: Material(
        color: p.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KCompose.panelRadius),
          side: BorderSide(color: p.border.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                KSpacing.md,
                KSpacing.sm + 2,
                KSpacing.sm,
                KSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  ComposeIconDisc(neutral: neutralIcon, child: icon),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                        if (subtitle case final s?)
                          Text(
                            s,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: p.textTertiary),
                          ),
                        if (body case final b?)
                          Padding(
                            padding: const EdgeInsets.only(top: KSpacing.xs),
                            child: b,
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                  // Mirrors itself in RTL (matchTextDirection).
                  Icon(Icons.chevron_right_rounded, color: p.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle with a dashed border (the "add more" tile).
class DashedBorderPainter extends CustomPainter {
  const new({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.5);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// Common emoji for the caption (Unicode; the Kabi stickers are a chat
/// feature).
const List<String> captionEmoji = [
  '😀',
  '😂',
  '🥹',
  '😍',
  '🥰',
  '😎',
  '🤩',
  '😊',
  '😇',
  '🤔',
  '😴',
  '😢',
  '😡',
  '👏',
  '🙌',
  '🙏',
  '👍',
  '💪',
  '❤️',
  '🔥',
  '✨',
  '🎉',
  '🌅',
  '🌄',
  '🌙',
  '⭐',
  '☀️',
  '🌸',
  '🌴',
  '🌊',
  '⛰️',
  '🏜️',
  '🕌',
  '☕',
  '🍽️',
  '🎶',
  '📸',
  '✈️',
  '🚗',
  '🇯🇴',
];

/// Picks one emoji; null when dismissed.
Future<String?> showCaptionEmojiSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          padding: const EdgeInsets.all(KSpacing.md),
          children: [
            for (final e in captionEmoji)
              InkWell(
                key: ValueKey('create.emoji.$e'),
                borderRadius: BorderRadius.circular(KRadius.sm),
                onTap: () => Navigator.of(sheet).pop(e),
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ),
    );

/// Searches people to mention (`GET /search?type=users`) and returns the
/// chosen one; null when dismissed.
Future<UserSummary?> showMentionSheet(BuildContext context) =>
    showModalBottomSheet<UserSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: const _MentionSearch(),
      ),
    );

class _MentionSearch extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MentionSearch> createState() => _MentionSearchState();
}

class _MentionSearchState extends ConsumerState<_MentionSearch> {
  Timer? _debounce;
  String _query = '';
  Future<List<UserSummary>>? _results;

  void _changed(String raw) {
    final q = raw.trim().replaceFirst(RegExp('^@'), '');
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: TextField(
                key: const Key('create.mention.query'),
                autofocus: true,
                onChanged: _changed,
                decoration: InputDecoration(
                  hintText: l10n.createMentionSearchHint,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
            ),
            Expanded(
              child: switch (_results) {
                null => Center(
                  child: Text(
                    l10n.createMentionStart,
                    style: context.textStyles.caption.copyWith(
                      color: p.textTertiary,
                    ),
                  ),
                ),
                final future => FutureBuilder<List<UserSummary>>(
                  key: ValueKey(_query),
                  future: future,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text(l10n.createMentionFailed));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final people = snap.data!;
                    if (people.isEmpty) {
                      return Center(child: Text(l10n.createMentionNone));
                    }
                    return ListView(
                      children: [
                        for (final u in people)
                          ListTile(
                            key: ValueKey('create.mention.${u.username}'),
                            leading: KAvatar(
                              name: u.displayName,
                              imageUrl: u.avatarUrl,
                              size: KSizes.avatarSm,
                            ),
                            title: Text(u.displayName),
                            subtitle: Text(
                              KHandle.text(
                                context.l10n,
                                u.username,
                                premiumTier: u.premiumTier,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(u),
                          ),
                      ],
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the place (free text ≤ 80); returns the new value (empty clears),
/// null when dismissed.
Future<String?> showPlaceSheet(BuildContext context, String current) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlaceSheet(current: current),
    );

/// Owns its text controller, so it outlives the sheet's closing animation.
class _PlaceSheet extends StatefulWidget {
  const new({required this.current});

  final String current;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpacing.md,
        0,
        KSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + KSpacing.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('create.place.field'),
              controller: _controller,
              autofocus: true,
              maxLength: maxLocationText,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: l10n.createLocationHint,
                prefixIcon: const AppIcon(AppIcons.location),
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: const Key('create.place.save'),
              label: l10n.createPlaceSave,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Advanced settings: comments on/off, who can comment, hide the like
/// count. Returns the new settings, null when dismissed.
Future<PostSettingsDraft?> showAdvancedSheet(
  BuildContext context,
  PostSettingsDraft current,
) => showModalBottomSheet<PostSettingsDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) {
    var draft = current;
    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final who = draft.whoCanComment ?? WhoCanComment.everyone;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                key: const Key('create.advanced.comments'),
                title: Text(l10n.createCommentsOn),
                value: draft.commentsEnabled,
                onChanged: (v) =>
                    setState(() => draft = draft.copyWith(commentsEnabled: v)),
              ),
              RadioGroup<WhoCanComment>(
                groupValue: who,
                onChanged: (v) {
                  if (v != null && draft.commentsEnabled) {
                    setState(() => draft = draft.copyWith(whoCanComment: v));
                  }
                },
                child: Column(
                  children: [
                    for (final (w, label) in [
                      (WhoCanComment.everyone, l10n.createWhoEveryone),
                      (WhoCanComment.followers, l10n.createWhoFollowers),
                      (WhoCanComment.nobody, l10n.createWhoNobody),
                    ])
                      RadioListTile<WhoCanComment>(
                        key: ValueKey('create.advanced.who.${w.name}'),
                        value: w,
                        enabled: draft.commentsEnabled,
                        title: Text(label),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                key: const Key('create.advanced.hideLikes'),
                title: Text(l10n.createHideLikes),
                value: draft.hideLikeCount,
                onChanged: (v) =>
                    setState(() => draft = draft.copyWith(hideLikeCount: v)),
              ),
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KButton(
                  key: const Key('create.advanced.save'),
                  label: l10n.createPlaceSave,
                  onPressed: () => Navigator.of(context).pop(draft),
                ),
              ),
            ],
          ),
        );
      },
    );
  },
);

/// [at] as the schedule shows it: date and time in the app's locale.
String scheduleLabel(BuildContext context, DateTime at) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  return context.l10n.createScheduleAt(
    KFormat.date(at, tag),
    KFormat.time(at, tag),
  );
}

/// Picks when a post publishes: a day within 30 days, then a time. A time
/// outside 5 minutes to 30 days ahead says so and returns `null`.
Future<DateTime?> pickScheduleTime(
  BuildContext context,
  DateTime? current,
) async {
  final l10n = context.l10n;
  final now = clock.now();
  final first = current ?? now.add(const Duration(hours: 1));
  final day = await showDatePicker(
    context: context,
    initialDate: first,
    firstDate: now,
    lastDate: now.add(maxScheduleLead),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(first),
  );
  if (time == null || !context.mounted) return null;
  final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  if (!isSchedulable(at, clock.now())) {
    KSnack.error(context, l10n.createScheduleWindow);
    return null;
  }
  return at;
}

/// A selected photo as a small card shows it: decoded near the size it is
/// drawn at instead of its full 2160 px (a dozen full-size decodes made the
/// strip and the tray stutter on phones). [extent] is the card's larger
/// side; twice it keeps `BoxFit.cover` sharp for ratios up to 2:1.
ImageProvider composeThumb(
  BuildContext context,
  Uint8List bytes,
  double extent,
) {
  final px = (extent * 2 * MediaQuery.devicePixelRatioOf(context)).round();
  return ResizeImage(
    MemoryImage(bytes),
    width: px,
    height: px,
    policy: ResizeImagePolicy.fit,
  );
}

/// Opens the selected photos full screen at [initial]: swipe between them
/// (in the reading direction), see "2/5" and the dots, remove the one shown.
/// Returns the index shown when it closes (null when no photo is left).
Future<int?> showComposePhotoPreview(BuildContext context, int initial) =>
    Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposePhotoPreview(initial: initial),
      ),
    );

/// The full-screen preview of the draft's photos (both Create steps): a
/// pager over the photos in post order, Close at the start, the counter in
/// the middle and Remove at the end, the dots at the bottom.
class ComposePhotoPreview extends ConsumerStatefulWidget {
  const new({required this.initial, super.key});

  final int initial;

  static const pagerKey = Key('create.preview.pager');
  static const counterKey = Key('create.preview.counter');
  static const closeKey = Key('create.preview.close');
  static const removeKey = Key('create.preview.remove');

  @override
  ConsumerState<ComposePhotoPreview> createState() =>
      _ComposePhotoPreviewState();
}

class _ComposePhotoPreviewState extends ConsumerState<ComposePhotoPreview> {
  late int _page = widget.initial;
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_page);

  void _remove(List<ComposePhoto> photos) {
    if (photos.isEmpty) return;
    final page = _page.clamp(0, photos.length - 1);
    ref
        .read(composeControllerProvider.notifier)
        .removePhoto(photos[page].localId);
    if (photos.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    // The next photo slides in; removing the last shows the one before.
    final next = page.clamp(0, photos.length - 2);
    setState(() => _page = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(composeControllerProvider);
    final photos = draft.photos;
    final count = photos.length;
    final page = count == 0 ? 0 : _page.clamp(0, count - 1);
    const fg = Colors.white;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              container: true,
              label: count == 0 ? null : l10n.createPhotoLabel(page + 1, count),
              child: PageView.builder(
                key: ComposePhotoPreview.pagerKey,
                controller: _pages,
                itemCount: count,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Image(
                  image: ResizeImage(
                    MemoryImage(photos[i].bytes),
                    width: (width * dpr).round(),
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.sm),
                  child: Row(
                    children: [
                      IconButton(
                        key: ComposePhotoPreview.closeKey,
                        tooltip: l10n.createClose,
                        onPressed: _close,
                        icon: const AppIcon(AppIcons.close, color: fg),
                      ),
                      Expanded(
                        child: Text(
                          count == 0
                              ? ''
                              : '${l10n.createPhotoNumber(page + 1)}/'
                                    '${l10n.createPhotoNumber(count)}',
                          key: ComposePhotoPreview.counterKey,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: context.textStyles.bodyStrong.copyWith(
                            color: fg,
                          ),
                        ),
                      ),
                      IconButton(
                        key: ComposePhotoPreview.removeKey,
                        tooltip: l10n.createRemovePhoto,
                        onPressed: draft.busy ? null : () => _remove(photos),
                        icon: const Icon(Icons.delete_outline, color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (count > 1)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.lg),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < count; i++)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == page
                                    ? context.palette.primary
                                    : fg.withValues(alpha: 0.45),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
