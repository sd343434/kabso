import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_entry_card.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/referrals/application/referral_providers.dart';
import 'package:kabso_live/features/referrals/data/referral_repository.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart'
    show formatPrice;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// D217: opens the system share sheet and WhatsApp. Tests replace it.
abstract interface class InviteSharer {
  /// The system share sheet with [text]; `true` unless it was dismissed.
  Future<bool> share(String text, {Rect? origin});

  /// WhatsApp with [text] ready to send; `false` when it could not open.
  Future<bool> whatsapp(String text);
}

class _SystemInviteSharer implements InviteSharer {
  const new();

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> whatsapp(String text) => launcher.launchUrl(
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
    mode: launcher.LaunchMode.externalApplication,
  );
}

final inviteSharerProvider = Provider<InviteSharer>(
  (ref) => const _SystemInviteSharer(),
);

/// The percentage of [bps] basis points (500 → «5%»), Latin digits.
String referralPercent(int bps) => NumberFormat.decimalPercentPattern(
  locale: 'en',
  decimalDigits: bps % 100 == 0 ? 0 : 2,
).format(bps / 10000);

/// Cherries as a grouped number, isolated for mixed-direction text.
String _n(int value) => KFormat.bidiIsolate(KFormat.grouped(value));

/// The milestones from the server's values, one per line («صديق واحد:
/// 50,000 كرزة», «5 أصدقاء: 300,000 كرزة», …).
String referralMilestoneList(
  AppLocalizations l10n,
  List<ReferralMilestone> milestones,
) => milestones
    .map(
      (m) => l10n.inviteMilestoneItem(
        l10n.inviteMilestoneFriends(m.friends),
        _n(m.cherries),
      ),
    )
    .join('\n');

/// `/invite-friends` «دعوة صديق» (v1.74-social, D217, CONVENTIONS §10.71),
/// behind the Me hub's «اربح المال». The layout follows the owner's
/// reference (a third-party app's «Invite friend», layout only) in Kabso's
/// identity and art (Kabi, the gift box, the cherry): the hero «ادعُ أصدقاءك
/// واربح حتى N», the ticker of real rewards, the steps and what each side
/// gets, «ادعُ الآن», the code with «نسخ», the milestones with «N مدعو», the
/// friends invited, and a share bar (WhatsApp, the share sheet, copy link).
/// Every number is the server's (`MyReferral`); none is written here. When
/// the server says the programme is off, the page gives way to the cherry
/// wallet (the former destination of «اربح المال»).
class InviteFriendsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const helpKey = Key('invite.help');
  static const heroKey = Key('invite.hero');
  static const tickerKey = Key('invite.ticker');
  static const stepsKey = Key('invite.steps');
  static const youGetKey = Key('invite.youGet');
  static const inviteNowKey = Key('invite.now');
  static const codeKey = Key('invite.code');
  static const copyKey = Key('invite.copy');
  static const milestonesKey = Key('invite.milestones');
  static const invitedKey = Key('invite.invited');
  static const rewardsKey = Key('invite.rewards');
  static const friendsKey = Key('invite.friends');
  static const noFriendsKey = Key('invite.noFriends');
  static const shareBarKey = Key('invite.shareBar');
  static const whatsappKey = Key('invite.share.whatsapp');
  static const shareKey = Key('invite.share.more');
  static const copyLinkKey = Key('invite.share.copyLink');
  static const errorKey = Key('invite.error');
  static const loadingKey = Key('invite.loading');
  static Key milestoneKey(int friends) => Key('invite.milestone.$friends');

  /// Kabi's animation (off in tests and with reduced motion).
  static bool animateArt = true;

  @override
  ConsumerState<InviteFriendsScreen> createState() =>
      _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends ConsumerState<InviteFriendsScreen> {
  bool _leaving = false;

  void _leaveToWallet() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null) return;
      unawaited(router.pushReplacement(AppRoutes.walletCherries));
    });
  }

  String _shareText(AppLocalizations l10n, MyReferral r) =>
      l10n.inviteShareText(r.code, r.link);

  Future<void> _share(MyReferral r) async {
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await ref
          .read(inviteSharerProvider)
          .share(_shareText(l10n, r), origin: origin);
    } on Object {
      await _copy(r.link, l10n.inviteShareFailed);
    }
  }

  Future<void> _whatsapp(MyReferral r) async {
    final l10n = context.l10n;
    var ok = false;
    try {
      ok = await ref.read(inviteSharerProvider).whatsapp(_shareText(l10n, r));
    } on Object {
      ok = false;
    }
    if (!ok) await _copy(r.link, l10n.inviteShareFailed);
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) KSnack.success(context, done);
  }

  void _showRules(MyReferral r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RulesSheet(referral: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final load = ref.watch(myReferralProvider);
    final data = load.value;
    final r = data;
    if (load.hasValue && (r == null || !r.enabled)) _leaveToWallet();
    final Widget body;
    if (r != null && r.enabled) {
      body = _InviteBody(
        referral: r,
        onInvite: () => unawaited(_share(r)),
        onCopy: () => unawaited(_copy(r.code, l10n.inviteCodeCopied)),
      );
    } else if (load.hasError && !load.isLoading) {
      body = Center(
        key: InviteFriendsScreen.errorKey,
        child: KErrorState(
          title: l10n.inviteErrorTitle,
          message: failureMessage(l10n, toAppFailure(load.error!)),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(myReferralProvider),
        ),
      );
    } else {
      body = const Center(
        key: InviteFriendsScreen.loadingKey,
        child: CircularProgressIndicator(),
      );
    }
    return Scaffold(
      appBar: KAppBar(
        title: Text(l10n.inviteTitle),
        centerTitle: true,
        actions: [
          IconButton(
            key: InviteFriendsScreen.helpKey,
            tooltip: l10n.inviteRulesTooltip,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: r == null || !r.enabled ? null : () => _showRules(r),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: r != null && r.enabled
          ? _ShareBar(
              onWhatsapp: () => unawaited(_whatsapp(r)),
              onShare: () => unawaited(_share(r)),
              onCopyLink: () => unawaited(_copy(r.link, l10n.inviteLinkCopied)),
            )
          : null,
    );
  }
}

class _InviteBody extends ConsumerWidget {
  const new({
    required this.referral,
    required this.onInvite,
    required this.onCopy,
  });

  final MyReferral referral;
  final VoidCallback onInvite;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = referral;
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final ticker = ref.watch(referralTickerProvider).value ?? const [];
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(referralTickerProvider)
          ..invalidate(myReferralProvider);
        await ref.read(myReferralProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: KSpacing.xl),
        children: [
          _Hero(referral: r),
          if (ticker.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.md,
                KSpacing.lg,
                0,
              ),
              child: _Ticker(items: ticker),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.xl),
                border: Border.all(color: p.border),
              ),
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitlePill(l10n.inviteCardTitle),
                  const SizedBox(height: KSpacing.md),
                  _Steps(referral: r),
                  const SizedBox(height: KSpacing.lg),
                  _YouGet(referral: r),
                  const SizedBox(height: KSpacing.lg),
                  KButton(
                    key: InviteFriendsScreen.inviteNowKey,
                    label: l10n.inviteNow,
                    icon: Icons.ios_share_rounded,
                    onPressed: onInvite,
                  ),
                  const SizedBox(height: KSpacing.md),
                  _CodeRow(code: r.code, onCopy: onCopy),
                  const SizedBox(height: KSpacing.lg),
                  const _DashedDivider(),
                  const SizedBox(height: KSpacing.lg),
                  _Milestones(referral: r),
                ],
              ),
            ),
          ),
          if (r.pendingCherries > 0 || r.creditedCherries > 0)
            Padding(
              key: InviteFriendsScreen.rewardsKey,
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.md,
                KSpacing.lg,
                0,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: KSpacing.md,
                runSpacing: KSpacing.xs,
                children: [
                  Text(
                    l10n.inviteRewardsPending(_n(r.pendingCherries)),
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
                  Text(
                    l10n.inviteRewardsCredited(_n(r.creditedCherries)),
                    style: text.caption.copyWith(color: p.success),
                  ),
                ],
              ),
            ),
          // D390: «برنامج سفراء Kabso» (only while it is on).
          const AmbassadorEntryCard(),
          _Friends(invitees: r.invitees),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const new({required this.referral});

  final MyReferral referral;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final money = referral.payout.valueOf(referral.upToTotal);
    final animate =
        InviteFriendsScreen.animateArt &&
        !MediaQuery.disableAnimationsOf(context);
    return Container(
      key: InviteFriendsScreen.heroKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: dark
              ? [KBrandColors.red700, p.background]
              : [KBrandColors.red400.withValues(alpha: 0.16), p.background],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inviteHeroLine,
                  style: text.headline.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: KSpacing.xs),
                KCherryAmount(
                  referral.upToTotal,
                  size: 30,
                  gap: KSpacing.sm,
                  style: text.display.copyWith(
                    fontWeight: FontWeight.w900,
                    color: dark ? KBrandColors.gold : KBrandColors.red600,
                  ),
                ),
                if (money > 0)
                  Text(
                    l10n.inviteMoneyHint(
                      KFormat.bidiIsolate(
                        formatPrice(money, referral.payout.currency),
                      ),
                    ),
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          KabiEmoji(KabsoEmoji.kabi('gift'), size: 104, animate: animate),
        ],
      ),
    );
  }
}

/// One real reward at a time (rotating every few seconds; still with reduced
/// motion).
class _Ticker extends StatefulWidget {
  const new({required this.items});

  final List<ReferralTickerItem> items;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  int _i = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (widget.items.length > 1 &&
        InviteFriendsScreen.animateArt &&
        !MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _i = (_i + 1) % widget.items.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final item = widget.items[_i % widget.items.length];
    return Container(
      key: InviteFriendsScreen.tickerKey,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, size: 18, color: p.primaryText),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                l10n.inviteTickerLine(
                  KFormat.bidiIsolate(item.name),
                  KFormat.grouped(item.cherries),
                ),
                key: ValueKey(_i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: p.primary, width: 1.5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.textStyles.bodyStrong,
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const new({required this.referral});

  final MyReferral referral;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final rules = referral.rules;
    Widget line(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.primaryText),
          const SizedBox(width: KSpacing.sm),
          Expanded(child: Text(value, style: context.textStyles.body)),
        ],
      ),
    );
    return Container(
      key: InviteFriendsScreen.stepsKey,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KabsoArtIcon(KabsoArt.giftBox, size: 64),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rules.inviterSignupCherries > 0)
                  line(
                    Icons.person_add_alt_1_rounded,
                    l10n.inviteStepSignup(_n(rules.inviterSignupCherries)),
                  ),
                if (rules.firstRechargeBps > 0)
                  line(
                    Icons.bolt_rounded,
                    l10n.inviteStepRecharge(
                      KFormat.bidiIsolate(
                        referralPercent(rules.firstRechargeBps),
                      ),
                    ),
                  ),
                if (referral.milestones.isNotEmpty)
                  line(
                    Icons.emoji_events_outlined,
                    l10n.inviteStepMilestones(
                      referralMilestoneList(l10n, referral.milestones),
                    ),
                  ),
                line(
                  Icons.verified_user_outlined,
                  l10n.inviteStepHold(_n(rules.holdHours)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YouGet extends StatelessWidget {
  const new({required this.referral});

  final MyReferral referral;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rules = referral.rules;
    final you = l10n.inviteCherries(_n(rules.inviterSignupCherries));
    final text = rules.inviteeSignupCherries > 0
        ? l10n.inviteYouGet(
            you,
            l10n.inviteCherries(_n(rules.inviteeSignupCherries)),
          )
        : l10n.inviteYouGetOnly(you);
    return Text(
      text,
      key: InviteFriendsScreen.youGetKey,
      textAlign: TextAlign.center,
      style: context.textStyles.title.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const new({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: KSpacing.sm,
      children: [
        Text(
          l10n.inviteMyCode,
          style: context.textStyles.body.copyWith(color: p.textSecondary),
        ),
        Text(
          code,
          key: InviteFriendsScreen.codeKey,
          textDirection: TextDirection.ltr,
          style: context.textStyles.bodyStrong.copyWith(letterSpacing: 2),
        ),
        OutlinedButton(
          key: InviteFriendsScreen.copyKey,
          onPressed: onCopy,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(48, 36),
          ),
          child: Text(l10n.inviteCopy),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: CustomPaint(painter: _DashPainter(context.palette.border)),
  );
}

class _DashPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _Milestones extends StatelessWidget {
  const new({required this.referral});

  final MyReferral referral;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final ms = referral.milestones;
    return Column(
      key: InviteFriendsScreen.milestonesKey,
      children: [
        if (ms.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KSpacing.sm,
            children: [
              Text(
                l10n.inviteMilestonesTitle,
                textAlign: TextAlign.center,
                style: text.bodyStrong,
              ),
              KCherryAmount(
                referral.upToMilestones,
                size: 18,
                style: text.title.copyWith(
                  fontWeight: FontWeight.w900,
                  color: p.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
        ],
        Row(
          key: InviteFriendsScreen.invitedKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 18, color: p.primaryText),
            const SizedBox(width: KSpacing.xs),
            Text(
              l10n.inviteInvitedCount(_n(referral.invited)),
              style: text.body.copyWith(color: p.primaryText),
            ),
          ],
        ),
        if (ms.isNotEmpty) ...[
          const SizedBox(height: KSpacing.md),
          _Track(milestones: ms),
        ],
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const new({required this.milestones});

  final List<ReferralMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final reached = milestones
        .where((m) => m.state != MilestoneState.locked)
        .length;
    return Stack(
      children: [
        // The track behind the locks (filled up to the last reached one).
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 66,
          child: Row(
            children: [
              for (var i = 0; i < milestones.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    color: i < reached
                        ? p.primary
                        : p.primary.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in milestones)
              Expanded(
                child: Semantics(
                  container: true,
                  label: l10n.inviteMilestoneSemantics(
                    l10n.inviteMilestoneFriends(m.friends),
                    KFormat.grouped(m.cherries),
                    switch (m.state) {
                      MilestoneState.locked => l10n.inviteMilestoneLocked,
                      MilestoneState.unlocked => l10n.inviteMilestoneUnlocked,
                      MilestoneState.claimed => l10n.inviteMilestoneClaimed,
                    },
                  ),
                  child: ExcludeSemantics(
                    child: _Stop(
                      key: InviteFriendsScreen.milestoneKey(m.friends),
                      milestone: m,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const new({required this.milestone, super.key});

  final ReferralMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final m = milestone;
    final (Color fill, Color fg, IconData icon) = switch (m.state) {
      MilestoneState.locked => (
        p.primary.withValues(alpha: 0.14),
        p.textSecondary,
        Icons.lock_rounded,
      ),
      MilestoneState.unlocked => (
        p.primary.withValues(alpha: 0.32),
        p.textPrimary,
        Icons.lock_open_rounded,
      ),
      MilestoneState.claimed => (p.success, p.onPrimary, Icons.check_rounded),
    };
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: KSpacing.xxs),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.sm,
            vertical: KSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: KCherryAmount(
            m.cherries,
            compact: true,
            size: 14,
            style: context.textStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(size: const Size(12, 6), painter: _Pointer(fill)),
        const SizedBox(height: 18),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: m.state == MilestoneState.claimed ? p.success : p.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: m.state == MilestoneState.locked
                  ? p.primary.withValues(alpha: 0.4)
                  : p.primary,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: m.state == MilestoneState.claimed
                ? p.onPrimary
                : p.primaryText,
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.inviteMilestoneFriends(m.friends),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.textStyles.caption.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

class _Pointer extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Pointer old) => old.color != color;
}

class _Friends extends StatelessWidget {
  const new({required this.invitees});

  final List<ReferralInvitee> invitees;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      key: InviteFriendsScreen.friendsKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.xl,
        KSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.inviteFriendsTitle, style: text.title),
          const SizedBox(height: KSpacing.sm),
          if (invitees.isEmpty)
            Text(
              l10n.inviteNoFriends,
              key: InviteFriendsScreen.noFriendsKey,
              style: text.body.copyWith(color: p.textSecondary),
            )
          else
            for (final f in invitees)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: p.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: p.primaryText,
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyStrong,
                          ),
                          Text(
                            KFormat.date(f.joinedAt, localeTag),
                            style: text.caption.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (f.firstRecharge) ...[
                      Text(
                        l10n.inviteRecharged,
                        style: text.caption.copyWith(color: p.success),
                      ),
                      const SizedBox(width: KSpacing.sm),
                    ],
                    _StatusChip(status: f.status),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const new({required this.status});

  final ReferralStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final (String label, Color color) = switch (status) {
      ReferralStatus.pending => (l10n.inviteStatusPending, p.warning),
      ReferralStatus.qualified => (l10n.inviteStatusQualified, p.success),
      ReferralStatus.rejected => (l10n.inviteStatusRejected, p.textSecondary),
      ReferralStatus.voided => (l10n.inviteStatusVoid, p.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        label,
        style: context.textStyles.caption.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  const new({
    required this.onWhatsapp,
    required this.onShare,
    required this.onCopyLink,
  });

  final VoidCallback onWhatsapp;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    Widget item(
      Key key,
      IconData icon,
      Color color,
      String label,
      VoidCallback onTap,
    ) => Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Material(
      key: InviteFriendsScreen.shareBarKey,
      color: p.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          child: Row(
            children: [
              item(
                InviteFriendsScreen.whatsappKey,
                Icons.chat_rounded,
                const Color(0xFF1E8E4F),
                l10n.inviteShareWhatsapp,
                onWhatsapp,
              ),
              item(
                InviteFriendsScreen.shareKey,
                Icons.ios_share_rounded,
                KBrandColors.red600,
                l10n.inviteShareMore,
                onShare,
              ),
              item(
                InviteFriendsScreen.copyLinkKey,
                Icons.link_rounded,
                const Color(0xFF4A5568),
                l10n.inviteShareCopyLink,
                onCopyLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesSheet extends StatelessWidget {
  const new({required this.referral});

  final MyReferral referral;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final r = referral.rules;
    final rules = [
      l10n.inviteRuleSignup(_n(r.inviterSignupCherries)),
      if (r.inviteeSignupCherries > 0)
        l10n.inviteRuleInvitee(_n(r.inviteeSignupCherries)),
      if (r.firstRechargeBps > 0)
        l10n.inviteRuleRecharge(
          KFormat.bidiIsolate(referralPercent(r.firstRechargeBps)),
        ),
      // The three rewards first (owner 2026-11-01): sign-up, first
      // recharge, milestones.
      if (referral.milestones.isNotEmpty)
        l10n.inviteRuleMilestones(
          referralMilestoneList(l10n, referral.milestones),
        ),
      l10n.inviteRuleHold(_n(r.holdHours)),
      l10n.inviteRuleFair,
      if (r.dailySignupCap > 0) l10n.inviteRuleCap(_n(r.dailySignupCap)),
      l10n.inviteRuleLater(_n(r.applyWindowDays)),
      l10n.inviteRuleWithdraw,
      l10n.inviteRuleClawback,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.inviteRulesTitle, style: text.title),
            const SizedBox(height: KSpacing.md),
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The bullet: a dot drawn in the text colour.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 9,
                        end: KSpacing.sm,
                      ),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: text.body.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(rule, style: text.body)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
