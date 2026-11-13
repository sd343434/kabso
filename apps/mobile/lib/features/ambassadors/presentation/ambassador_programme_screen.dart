import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_badge.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountries, rechargeCountryName;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The percentage of [bps] basis points (500 → «5%»), Latin digits.
String ambassadorPercent(int bps) => NumberFormat.decimalPercentPattern(
  locale: 'en',
  decimalDigits: bps % 100 == 0 ? 0 : 2,
).format(bps / 10000);

String _n(int v) => KFormat.bidiIsolate(KFormat.grouped(v));

/// The reward of a level in words.
String ambassadorRewardText(AppLocalizations l10n, AmbassadorReward r) =>
    switch (r.kind) {
      'COINS' => l10n.ambRewardCoins(_n(r.amount)),
      'VIP_DAYS' => l10n.ambRewardVip(
        KFormat.bidiIsolate((r.vipTier ?? 'VIP').replaceAll('_', ' ')),
        _n(r.amount),
      ),
      'BAG_ITEM' => l10n.ambRewardItem(_n(r.amount)),
      _ => l10n.ambRewardNone,
    };

/// v1.140-social (D390, §10.179.2): «برنامج سفراء Kabso» — what an
/// ambassador does and gets, the levels and the rules from the server (no
/// number is hard-coded), then the application form or its status; an
/// ambassador opens the dashboard. Off: «قريباً» and no form.
class AmbassadorProgrammeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const submitKey = Key('ambassador.submit');
  static const statusKey = Key('ambassador.status');
  static const dashboardKey = Key('ambassador.openDashboard');
  static const audienceKey = Key('ambassador.audience');
  static const motivationKey = Key('ambassador.motivation');
  static Key linkKey(int i) => Key('ambassador.link.$i');
  static const maxLinks = 5;

  @override
  ConsumerState<AmbassadorProgrammeScreen> createState() =>
      _AmbassadorProgrammeScreenState();
}

class _AmbassadorProgrammeScreenState
    extends ConsumerState<AmbassadorProgrammeScreen> {
  late String? _country = switch (ref
      .read(currentUserProvider)
      ?.country
      ?.toUpperCase()) {
    final String c when rechargeCountries.contains(c) => c,
    _ => null,
  };
  final List<TextEditingController> _links = [TextEditingController()];
  final _audience = TextEditingController();
  final _motivation = TextEditingController();
  bool _tried = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _links) {
      c.dispose();
    }
    _audience.dispose();
    _motivation.dispose();
    super.dispose();
  }

  static bool _linkOk(String v) =>
      RegExp(r'^https://\S+$', caseSensitive: false).hasMatch(v.trim());

  int? get _audienceValue => int.tryParse(_audience.text.trim());

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _tried = true;
      _error = null;
    });
    final country = _country;
    final audience = _audienceValue;
    if (country == null ||
        !_links.every((c) => _linkOk(c.text)) ||
        audience == null ||
        _motivation.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(ambassadorRepositoryProvider)
          .apply(
            AmbassadorApplicationDraft(
              country: country,
              links: [for (final c in _links) c.text.trim()],
              audienceSize: audience,
              motivation: _motivation.text.trim(),
            ),
          );
      if (!mounted) return;
      ref.invalidate(ambassadorProgrammeProvider);
      KSnack.success(context, l10n.ambSent);
      setState(() => _busy = false);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final programme = ref.watch(ambassadorProgrammeProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.ambProgrammeTitle),
        leading: Navigator.canPop(context) ? null : const SizedBox.shrink(),
      ),
      body: switch (programme) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxl,
          ),
          children: [
            const _Hero(),
            const SizedBox(height: KSpacing.lg),
            const _Section(
              icon: Icons.campaign_rounded,
              kind: _SectionKind.does,
            ),
            const SizedBox(height: KSpacing.md),
            const _Section(
              icon: Icons.card_giftcard_rounded,
              kind: _SectionKind.gets,
            ),
            if (value.levels.isNotEmpty) ...[
              const SizedBox(height: KSpacing.lg),
              _Levels(levels: value.levels),
              const SizedBox(height: KSpacing.lg),
              _Rules(programme: value),
            ],
            const SizedBox(height: KSpacing.lg),
            _status(value) ?? _form(value),
          ],
        ),
        AsyncError(:final error) => Center(
          child: Text(failureMessage(l10n, toAppFailure(error))),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The status card instead of the form (off, staff, pending, ambassador).
  Widget? _status(AmbassadorProgramme value) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    if (value.canApply) return null;
    final (IconData icon, String text) = switch (value) {
      AmbassadorProgramme(isAmbassador: true) => (
        Icons.verified_rounded,
        l10n.ambYouAreAmbassador,
      ),
      AmbassadorProgramme(refusal: 'DISABLED') => (
        Icons.hourglass_top_rounded,
        l10n.ambSoon,
      ),
      AmbassadorProgramme(refusal: 'STAFF') => (
        Icons.badge_rounded,
        l10n.ambStatusStaff,
      ),
      AmbassadorProgramme(refusal: 'PENDING') => (
        Icons.hourglass_top_rounded,
        l10n.ambStatusPending,
      ),
      _ => (Icons.info_outline_rounded, l10n.ambStatusNotActive),
    };
    return Container(
      key: AmbassadorProgrammeScreen.statusKey,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: p.primary, size: 40),
          const SizedBox(height: KSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          if (value.isAmbassador) ...[
            const SizedBox(height: KSpacing.md),
            KButton(
              key: AmbassadorProgrammeScreen.dashboardKey,
              label: l10n.ambOpenDashboard,
              icon: Icons.insights_rounded,
              onPressed: () =>
                  unawaited(context.push(AppRoutes.ambassadorDashboard)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _form(AmbassadorProgramme value) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rejected = value.application?.status == 'REJECTED'
        ? value.application?.rejectReason
        : null;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ambFormTitle, style: t.title),
          if (rejected != null)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(
                l10n.ambStatusRejected(rejected),
                style: t.caption.copyWith(color: p.error),
              ),
            ),
          const SizedBox(height: KSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _country,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.ambCountry,
              errorText: _tried && _country == null
                  ? l10n.ambCountryError
                  : null,
            ),
            items: [
              for (final c in rechargeCountries)
                DropdownMenuItem(
                  value: c,
                  child: Text(
                    rechargeCountryName(context, c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (c) => setState(() => _country = c),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.ambLinks,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          for (final (i, c) in _links.indexed) ...[
            KTextField(
              fieldKey: AmbassadorProgrammeScreen.linkKey(i),
              label: 'https://',
              controller: c,
              maxLength: 200,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              errorText: _tried && !_linkOk(c.text) ? l10n.ambLinkError : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: KSpacing.xs),
          ],
          if (_links.length < AmbassadorProgrammeScreen.maxLinks)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _links.add(TextEditingController())),
                icon: const Icon(Icons.add_link_rounded),
                label: Text(l10n.ambAddLink),
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          KTextField(
            fieldKey: AmbassadorProgrammeScreen.audienceKey,
            label: l10n.ambAudience,
            controller: _audience,
            maxLength: 10,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            errorText: _tried && _audienceValue == null
                ? l10n.ambAudienceError
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpacing.sm),
          KTextField(
            fieldKey: AmbassadorProgrammeScreen.motivationKey,
            label: l10n.ambMotivation,
            controller: _motivation,
            maxLength: 1000,
            keyboardType: TextInputType.multiline,
            errorText: _tried && _motivation.text.trim().isEmpty
                ? l10n.ambMotivationError
                : null,
            onChanged: (_) => setState(() {}),
          ),
          if (_error case final e?) ...[
            const SizedBox(height: KSpacing.sm),
            Text(e, style: t.caption.copyWith(color: p.error)),
          ],
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: AmbassadorProgrammeScreen.submitKey,
            label: l10n.ambSubmit,
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _busy ? null : () => unawaited(_submit()),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            p.primary,
            Color.lerp(p.primary, const Color(0xFF1A1033), 0.55)!,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.onPrimary.withValues(alpha: 0.16),
            ),
            child: Icon(Icons.public_rounded, color: p.onPrimary, size: 32),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ambProgrammeTitle,
                  style: t.title.copyWith(color: p.onPrimary),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.ambHeroTitle,
                  style: t.body.copyWith(
                    color: p.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SectionKind { does, gets }

class _Section extends StatelessWidget {
  const new({required this.icon, required this.kind});

  final IconData icon;
  final _SectionKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final (title, items) = switch (kind) {
      _SectionKind.does => (
        l10n.ambWhatYouDo,
        [l10n.ambDo1, l10n.ambDo2, l10n.ambDo3, l10n.ambDo4],
      ),
      _SectionKind.gets => (
        l10n.ambWhatYouGet,
        [l10n.ambGet1, l10n.ambGet2, l10n.ambGet3, l10n.ambGet4],
      ),
    };
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: p.primary, size: 22),
              const SizedBox(width: KSpacing.xs),
              Expanded(child: Text(title, style: t.bodyStrong)),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: p.success,
                    ),
                  ),
                  const SizedBox(width: KSpacing.xs),
                  Expanded(
                    child: Text(
                      item,
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Levels extends StatelessWidget {
  const new({required this.levels});

  final List<AmbassadorLevel> levels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.ambLevelsTitle, style: t.title),
        const SizedBox(height: KSpacing.xs),
        for (final l in levels)
          Container(
            margin: const EdgeInsets.only(bottom: KSpacing.xs),
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(KRadius.lg),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AmbassadorBadge(level: l.code),
                    const Spacer(),
                    Text(
                      l10n.ambLevelCommission(
                        KFormat.bidiIsolate(ambassadorPercent(l.commissionBps)),
                      ),
                      style: t.bodyStrong.copyWith(color: p.primaryText),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.ambLevelRequirement(
                    _n(l.minActiveReferrals),
                    _n(l.minTopupCoins),
                  ),
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                Text(
                  ambassadorRewardText(l10n, l.reward),
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const new({required this.programme});

  final AmbassadorProgramme programme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final rules = [
      l10n.ambRuleWindow(_n(programme.attributionWindowDays)),
      l10n.ambRuleHold(_n(programme.holdDays)),
      l10n.ambRuleActive(
        _n(programme.minActiveDays),
        _n(programme.minActiveTopupCoins),
      ),
      l10n.ambRuleTrack,
      l10n.ambRuleFraud,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.ambRulesTitle, style: t.title),
        const SizedBox(height: KSpacing.xs),
        for (final r in rules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    r,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
