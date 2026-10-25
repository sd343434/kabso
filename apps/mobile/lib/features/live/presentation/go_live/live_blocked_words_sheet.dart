import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys of the blocked words sheet (tests and captures).
abstract final class LiveBlockedWordsKeys {
  static const field = Key('blockedWords.field');
  static const add = Key('blockedWords.add');
  static const count = Key('blockedWords.count');
  static Key remove(String word) => Key('blockedWords.remove.$word');
}

/// The host's blocked words (CP-016 B, ref 71 "Blocked Words"): a field to
/// add a word or short phrase (up to 30 characters), the list with ✕ to
/// remove, n/100. Every change is saved at once (`PUT`); the server masks
/// these words with * in the chat of every live of this host.
Future<void> showLiveBlockedWords(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      barrierColor: const Color(0x00000000),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BlockedWordsSheet(),
    );

class _BlockedWordsSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_BlockedWordsSheet> createState() => _BlockedWordsSheetState();
}

class _BlockedWordsSheetState extends ConsumerState<_BlockedWordsSheet> {
  final _field = TextEditingController();
  bool _saving = false;

  static const _ink = Color(0xFF1C1B1F);
  static const _soft = Color(0xFF7A7B8C);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> words) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(liveBlockedWordsRepositoryProvider).set(words);
      ref.invalidate(liveBlockedWordsProvider);
      await ref.read(liveBlockedWordsProvider.future);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add(List<String> current) async {
    final word = _field.text.trim();
    if (word.isEmpty || _saving) return;
    if (current.any((w) => w.toLowerCase() == word.toLowerCase())) {
      _field.clear();
      return;
    }
    await _save([...current, word]);
    if (mounted) _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final words = ref.watch(liveBlockedWordsProvider);
    final list = words.value ?? const <String>[];
    final full = list.length >= maxLiveBlockedWords;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiveWhiteSheetHeader(
                title: l10n.liveSettingsBlockedWords,
                centred: true,
                titleTop: 15.6,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 10),
                child: Text(
                  l10n.liveBlockedWordsHint,
                  style: text.caption.copyWith(color: _soft, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: LiveBlockedWordsKeys.field,
                        controller: _field,
                        enabled: words.hasValue && !full,
                        maxLength: maxLiveBlockedWordLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp('[\n\r\u2028\u2029]'),
                          ),
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(list),
                        onChanged: (_) => setState(() {}),
                        style: text.body.copyWith(color: _ink),
                        decoration: InputDecoration(
                          hintText: full
                              ? l10n.liveBlockedWordsFull
                              : l10n.liveBlockedWordsAddHint,
                          counterText: '',
                          // A light field on the white sheet (the app's
                          // dark input theme would show a black box).
                          filled: true,
                          fillColor: const Color(0xFFF3F3F3),
                          hintStyle: text.body.copyWith(color: _soft),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF34CAC0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: LiveBlockedWordsKeys.add,
                      onPressed: _saving || full || _field.text.trim().isEmpty
                          ? null
                          : () => _add(list),
                      child: Text(l10n.liveBlockedWordsAdd),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 4),
                child: Text(
                  '${list.length}/$maxLiveBlockedWords',
                  key: LiveBlockedWordsKeys.count,
                  style: text.caption.copyWith(color: _soft),
                ),
              ),
              Expanded(
                child: switch (words) {
                  AsyncData(:final value) when value.isEmpty => Center(
                    child: Text(
                      l10n.liveBlockedWordsEmpty,
                      style: text.body.copyWith(color: _soft),
                    ),
                  ),
                  AsyncData(:final value) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in value)
                          InputChip(
                            label: Text(
                              w,
                              style: text.body.copyWith(color: _ink),
                            ),
                            backgroundColor: const Color(0xFFF3F3F3),
                            side: BorderSide.none,
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              key: LiveBlockedWordsKeys.remove(w),
                              size: 18,
                            ),
                            deleteButtonTooltipMessage: l10n
                                .liveBlockedWordsRemove(w),
                            onDeleted: _saving
                                ? null
                                : () => _save([
                                    for (final x in value)
                                      if (x != w) x,
                                  ]),
                          ),
                      ],
                    ),
                  ),
                  AsyncError(:final error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        failureMessage(l10n, toAppFailure(error)),
                        textAlign: TextAlign.center,
                        style: text.body.copyWith(color: _soft),
                      ),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
