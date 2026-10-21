import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the Create screen (owner's reference, KL-060; values on the
/// Kabso scale, see the reference spec in the PR notes).
abstract final class KCompose {
  static const double inset = KSpacing.lg;
  static const double headerButton = 32;
  static const double publishHeight = 28;
  static const double sparkle = 24;
  static const double photoWidth = 88;
  static const double addWidth = 82;
  static const double stripHeight = 141;
  static const double stripGap = 6;
  static const double cardRadius = KRadius.md;
  static const double badge = 20;
  static const double dot = 5;
  static const double captionMinHeight = 110;
  static const double tool = 28;
  static const double chipHeight = 32;
  static const double rowIcon = 34;
  static const double rowGap = KSpacing.sm;
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
  const new({required this.child, this.size = KCompose.rowIcon, super.key});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.palette.primary.withValues(alpha: 0.09),
      shape: BoxShape.circle,
    ),
    child: IconTheme.merge(
      data: IconThemeData(color: context.palette.primary, size: size * 0.55),
      child: child,
    ),
  );
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
    super.key,
  });

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
    return Material(
      color: p.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KCompose.cardRadius),
        side: BorderSide(color: p.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.sm,
              KSpacing.sm,
              KSpacing.sm,
              KSpacing.sm,
            ),
            child: Row(
              children: [
                ComposeIconDisc(child: icon),
                const SizedBox(width: KSpacing.sm),
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
    );
  }
}

/// A content-type chip ("Photos", "Live", …). Disabled chips are for types
/// without an API yet; they say so instead of pretending to work.
class ComposeTypeChip extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticsHint,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null || selected;
    final fg = selected
        ? p.onPrimary
        : (enabled ? p.textPrimary : p.textTertiary);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      hint: semanticsHint,
      child: Material(
        color: selected ? p.primary : p.surfaceOverlay,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: KSpacing.md,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(color: fg, size: 18),
                      child: icon,
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Text(
                      label,
                      maxLines: 1,
                      style: context.textStyles.label.copyWith(color: fg),
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
                              context.l10n.profileUsername(u.username),
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
