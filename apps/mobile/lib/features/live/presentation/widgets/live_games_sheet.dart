import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D173 (owner: «ولا يوجد في الاثنين زر جوي ستيك الخاص بالألعاب»): the
/// games button of the viewer's video and audio bars (and the host's audio
/// bar) opens this sheet. There are no games yet — they wait for a game
/// provider — so the sheet says so honestly: the owner's controller art,
/// «الألعاب» and «الألعاب قريباً», with no game tiles that look playable.
Future<void> showLiveGamesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LiveGamesSheet(),
    );

/// The games sheet's body (see [showLiveGamesSheet]).
class LiveGamesSheet extends StatelessWidget {
  const new({super.key});

  /// The owner's colourful controller art (D141), as on the host's bar.
  static const art = 'assets/live_bar/bar_games.png';

  static const sheetKey = Key('live.gamesSheet');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    return SafeArea(
      key: sheetKey,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.md,
          KSpacing.lg,
          KSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x1F000000),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: KSpacing.lg),
            Image.asset(art, width: 64, height: 64, excludeFromSemantics: true),
            const SizedBox(height: KSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.liveGames,
                textAlign: TextAlign.center,
                style: t.title.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.liveGamesSoon,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.liveGamesSoonBody,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: soft),
            ),
          ],
        ),
      ),
    );
  }
}
