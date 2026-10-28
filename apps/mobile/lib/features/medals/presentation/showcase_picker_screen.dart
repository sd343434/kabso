import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/application/medals_providers.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/medals/showcase` (CP-018, owner D106 amendment): choose up to
/// [maxShowcaseMedals] earned medals to show on your profile, in order.
/// Tapping an earned medal adds it at the end (or takes it out); the chosen
/// row on top shows the order. Save sends `PUT /me/medals/showcase`.
class ShowcasePickerScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final catalogue = ref.watch(medalCatalogueProvider);
    final showcase = ref.watch(myShowcaseProvider);
    return switch ((catalogue, showcase)) {
      (AsyncValue(value: final c?), AsyncValue(value: final s?)) =>
        ShowcasePicker(
          medals: [
            for (final m in c.data)
              if (m.unlocked) m,
          ],
          initial: [for (final m in s) m.code],
        ),
      (AsyncValue(:final error?, isLoading: false), _) ||
      (_, AsyncValue(:final error?, isLoading: false)) => Scaffold(
        appBar: KAppBar(title: Text(l10n.medalsShowcaseTitle)),
        body: FailureErrorState(
          title: l10n.medalsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref
            ..invalidate(medalCatalogueProvider)
            ..invalidate(myShowcaseProvider),
        ),
      ),
      _ => Scaffold(
        appBar: KAppBar(title: Text(l10n.medalsShowcaseTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// The picker over loaded [medals] (earned only) and the saved order
/// [initial].
class ShowcasePicker extends ConsumerStatefulWidget {
  const new({required this.medals, required this.initial, super.key});

  final List<Medal> medals;
  final List<String> initial;

  static const saveKey = Key('medals.showcase.save');
  static const chosenKey = Key('medals.showcase.chosen');

  static Key optionKey(String code) => Key('medals.showcase.option.$code');
  static Key chosenItemKey(String code) => Key('medals.showcase.chosen.$code');

  @override
  ConsumerState<ShowcasePicker> createState() => _ShowcasePickerState();
}

class _ShowcasePickerState extends ConsumerState<ShowcasePicker> {
  late final List<String> _chosen = [
    for (final code in widget.initial)
      if (widget.medals.any((m) => m.code == code)) code,
  ];
  bool _saving = false;

  /// Saved: leaving needs no question.
  bool _saved = false;

  bool get _changed {
    if (_chosen.length != widget.initial.length) return true;
    for (var i = 0; i < _chosen.length; i++) {
      if (_chosen[i] != widget.initial[i]) return true;
    }
    return false;
  }

  void _toggle(String code) {
    final l10n = context.l10n;
    setState(() {
      if (_chosen.contains(code)) {
        _chosen.remove(code);
      } else if (_chosen.length >= maxShowcaseMedals) {
        KSnack.info(context, l10n.medalsShowcaseLimit(maxShowcaseMedals));
      } else {
        _chosen.add(code);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(medalsRepositoryProvider).setShowcase(List.of(_chosen));
      if (!mounted) return;
      ref
        ..invalidate(myShowcaseProvider)
        ..invalidate(profileStatsProvider)
        ..invalidate(publicProfileProvider);
      KSnack.success(context, l10n.medalsShowcaseSaved);
      setState(() => _saved = true);
      if (context.canPop()) context.pop();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Medal _medal(String code) => widget.medals.firstWhere((m) => m.code == code);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return PopScope(
      canPop: !_changed || _saving || _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l10n.medalsDiscard),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(l10n.bondsCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l10n.medalsDiscardConfirm),
              ),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: KAppBar(
          backgroundColor: p.background,
          centerTitle: true,
          title: Text(l10n.medalsShowcaseTitle),
          actions: [
            TextButton(
              key: ShowcasePicker.saveKey,
              onPressed: _saving || !_changed ? null : () => unawaited(_save()),
              child: Text(l10n.medalsShowcaseSave),
            ),
          ],
        ),
        body: widget.medals.isEmpty
            ? Center(
                child: KEmptyState(
                  icon: Icons.military_tech_outlined,
                  title: l10n.medalsEmptyTitle,
                  message: l10n.medalsShowcaseNoneEarned,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(KSpacing.lg),
                children: [
                  Text(
                    l10n.medalsShowcaseHint(maxShowcaseMedals),
                    style: t.body.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: KSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.medalsShowcaseTitle,
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                      ),
                      Text(
                        l10n.medalsShowcaseCount(
                          _chosen.length,
                          maxShowcaseMedals,
                        ),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Container(
                    key: ShowcasePicker.chosenKey,
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(KRadius.md),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: _chosen.isEmpty
                        ? Text(
                            l10n.medalsShowcaseEmptyPreview,
                            style: t.caption.copyWith(color: p.textTertiary),
                          )
                        : Wrap(
                            spacing: KSpacing.sm,
                            runSpacing: KSpacing.sm,
                            children: [
                              for (final (i, code) in _chosen.indexed)
                                Semantics(
                                  button: true,
                                  label: l10n.medalsPosition(
                                    _medal(code).name,
                                    i + 1,
                                  ),
                                  excludeSemantics: true,
                                  child: InkResponse(
                                    key: ShowcasePicker.chosenItemKey(code),
                                    onTap: () => _toggle(code),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        MedalIcon(
                                          iconKey: _medal(code).iconKey,
                                          size: 44,
                                        ),
                                        PositionedDirectional(
                                          top: -4,
                                          end: -4,
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundColor: p.primary,
                                            child: Text(
                                              '${i + 1}',
                                              style: t.caption.copyWith(
                                                color: p.onPrimary,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: KSpacing.lg),
                  for (final m in widget.medals)
                    CheckboxListTile(
                      key: ShowcasePicker.optionKey(m.code),
                      value: _chosen.contains(m.code),
                      onChanged: (_) => _toggle(m.code),
                      secondary: MedalIcon(iconKey: m.iconKey),
                      title: Text(m.name),
                      subtitle: Text(
                        m.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
      ),
    );
  }
}
