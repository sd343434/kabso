import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The host's room tools (owner's reference): a white sheet with the
/// room's tools and the other tools as round icons in a grid. Only tools
/// that work are listed; on/off tools show their state.
Future<void> showLiveRoomTools(
  BuildContext context, {
  required List<GoLiveTool> room,
  required List<GoLiveTool> other,
  String? roomTitle,
  String? otherTitle,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  // The reference leaves the room undimmed behind the sheet.
  barrierColor: const Color(0x00000000),
  builder: (sheet) => _ToolsSheet(
    room: room,
    other: other,
    roomTitle: roomTitle,
    otherTitle: otherTitle,
  ),
);

/// D131: one titled grid of tools in the same white sheet (the host's
/// Beautification tools).
Future<void> showLiveToolGrid(
  BuildContext context, {
  required String title,
  required List<GoLiveTool> tools,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  barrierColor: const Color(0x00000000),
  builder: (sheet) =>
      _ToolsSheet(room: tools, other: const [], roomTitle: title),
);

class _ToolsSheet extends StatelessWidget {
  const new({
    required this.room,
    required this.other,
    this.roomTitle,
    this.otherTitle,
  });

  final List<GoLiveTool> room;
  final List<GoLiveTool> other;

  /// The first section's title (default "Room tools").
  final String? roomTitle;

  /// D173: the second section's title (default "Other tools").
  final String? otherTitle;

  static const ink = Color(0xFF1C1B2E);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Measured on the owner's reference (430 pt wide): titles at 16 pt from
    // the edge, five 83-pt columns, 87-pt rows; a title's caps 24.7 pt above
    // the circles, the next title's caps 3.7 pt below the last row.
    final title = context.textStyles.bodyStrong.copyWith(
      color: const Color(0xFF313131),
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w800,
    );
    Widget section(String name, List<GoLiveTool> tools, {bool first = true}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                16,
                first ? 14 : 0.5,
                16,
                0,
              ),
              child: Text(name, style: title),
            ),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 82.9 / 87.1,
              padding: const EdgeInsets.fromLTRB(7.75, 12, 7.75, 0),
              children: [for (final tool in tools) _ToolTile(tool: tool)],
            ),
          ],
        );
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (room.isNotEmpty)
                section(roomTitle ?? l10n.liveToolsRoom, room),
              if (other.isNotEmpty)
                section(
                  otherTitle ?? l10n.liveToolsOther,
                  other,
                  first: room.isEmpty,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const new({required this.tool});

  final GoLiveTool tool;

  static const circle = Color(0xFFF5F7FB);
  static const glyph = Color(0xFF2D2F33);
  static const off = Color(0xFF9A9BAA);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = tool.onTap != null;
    final toggled = tool.toggled;
    void tap() {
      Navigator.of(context).pop();
      tool.onTap!();
    }

    // On/off tools say their state to screen readers; on screen the icon
    // changes (e.g. chat / chat off), as in the reference (no extra text).
    final label = switch (toggled) {
      _ when tool.soon => '${tool.label}, ${l10n.liveSoon}',
      true => '${tool.label}, ${l10n.liveToolOn}',
      false => '${tool.label}, ${l10n.liveToolOff}',
      null => tool.label,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      label: label,
      onTap: enabled ? tap : null,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveKeys.tool(tool.id),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? tap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: const BoxDecoration(
                      color: circle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tool.icon,
                      size: 24,
                      color: toggled == false ? off : glyph,
                    ),
                  ),
                  if (tool.soon)
                    PositionedDirectional(
                      top: -6,
                      end: -16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EAF0),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                        ),
                        child: Text(
                          l10n.liveSoon,
                          style: context.textStyles.caption.copyWith(
                            color: const Color(0xFF5A5B6A),
                            fontSize: 8,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (tool.badge)
                    const PositionedDirectional(
                      top: -1,
                      end: -3,
                      child: SizedBox.square(
                        dimension: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFFF3B6B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1.9),
              // One word never breaks inside: it shrinks to fit (narrow
              // screens); longer labels take two lines.
              if (!tool.label.contains(' '))
                FittedBox(fit: BoxFit.scaleDown, child: _label(context))
              else
                // D173: a large text scale on a narrow phone never overflows
                // the tile (the second line is cut at the tile's edge).
                Flexible(child: _label(context)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _ToolTile {
  Widget _label(BuildContext context) => Text(
    tool.label,
    maxLines: 2,
    textAlign: TextAlign.center,
    overflow: TextOverflow.ellipsis,
    style: context.textStyles.caption.copyWith(
      color: const Color(0xFF000000),
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Voice settings while live (D94): noise reduction and enhancement.
Future<void> showLiveVoiceSheet(
  BuildContext context, {
  required bool noiseReduction,
  required bool enhance,
  required Future<void> Function({bool? noiseReduction, bool? enhance})
  onChanged,
  // Before going live the sheet also holds the microphone switch.
  bool? micEnabled,
  VoidCallback? onMic,
  Key? micKey,
  Key? noiseKey,
  Key? enhanceKey,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheet) {
    var noise = noiseReduction;
    var clear = enhance;
    var mic = micEnabled;
    final l10n = sheet.l10n;
    final ink = sheet.textStyles.body.copyWith(color: _ToolsSheet.ink);
    final hint = sheet.textStyles.caption.copyWith(
      color: const Color(0xFF7A7B8C),
    );
    return StatefulBuilder(
      builder: (context, setState) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The mixer sheet's header (owner ref 69).
            LiveWhiteSheetHeader(
              title: l10n.goLiveVoiceSettings,
              centred: true,
            ),
            if (mic case final on?)
              SwitchListTile(
                key: micKey ?? const Key('liveVoice.mic'),
                title: Text(l10n.goLiveMicrophone, style: ink),
                subtitle: Text(l10n.goLiveMicrophoneHint, style: hint),
                value: on,
                onChanged: onMic == null
                    ? null
                    : (v) {
                        setState(() => mic = v);
                        onMic();
                      },
              ),
            SwitchListTile(
              key: noiseKey ?? const Key('liveVoice.noise'),
              title: Text(l10n.goLiveNoiseReduction, style: ink),
              subtitle: Text(l10n.goLiveNoiseReductionHint, style: hint),
              value: noise,
              onChanged: (v) {
                setState(() => noise = v);
                unawaited(onChanged(noiseReduction: v));
              },
            ),
            SwitchListTile(
              key: enhanceKey ?? const Key('liveVoice.enhance'),
              title: Text(l10n.goLiveVoiceEnhance, style: ink),
              subtitle: Text(l10n.goLiveVoiceEnhanceHint, style: hint),
              value: clear,
              onChanged: (v) {
                setState(() => clear = v);
                unawaited(onChanged(enhance: v));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);
