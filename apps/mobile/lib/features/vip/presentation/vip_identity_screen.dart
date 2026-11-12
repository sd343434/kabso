import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_identity_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D378 (§10.168.4): the golden IDs the caller may pick and their own.
final FutureProvider<VipGoldenIdChoice> vipGoldenIdChoiceProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(vipIdentityRepositoryProvider).goldenIds();
    });

/// D378 (§10.168.3): the medal the caller's VIP claims free and the names.
final FutureProvider<({PremiumTier? vipTier, List<PremiumNameStatus> names})>
vipPremiumChoiceProvider = FutureProvider.autoDispose((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(vipIdentityRepositoryProvider).premiumChoice();
});

/// The longest signature (characters).
const int vipSignatureMax = 24;

/// D378 «هويتي المميزة»: where a member sets what their identity perks need
/// — the signature's text (ANIMATED_SIGNATURE), a golden ID of their class
/// (GOLDEN_ID) and a premium username claimed free (PREMIUM_USERNAME). Each
/// card shows only while the member's tier (or a lower one) holds its perk.
class VipIdentityScreen extends ConsumerWidget {
  const new({super.key});

  static const signatureFieldKey = Key('vip.identity.signatureField');
  static const signatureSaveKey = Key('vip.identity.signatureSave');
  static const signatureClearKey = Key('vip.identity.signatureClear');
  static const goldenCardKey = Key('vip.identity.golden');
  static const goldenReleaseKey = Key('vip.identity.goldenRelease');
  static Key goldenNumberKey(String n) => Key('vip.identity.golden.$n');
  static const premiumCardKey = Key('vip.identity.premium');
  static Key premiumNameKey(String n) => Key('vip.identity.premium.$n');
  static const noneKey = Key('vip.identity.none');

  /// Whether a member's [look] holds any perk this page sets.
  static bool hasAny(VipLook? look) =>
      look != null &&
      look.vip.member &&
      (look.has(VipPerks.signature) ||
          look.has(VipPerks.goldenId) ||
          look.has(VipPerks.premiumUsername));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(myVipProvider).value;
    final vip = membership == null
        ? null
        : UserVip(
            tier: membership.tierCode,
            rank: 0,
            color: membership.tierColor,
          );
    final look = ref.watch(vipLookProvider(vip));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vipIdentityTitle)),
      body: SafeArea(
        child: !hasAny(look)
            ? KEmptyState(
                key: noneKey,
                icon: Icons.workspace_premium_outlined,
                title: l10n.vipIdentityNoneTitle,
                message: l10n.vipIdentityNoneMessage,
              )
            : ListView(
                padding: const EdgeInsets.all(KSpacing.md),
                children: [
                  if (look!.has(VipPerks.signature)) ...[
                    _SignatureCard(look: look),
                    const SizedBox(height: KSpacing.md),
                  ],
                  if (look.has(VipPerks.goldenId)) ...[
                    const _GoldenIdCard(),
                    const SizedBox(height: KSpacing.md),
                  ],
                  if (look.has(VipPerks.premiumUsername)) const _PremiumCard(),
                ],
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: t.title.copyWith(fontSize: 16)),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(subtitle, style: t.caption.copyWith(color: p.textSecondary)),
            const SizedBox(height: KSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// The message for a refused identity call.
String _refusal(AppLocalizations l10n, Object error) {
  final failure = toAppFailure(error);
  final issue = failure is ServerFailure && failure.details.isNotEmpty
      ? failure.details.first.issue
      : null;
  return switch (issue) {
    'blocked_word' => l10n.vipSignatureBlocked,
    'too_long' => l10n.vipSignatureTooLong(vipSignatureMax),
    'too_short' => l10n.vipSignatureTooShort,
    'invalid_format' => l10n.vipSignatureInvalid,
    'taken' => l10n.vipGoldenIdTaken,
    'class' => l10n.vipIdentityNotYourClass,
    'not_held' => l10n.vipIdentityNotHeld,
    _ => failureMessage(l10n, failure),
  };
}

// ---- ANIMATED_SIGNATURE -----------------------------------------------------

class _SignatureCard extends ConsumerStatefulWidget {
  const new({required this.look});

  final VipLook look;

  @override
  ConsumerState<_SignatureCard> createState() => _SignatureCardState();
}

class _SignatureCardState extends ConsumerState<_SignatureCard> {
  final _text = TextEditingController();
  bool _touched = false;
  bool _busy = false;
  String? _saved;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(String? value) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final stored = await ref
          .read(vipIdentityRepositoryProvider)
          .setSignature(value);
      if (!mounted) return;
      setState(() {
        _saved = stored ?? '';
        _text.text = stored ?? '';
        _touched = true;
      });
      final me = ref.read(currentUserProvider)?.username;
      if (me != null) ref.invalidate(publicProfileProvider(me));
      _say(
        context,
        stored == null ? l10n.vipSignatureCleared : l10n.vipIdentitySaved,
      );
    } on Object catch (e) {
      if (mounted) _say(context, _refusal(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(currentUserProvider)?.username;
    final current = me == null
        ? null
        : ref.watch(publicProfileProvider(me)).value?.vip?.signature;
    if (!_touched && current != null && _text.text.isEmpty) {
      _text.text = current;
    }
    final shown = _saved ?? current;
    final preview = UserVip(
      tier: widget.look.vip.tier,
      rank: widget.look.vip.rank,
      color: widget.look.vip.color,
      signature: shown == null || shown.isEmpty ? null : shown,
    );
    return _Card(
      title: l10n.vipSignatureTitle,
      subtitle: l10n.vipSignatureSubtitle(vipSignatureMax),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview.signature != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: VipSignatureLine(vip: preview),
            ),
            const SizedBox(height: KSpacing.sm),
          ],
          TextField(
            key: VipIdentityScreen.signatureFieldKey,
            controller: _text,
            maxLength: vipSignatureMax,
            onChanged: (_) => setState(() => _touched = true),
            decoration: InputDecoration(hintText: l10n.vipSignatureHint),
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(
                child: KButton(
                  key: VipIdentityScreen.signatureSaveKey,
                  label: l10n.vipIdentitySave,
                  loading: _busy,
                  onPressed: _text.text.trim().isEmpty
                      ? null
                      : () => unawaited(_save(_text.text)),
                ),
              ),
              if (shown != null && shown.isNotEmpty) ...[
                const SizedBox(width: KSpacing.sm),
                KButton(
                  key: VipIdentityScreen.signatureClearKey,
                  label: l10n.vipSignatureClear,
                  variant: KButtonVariant.secondary,
                  expand: false,
                  onPressed: _busy ? null : () => unawaited(_save(null)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---- GOLDEN_ID --------------------------------------------------------------

/// The name of a golden ID class.
String vipGoldenClassName(AppLocalizations l10n, String? cls) => switch (cls) {
  'REPEATED' => l10n.vipGoldenClassRepeated,
  'THREE_DIGIT' => l10n.vipGoldenClassDigits(3),
  'FOUR_DIGIT' => l10n.vipGoldenClassDigits(4),
  'FIVE_DIGIT' => l10n.vipGoldenClassDigits(5),
  _ => '—',
};

class _GoldenIdCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_GoldenIdCard> createState() => _GoldenIdCardState();
}

class _GoldenIdCardState extends ConsumerState<_GoldenIdCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() call, String done) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      ref.invalidate(vipGoldenIdChoiceProvider);
      final me = ref.read(currentUserProvider)?.username;
      if (me != null) ref.invalidate(publicProfileProvider(me));
      _say(context, done);
    } on Object catch (e) {
      if (mounted) {
        _say(context, _refusal(l10n, e));
        ref.invalidate(vipGoldenIdChoiceProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final repo = ref.watch(vipIdentityRepositoryProvider);
    final choice = ref.watch(vipGoldenIdChoiceProvider);
    return _Card(
      key: VipIdentityScreen.goldenCardKey,
      title: l10n.vipGoldenIdTitle,
      subtitle: switch (choice.value?.goldenClass) {
        final cls? => l10n.vipGoldenIdSubtitle(vipGoldenClassName(l10n, cls)),
        null => l10n.vipGoldenIdNoClass,
      },
      child: switch (choice) {
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.mine case final mine?) ...[
              Row(
                children: [
                  VipGoldenIdChip(
                    goldenId: UserGoldenId(
                      number: mine.number,
                      goldenClass: mine.goldenClass,
                    ),
                  ),
                  const Spacer(),
                  KButton(
                    key: VipIdentityScreen.goldenReleaseKey,
                    label: l10n.vipGoldenIdRelease,
                    variant: KButtonVariant.ghost,
                    expand: false,
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run(
                              repo.releaseGoldenId,
                              l10n.vipGoldenIdReleased,
                            ),
                          ),
                  ),
                ],
              ),
              if (mine.grace)
                Padding(
                  padding: const EdgeInsets.only(top: KSpacing.xs),
                  child: Text(
                    l10n.vipGoldenIdGrace,
                    style: context.textStyles.caption.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: KSpacing.md),
            ],
            if (value.available.isEmpty)
              Text(
                l10n.vipGoldenIdNoneFree,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: [
                  for (final n in value.available)
                    ActionChip(
                      key: VipIdentityScreen.goldenNumberKey(n),
                      label: Text(n, textDirection: TextDirection.ltr),
                      tooltip: l10n.vipGoldenIdPick(n),
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _run(
                                () => repo.claimGoldenId(n),
                                l10n.vipGoldenIdTaken2(n),
                              ),
                            ),
                    ),
                ],
              ),
          ],
        ),
        AsyncError(:final error) => Text(_refusal(l10n, error)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

// ---- PREMIUM_USERNAME -------------------------------------------------------

class _PremiumCard extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends ConsumerState<_PremiumCard> {
  bool _busy = false;

  Future<void> _claim(String name) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final mine = await ref
          .read(vipIdentityRepositoryProvider)
          .claimPremiumUsername(name);
      if (!mounted) return;
      ref
        ..invalidate(vipPremiumChoiceProvider)
        ..invalidate(meProvider);
      _say(context, l10n.vipPremiumClaimed(mine.username));
    } on Object catch (e) {
      if (mounted) _say(context, _refusal(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choice = ref.watch(vipPremiumChoiceProvider);
    return _Card(
      key: VipIdentityScreen.premiumCardKey,
      title: l10n.vipPremiumTitle,
      subtitle: l10n.vipPremiumSubtitle,
      child: switch (choice) {
        AsyncData(:final value) when value.names.isEmpty => Text(
          l10n.vipPremiumNone,
          style: context.textStyles.caption,
        ),
        AsyncData(:final value) => Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.sm,
          children: [
            for (final n in value.names)
              if (n.tier case final tier?)
                InkWell(
                  key: VipIdentityScreen.premiumNameKey(n.username),
                  borderRadius: BorderRadius.circular(KRadius.md),
                  onTap: _busy ? null : () => unawaited(_claim(n.username)),
                  child: Semantics(
                    button: true,
                    label: l10n.vipPremiumClaim(n.username),
                    excludeSemantics: true,
                    child: KSpecialUsername(username: n.username, tier: tier),
                  ),
                ),
          ],
        ),
        AsyncError(:final error) => Text(_refusal(l10n, error)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
