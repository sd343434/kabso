import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the room info sheet (tests and captures).
abstract final class LiveRoomInfoKeys {
  static const sheet = Key('roomInfo.sheet');
  static const editTitle = Key('roomInfo.editTitle');
  static const titleField = Key('roomInfo.titleField');
  static const settings = Key('roomInfo.settings');
  static const tag = Key('roomInfo.tag');
  static const announcement = Key('roomInfo.announcement');
  static const topicField = Key('roomInfo.topicField');
  static const save = Key('roomInfo.save');
  static const boost = Key('roomInfo.boost');
  static Key category(String? slug) => Key('roomInfo.category.${slug ?? '-'}');
}

/// The host's room info while live (owner ref 73): the live cover with
/// Change (CP-015), the title with its pencil, then Room level (no server
/// yet: "Soon"), Room settings, Tag (the category) and Announcement (the
/// topic) — both CP-014 — and Boost my room (CP-014 part C waits for L3,
/// so it is shown disabled). The top fades from mint (#A3EDE8) to white.
Future<void> showLiveRoomInfo(
  BuildContext context, {
  required String hostName,
  required String? hostAvatarUrl,
  required VoidCallback onSettings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => _RoomInfoSheet(
    hostName: hostName,
    hostAvatarUrl: hostAvatarUrl,
    onSettings: () {
      Navigator.of(sheet).pop();
      onSettings();
    },
  ),
);

class _RoomInfoSheet extends ConsumerWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.onSettings,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final VoidCallback onSettings;

  static const _ink = Color(0xFF27292B);
  static const _grey = Color(0xFF888A8F);

  Future<void> _guard(BuildContext context, Future<void> Function() run) async {
    final l10n = context.l10n;
    try {
      await run();
      if (context.mounted) KSnack.success(context, l10n.liveEditRoomSaved);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final room = ref.watch(liveHostControllerProvider.select((s) => s.room));
    final host = ref.read(liveHostControllerProvider.notifier);
    final title = room?.title ?? '';
    final live = room != null;
    Widget divider() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.5),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
    );
    return Container(
      key: LiveRoomInfoKeys.sheet,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.22, 0.38],
          colors: [Color(0xFFA3EDE8), Color(0xFFE9FBFA), Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Center(
              child: Container(
                width: 25,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveCoverPicture(
                    hostName: hostName,
                    hostAvatarUrl: hostAvatarUrl,
                    enabled: live,
                    size: 69.4,
                    radius: 11.6,
                    label: l10n.liveRoomInfoChange,
                    labelSize: 13,
                    labelBottom: 3,
                  ),
                  const SizedBox(width: 17.8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.title.copyWith(
                                color: const Color(0xFF242928),
                                fontSize: 19.5,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            key: LiveRoomInfoKeys.editTitle,
                            tooltip: l10n.liveEditRoomName,
                            visualDensity: VisualDensity.compact,
                            onPressed: live
                                ? () => _editText(
                                    context,
                                    label: l10n.liveEditRoomName,
                                    initial: title,
                                    maxLength: GoLiveTitleCard.titleMaxLength,
                                    fieldKey: LiveRoomInfoKeys.titleField,
                                    allowEmpty: false,
                                    onSave: (v) => _guard(
                                      context,
                                      () => host.editInfo(title: v),
                                    ),
                                  )
                                : null,
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF9AA0A6),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // CP-016 D (D101): the host's charm level; "Soon" while the
            // charm levels are unavailable.
            _InfoRow(
              label: l10n.liveRoomLevel,
              trailing: switch (room?.roomLevel) {
                final level? => CharmLevelBadge(level: level, height: 18),
                null => null,
              },
            ),
            const SizedBox(height: 4),
            divider(),
            const SizedBox(height: 9),
            _InfoRow(
              key: LiveRoomInfoKeys.settings,
              label: l10n.liveRoomSettings,
              height: 44,
              onTap: onSettings,
            ),
            _InfoRow(
              key: LiveRoomInfoKeys.tag,
              label: l10n.liveRoomTag,
              height: 44,
              value: room?.category?.name ?? l10n.liveRoomNoTag,
              onTap: live
                  ? () => _pickCategory(
                      context,
                      ref,
                      selected: room.category?.slug,
                      onPick: (slug) => _guard(
                        context,
                        () => host.editInfo(categorySlug: slug),
                      ),
                    )
                  : null,
            ),
            _InfoRow(
              key: LiveRoomInfoKeys.announcement,
              label: l10n.liveRoomAnnouncement,
              height: 44,
              value: room?.topic,
              onTap: live
                  ? () => _editText(
                      context,
                      label: l10n.liveRoomAnnouncement,
                      hint: l10n.liveEditRoomTopicHint,
                      initial: room.topic ?? '',
                      maxLength: 100,
                      fieldKey: LiveRoomInfoKeys.topicField,
                      allowEmpty: true,
                      onSave: (v) => _guard(
                        context,
                        () => host.editInfo(topic: v.isEmpty ? null : v),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 7.5),
            divider(),
            const SizedBox(height: 10),
            // CP-014 part C (boost) waits for L3: shown, never pretending.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Semantics(
                button: true,
                enabled: false,
                label: '${l10n.liveRoomBoost}, ${l10n.liveSoon}',
                excludeSemantics: true,
                child: Opacity(
                  key: LiveRoomInfoKeys.boost,
                  opacity: 0.45,
                  child: Container(
                    height: 51.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25.6),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFECA67), Color(0xFFFEA254)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFFFFFFF),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${l10n.liveRoomBoost} · ${l10n.liveSoon}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.title.copyWith(
                              color: const Color(0xFFFFFFFF),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref, {
    required String? selected,
    required Future<void> Function(String? slug) onPick,
  }) async {
    final l10n = context.l10n;
    List<LiveCategory> categories;
    try {
      categories = await ref.read(liveCategoriesProvider.future);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
      return;
    }
    if (!context.mounted) return;
    const noTag = '\u0000';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) {
        Widget option(String? slug, String name) => ListTile(
          key: LiveRoomInfoKeys.category(slug),
          leading: slug == null
              ? const Icon(Icons.block_rounded, color: _grey)
              : SizedBox.square(
                  dimension: 28,
                  child: switch (categoryArt(slug)) {
                    final art? => Image.asset(art),
                    null => Icon(categoryIcon(slug), color: _ink),
                  },
                ),
          title: Text(
            name,
            style: sheet.textStyles.body.copyWith(color: _ink, fontSize: 16),
          ),
          trailing: slug == selected
              ? const Icon(Icons.check_rounded, color: Color(0xFF34CAC0))
              : null,
          onTap: () => Navigator.of(sheet).pop(slug ?? noTag),
        );
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiveWhiteSheetHeader(title: l10n.liveRoomTag, centred: true),
                for (final c in categories) option(c.slug, c.name),
                option(null, l10n.liveRoomNoTag),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final slug = picked == noTag ? null : picked;
    if (slug == selected) return;
    await onPick(slug);
  }

  Future<void> _editText(
    BuildContext context, {
    required String label,
    required String initial,
    required int maxLength,
    required Key fieldKey,
    required bool allowEmpty,
    required Future<void> Function(String value) onSave,
    String? hint,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(
        label: label,
        initial: initial,
        maxLength: maxLength,
        fieldKey: fieldKey,
        allowEmpty: allowEmpty,
        hint: hint,
      ),
    );
    if (value == null || value == initial.trim() || !context.mounted) return;
    unawaited(onSave(value));
  }
}

/// One line of text (the title or the announcement), at most [maxLength].
class _TextEditDialog extends StatefulWidget {
  const new({
    required this.label,
    required this.initial,
    required this.maxLength,
    required this.fieldKey,
    required this.allowEmpty,
    this.hint,
  });

  final String label;
  final String initial;
  final int maxLength;
  final Key fieldKey;
  final bool allowEmpty;
  final String? hint;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final v = _controller.text.trim();
    final ok = widget.allowEmpty || v.isNotEmpty;
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp('[\n\r\u2028\u2029]')),
        ],
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          key: LiveRoomInfoKeys.save,
          onPressed: ok
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(l10n.liveEditRoomSave),
        ),
      ],
    );
  }
}

/// A row of the info sheet: label 16.5 pt (#27292B), an optional value in
/// grey, a chevron; without [onTap] it has no server yet ("Soon").
class _InfoRow extends StatelessWidget {
  const new({
    required this.label,
    super.key,
    this.onTap,
    this.value,
    this.trailing,
    this.height = 52,
  });

  final String label;
  final String? value;

  /// Shown at the end instead of [value]; the row is then information, not
  /// "Soon", even without [onTap].
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final trailing = this.trailing;
    final soon = onTap == null && trailing == null;
    final value = soon ? l10n.liveSoon : this.value;
    return Semantics(
      button: !soon,
      enabled: !soon,
      label: [label, ?value].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20.5, 0, 16, 0),
            child: Row(
              children: [
                Text(
                  label,
                  style: text.title.copyWith(
                    color: soon ? const Color(0xFFB4B6BB) : _RoomInfoSheet._ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                if (trailing != null) ...[const Spacer(), trailing],
                if (trailing == null)
                  Expanded(
                    child: Text(
                      value ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: text.body.copyWith(
                        color: soon
                            ? const Color(0xFFB4B6BB)
                            : const Color(0xFF888A8D),
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: _RoomInfoSheet._grey,
                    size: 26,
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
