import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D253 (owner: the host's screen «مثل التصميم ١٠٠٪», ref 2026-11-03,
/// 393 × 852 pt): the host's chat lines as the reference draws them — a
/// translucent black box hugging each line (D234's 44 %, 12 pt corners;
/// the second reference shows it over a bright picture), white bold text
/// with a shadow, one flowing line per message:
/// the role tag (the host's orange «المضيف»), the name (teal), the charm
/// badge, «:» and the text, wrapping under the start.
abstract final class KFlatChat {
  /// Ref: 14.5 pt lines of ≈ 13.5 pt bold text.
  static const double textSize = 13.5;
  static const double lineHeight = 1.07;

  /// Ref: the boxes 3 pt apart, the text 4 pt inside them.
  static const double gap = 3;
  static const EdgeInsetsDirectional padding = EdgeInsetsDirectional.fromSTEB(
    10,
    4,
    12,
    4,
  );
  static const Color box = Color(0x70000000);
  static const double radius = 12;

  /// The box around a line.
  static Widget boxed(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: box,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );

  /// Ref: the name `#A4E8E0`.
  static const Color name = Color(0xFFA4E8E0);

  /// Ref: the host tag `#FC7800`, 15 pt tall, white bold text.
  static const Color hostTag = Color(0xFFFC7800);
  static const double tagHeight = 15;

  static const Color moderatorTag = Color(0xFFFFB13B);

  /// The text stays readable over a bright picture.
  static const List<Shadow> shadow = [
    Shadow(color: Color(0x99000000), blurRadius: 3),
    Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 1),
  ];

  static TextStyle style(BuildContext context) =>
      context.textStyles.body.copyWith(
        fontSize: textSize,
        height: lineHeight,
        color: const Color(0xFFFFFFFF),
        fontWeight: FontWeight.w700,
        shadows: shadow,
      );
}

/// D253: one message of the host's flat chat.
class LiveChatFlatLine extends StatelessWidget {
  const new({
    required this.name,
    required this.text,
    required this.label,
    super.key,
    this.role,
    this.charmLevel,
    this.failed,
    this.onProfile,
    this.onActions,
  });

  final String name;
  final String text;
  final String label;
  final LiveChatRole? role;
  final int? charmLevel;

  /// Why a pending line failed (under it).
  final String? failed;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;

  static const tagKey = Key('liveChat.flat.tag');
  static const nameKey = Key('liveChat.flat.name');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = KFlatChat.style(context);
    final tag = switch (role) {
      LiveChatRole.host => l10n.liveChatHostBadge,
      LiveChatRole.moderator => l10n.liveChatModeratorBadge,
      _ => null,
    };
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActions,
        onLongPress: onActions,
        child: KFlatChat.boxed(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    if (tag != null) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          key: tagKey,
                          height: KFlatChat.tagHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: role == LiveChatRole.host
                                ? KFlatChat.hostTag
                                : KFlatChat.moderatorTag,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              tag,
                              textScaler: TextScaler.noScaling,
                              style: base.copyWith(
                                fontSize: 9.5,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                shadows: const [],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' '),
                    ],
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        key: nameKey,
                        onTap: onProfile,
                        child: Text(
                          name,
                          textScaler: scaler,
                          style: base.copyWith(color: KFlatChat.name),
                        ),
                      ),
                    ),
                    if (charmLevel case final level?) ...[
                      const TextSpan(text: ' '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: IntrinsicWidth(
                          child: CharmLevelBadge(
                            level: level,
                            height: CharmLevelBadge.lineHeight,
                          ),
                        ),
                      ),
                    ],
                    TextSpan(text: ': $text'),
                  ],
                ),
                textScaler: scaler,
              ),
              if (failed case final why?)
                Text(
                  why,
                  textScaler: scaler,
                  style: base.copyWith(
                    fontSize: 11,
                    color: const Color(0xFFFF8A9A),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D253: the rules line of the flat chat — white bold text in the same
/// box, no shield (ref).
class LiveChatFlatNotice extends StatelessWidget {
  const new({required this.text, required this.label, super.key});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label. $text',
    excludeSemantics: true,
    child: Text(
      text,
      textScaler: MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
      style: KFlatChat.style(context),
    ),
  );
}
