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
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => _ToolsSheet(room: room, other: other),
);

class _ToolsSheet extends StatelessWidget {
  const new({required this.room, required this.other});

  final List<GoLiveTool> room;
  final List<GoLiveTool> other;

  static const ink = Color(0xFF1C1B2E);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = context.textStyles.bodyStrong.copyWith(
      color: ink,
      fontSize: 17,
      fontWeight: FontWeight.w800,
    );
    Widget section(String name, List<GoLiveTool> tools) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(name, style: title),
        ),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.78,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          children: [for (final tool in tools) _ToolTile(tool: tool)],
        ),
      ],
    );
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (room.isNotEmpty) section(l10n.liveToolsRoom, room),
              if (other.isNotEmpty) section(l10n.liveToolsOther, other),
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

  static const circle = Color(0xFFF2F3F7);
  static const on = Color(0xFF6C4CF1);
  static const off = Color(0xFF9A9BAA);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = tool.onTap != null;
    final toggled = tool.toggled;
    final colour = toggled == false ? off : _ToolsSheet.ink;
    final state = switch (toggled) {
      true => l10n.liveToolOn,
      false => l10n.liveToolOff,
      null => null,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      label: tool.label,
      onTap: tool.onTap == null
          ? null
          : () {
              Navigator.of(context).pop();
              tool.onTap!();
            },
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveKeys.tool(tool.id),
        behavior: HitTestBehavior.opaque,
        onTap: tool.onTap == null
            ? null
            : () {
                Navigator.of(context).pop();
                tool.onTap!();
              },
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: circle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tool.icon, size: 26, color: colour),
                  ),
                  if (tool.badge || toggled != null)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: toggled == false
                              ? off
                              : (toggled ?? false)
                              ? const Color(0xFF2FD38A)
                              : const Color(0xFFFF3B6B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFFFFF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tool.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: _ToolsSheet.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state != null)
                Text(
                  state,
                  style: context.textStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: toggled! ? on : off,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice settings while live (D94): noise reduction and enhancement.
Future<void> showLiveVoiceSheet(
  BuildContext context, {
  required bool noiseReduction,
  required bool enhance,
  required Future<void> Function({bool? noiseReduction, bool? enhance})
  onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheet) {
    var noise = noiseReduction;
    var clear = enhance;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(
                l10n.goLiveVoiceSettings,
                style: ink.copyWith(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            SwitchListTile(
              key: const Key('liveVoice.noise'),
              title: Text(l10n.goLiveNoiseReduction, style: ink),
              subtitle: Text(l10n.goLiveNoiseReductionHint, style: hint),
              value: noise,
              onChanged: (v) {
                setState(() => noise = v);
                unawaited(onChanged(noiseReduction: v));
              },
            ),
            SwitchListTile(
              key: const Key('liveVoice.enhance'),
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
