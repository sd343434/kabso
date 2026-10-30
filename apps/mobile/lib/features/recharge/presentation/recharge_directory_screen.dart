import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart'
    show rechargePaymentTypeName;
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The countries offered first (the Arab League, then a few more); the
/// person's own country is selected by default and always offered.
const rechargeCountries = [
  'EG', 'SA', 'AE', 'IQ', 'JO', 'KW', 'QA', 'BH', 'OM', 'YE', 'SY', 'LB', //
  'PS', 'MA', 'DZ', 'TN', 'LY', 'SD', 'MR', 'SO', 'DJ', 'KM', 'TR',
];

/// `/recharge/agents` «وكلاء الشحن» (D185, §10.48): the ACTIVE agents of a
/// country — the ones available now first — each with the code, photo,
/// name and badge, the cities, the payment kinds, and the WhatsApp number
/// and payment method of «now». «تواصل» opens WhatsApp after D175's
/// «أنت تغادر Kabso»; an agent not available now has no button. The buyer
/// pays the agent outside the app.
class RechargeDirectoryScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialCountry});

  final String? initialCountry;

  static const emptyKey = Key('recharge.directory.empty');
  static Key cardKey(String code) => Key('recharge.agent.$code');
  static Key contactKey(String code) => Key('recharge.agent.$code.contact');
  static Key countryKey(String c) => Key('recharge.country.$c');

  @override
  ConsumerState<RechargeDirectoryScreen> createState() =>
      _RechargeDirectoryScreenState();
}

class _RechargeDirectoryScreenState
    extends ConsumerState<RechargeDirectoryScreen> {
  late String _country =
      widget.initialCountry ?? ref.read(currentUserProvider)?.country ?? 'EG';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final load = ref.watch(rechargeDirectoryProvider(_country));
    final countries = {_country, ...rechargeCountries}.toList();
    return MePage(
      title: l10n.rechargeDirectoryTitle,
      onRefresh: () async {
        ref.invalidate(rechargeDirectoryProvider(_country));
        try {
          await ref.read(rechargeDirectoryProvider(_country).future);
        } on Object {
          // Shown with a retry.
        }
      },
      children: [
        // Owner polish: the countries scroll; the selected one is filled.
        SizedBox(
          height: KSizes.minTouchTarget,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: countries.length,
            separatorBuilder: (_, _) => const SizedBox(width: KSpacing.xs),
            itemBuilder: (_, i) {
              final c = countries[i];
              return Center(
                child: KChip(
                  key: RechargeDirectoryScreen.countryKey(c),
                  label: KFormat.bidiIsolate(rechargeCountryName(context, c)),
                  selected: c == _country,
                  onSelected: () => setState(() => _country = c),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        RechargeNotice(
          icon: Icons.info_outline_rounded,
          text: l10n.rechargeDirectoryNote,
        ),
        const SizedBox(height: KSpacing.sm),
        ...switch (load) {
          AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
            KEmptyState(
              key: RechargeDirectoryScreen.emptyKey,
              icon: Icons.storefront_outlined,
              title: l10n.rechargeDirectoryEmpty,
              message: l10n.rechargeDirectoryEmptyBody,
              compact: true,
            ),
          ],
          AsyncValue(
            value: FeedItems(
              :final items,
              :final hasMore,
              :final loadMoreError,
            ),
          ) =>
            [
              for (final a in items) _AgentCard(agent: a, country: _country),
              if (hasMore)
                MeLoadMore(
                  failed: loadMoreError != null,
                  onLoad: ref
                      .read(rechargeDirectoryProvider(_country).notifier)
                      .loadMore,
                  itemCount: items.length,
                ),
            ],
          AsyncValue(:final error?, isLoading: false) => [
            FailureErrorState(
              title: l10n.errorTitle,
              failure: toAppFailure(error),
              onRetry: () =>
                  ref.invalidate(rechargeDirectoryProvider(_country)),
              compact: true,
            ),
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }
}

/// The country's name in the app language (Flutter has no list; the
/// common ones are named, others show their code).
String rechargeCountryName(BuildContext context, String code) {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  const names = {
    'EG': ('مصر', 'Egypt'),
    'SA': ('السعودية', 'Saudi Arabia'),
    'AE': ('الإمارات', 'UAE'),
    'IQ': ('العراق', 'Iraq'),
    'JO': ('الأردن', 'Jordan'),
    'KW': ('الكويت', 'Kuwait'),
    'QA': ('قطر', 'Qatar'),
    'BH': ('البحرين', 'Bahrain'),
    'OM': ('عُمان', 'Oman'),
    'YE': ('اليمن', 'Yemen'),
    'SY': ('سوريا', 'Syria'),
    'LB': ('لبنان', 'Lebanon'),
    'PS': ('فلسطين', 'Palestine'),
    'MA': ('المغرب', 'Morocco'),
    'DZ': ('الجزائر', 'Algeria'),
    'TN': ('تونس', 'Tunisia'),
    'LY': ('ليبيا', 'Libya'),
    'SD': ('السودان', 'Sudan'),
    'MR': ('موريتانيا', 'Mauritania'),
    'SO': ('الصومال', 'Somalia'),
    'DJ': ('جيبوتي', 'Djibouti'),
    'KM': ('جزر القمر', 'Comoros'),
    'TR': ('تركيا', 'Turkey'),
  };
  final n = names[code];
  return n == null ? code : (ar ? n.$1 : n.$2);
}

class _AgentCard extends ConsumerWidget {
  const new({required this.agent, required this.country});

  final RechargeAgentListing agent;
  final String country;

  Future<void> _contact(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final digits = (agent.whatsappNow ?? '').replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return;
    final url = 'https://wa.me/$digits';
    // D175: WhatsApp is not one of the platforms opened directly.
    if (!await confirmLeavingKabso(context, url) || !context.mounted) return;
    var opened = false;
    try {
      opened = await ref.read(externalLinkOpenerProvider).open(Uri.parse(url));
    } on PlatformException {
      opened = false;
    }
    if (!opened && context.mounted) KSnack.error(context, l10n.linkOpenFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final u = agent.user;
    final now = agent.availableNow;
    final cities = [
      for (final l in agent.locations)
        if (l.country == country) ...l.cities,
    ];
    // An agent who is not available now is shown muted.
    final ink = now ? p.textPrimary : p.textSecondary;
    return Padding(
      key: RechargeDirectoryScreen.cardKey(agent.code),
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: now ? p.surfaceRaised : p.surface,
          borderRadius: BorderRadius.circular(KRadius.lg),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: now ? 1 : 0.55,
                  child: KAvatar(name: u.displayName, imageUrl: u.avatarUrl),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              u.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(color: ink),
                            ),
                          ),
                          RechargeAgentInlineBadge(
                            code: agent.code,
                            height: inlineAgentBadgeHeight(
                              t.bodyStrong.fontSize!,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        l10n.rechargeIdLine(KFormat.bidiIsolate(agent.code)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: now ? p.primaryText : p.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (cities.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: p.textTertiary,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                cities.join('، '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (agent.paymentTypes.isNotEmpty) ...[
              const SizedBox(height: KSpacing.sm),
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: [
                  for (final ty in agent.paymentTypes)
                    RechargePill(label: rechargePaymentTypeName(l10n, ty)),
                ],
              ),
            ],
            const SizedBox(height: KSpacing.sm),
            Divider(height: 1, color: p.border),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: now ? p.success : p.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          now
                              ? l10n.rechargeAvailableNowLine(
                                  KFormat.bidiIsolate(
                                    agent.paymentMethodNow ?? '',
                                  ),
                                )
                              : l10n.rechargeNotAvailableNow,
                          style: t.caption.copyWith(
                            color: now ? p.success : p.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (now) ...[
                  const SizedBox(width: KSpacing.sm),
                  FilledButton.icon(
                    key: RechargeDirectoryScreen.contactKey(agent.code),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, KSizes.minTouchTarget - 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                      ),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                    ),
                    onPressed: () => unawaited(_contact(context, ref)),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(l10n.rechargeContact),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
