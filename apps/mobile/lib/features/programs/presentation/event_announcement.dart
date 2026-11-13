import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/programs/data/event_announcements_repository.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What the person chose on a full-screen announcement.
enum EventAnnouncementChoice {
  /// «شارك الآن» / «عرض النتائج»: the event page.
  open,

  /// «لاحقاً», ✕ or back.
  later,
}

/// v1.105-social (D340, CONVENTIONS §10.134.2): one full-screen event
/// announcement — «بدأت فعالية جديدة» (the event's art, title, dates and top
/// prize, «شارك الآن») or «مبروك» (the place won and the prize, «عرض
/// النتائج»), with «لاحقاً». The event's own art when it has some, else
/// Kabso's (the owner's gift box, Kabso's rank shields) — never third-party
/// art. Its parts drift gently unless the system asks for reduced motion.
class EventAnnouncementView extends StatefulWidget {
  const new({required this.announcement, required this.onChoice, super.key});

  final EventAnnouncement announcement;
  final ValueChanged<EventAnnouncementChoice> onChoice;

  static const viewKey = Key('eventAnnouncement.view');
  static const openKey = Key('eventAnnouncement.open');
  static const laterKey = Key('eventAnnouncement.later');
  static const closeKey = Key('eventAnnouncement.close');
  static const artKey = Key('eventAnnouncement.art');

  /// Tests and goldens: the event's pictures (no network).
  @visibleForTesting
  static ImageProvider Function(String url)? imageForTesting;

  static ImageProvider image(String url) =>
      imageForTesting?.call(url) ?? GiftEventBackdrop.image(url);

  @override
  State<EventAnnouncementView> createState() => _EventAnnouncementViewState();
}

class _EventAnnouncementViewState extends State<EventAnnouncementView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift
        ..stop()
        ..value = 0.5;
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final a = widget.announcement;
    final win = a.kind == EventAnnouncementKind.win;
    final gold = programGold(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final height = MediaQuery.sizeOf(context).height;
    final double artHeight = math.min(height * 0.42, 360);

    final content = <Widget>[
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.md,
            vertical: KSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: gold),
          ),
          child: Text(
            win
                ? eventBoardLabel(l10n, a.board ?? EventBoardKind.senders)
                : l10n.eventsAnnounceStarted,
            style: t.label.copyWith(color: gold),
          ),
        ),
      ),
      const SizedBox(height: KSpacing.md),
      if (win) ...[
        Text(
          l10n.eventsAnnounceWinTitle,
          textAlign: TextAlign.center,
          style: t.display.copyWith(color: gold),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.eventsAnnounceWinBody('${a.rank ?? ''}', a.event.title),
          textAlign: TextAlign.center,
          style: t.title.copyWith(color: p.textPrimary),
        ),
      ] else ...[
        Text(
          a.event.title,
          textAlign: TextAlign.center,
          style: t.headline.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          eventDates(l10n, a.event, localeTag),
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: p.textSecondary),
        ),
      ],
      if (a.prize.isNotEmpty) ...[
        const SizedBox(height: KSpacing.lg),
        Container(
          padding: const EdgeInsets.all(KSpacing.md),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(KRadius.lg),
            border: Border.all(color: gold.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Text(
                win
                    ? l10n.eventsAnnounceYourPrize
                    : l10n.eventsAnnounceTopPrize,
                style: t.label.copyWith(color: gold),
              ),
              const SizedBox(height: KSpacing.xs),
              EventPrizeChips(a.prize),
            ],
          ),
        ),
      ],
    ];

    return Material(
      key: EventAnnouncementView.viewKey,
      color: p.background,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: win ? l10n.eventsAnnounceWinTitle : l10n.eventsAnnounceStarted,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: artHeight,
                  width: double.infinity,
                  child: _Art(announcement: a, drift: _drift),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              KSpacing.lg,
                              KSpacing.sm,
                              KSpacing.lg,
                              KSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: content,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            KSpacing.lg,
                            0,
                            KSpacing.lg,
                            KSpacing.sm,
                          ),
                          child: Column(
                            children: [
                              KButton(
                                key: EventAnnouncementView.openKey,
                                label: win
                                    ? l10n.eventsAnnounceResults
                                    : l10n.eventsAnnounceJoin,
                                onPressed: () => widget.onChoice(
                                  EventAnnouncementChoice.open,
                                ),
                              ),
                              const SizedBox(height: KSpacing.xs),
                              KButton(
                                key: EventAnnouncementView.laterKey,
                                label: l10n.eventsAnnounceLater,
                                variant: KButtonVariant.ghost,
                                onPressed: () => widget.onChoice(
                                  EventAnnouncementChoice.later,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.xs),
                  child: IconButton(
                    key: EventAnnouncementView.closeKey,
                    tooltip: l10n.eventsAnnounceClose,
                    onPressed: () =>
                        widget.onChoice(EventAnnouncementChoice.later),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x66000000),
                      foregroundColor: const Color(0xFFFFFFFF),
                      minimumSize: const Size.square(KSizes.minTouchTarget),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top of the announcement: the event's background (else its banner,
/// else Kabso's red) fading into the page, and over it the event's title art
/// or Kabso's own picture (the gift box; a rank shield for a win).
class _Art extends StatelessWidget {
  const new({required this.announcement, required this.drift});

  final EventAnnouncement announcement;
  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = announcement;
    final win = a.kind == EventAnnouncementKind.win;
    final background = a.backgroundUrl ?? a.event.bannerUrl;
    final rank = a.rank ?? 0;
    final brand = win && rank >= 1 && rank <= 3
        ? 'assets/leaderboard/rank_shield_$rank.webp'
        : KabsoArt.giftBox.asset;
    final hero = !win && a.titleUrl != null
        ? Image(
            image: EventAnnouncementView.image(a.titleUrl!),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(brand, fit: BoxFit.contain),
          )
        : Image.asset(brand, fit: BoxFit.contain);
    return ExcludeSemantics(
      key: EventAnnouncementView.artKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: KBrandColors.gradientLive,
              ),
            ),
          ),
          if (background != null)
            Image(
              image: EventAnnouncementView.image(background),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // The art fades into the page (light or dark).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.55, 0.96, 1],
                colors: [
                  const Color(0x33000000),
                  p.background.withValues(alpha: 0),
                  p.background,
                  p.background,
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.xxl,
                KSpacing.xl,
                KSpacing.md,
              ),
              child: AnimatedBuilder(
                animation: drift,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, (drift.value - 0.5) * 12),
                  child: Transform.scale(
                    scale: 0.98 + drift.value * 0.04,
                    child: child,
                  ),
                ),
                child: hero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [announcement] full screen over [navigator]'s top route: fades and
/// grows in (instant when the system asks for reduced motion); back closes
/// it as «لاحقاً».
Future<EventAnnouncementChoice> showEventAnnouncement(
  NavigatorState navigator,
  EventAnnouncement announcement,
) async {
  final reduce =
      MediaQuery.maybeDisableAnimationsOf(navigator.context) ?? false;
  final choice = await navigator.push<EventAnnouncementChoice>(
    PageRouteBuilder<EventAnnouncementChoice>(
      opaque: false,
      barrierColor: const Color(0x99000000),
      fullscreenDialog: true,
      transitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 320),
      reverseTransitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => EventAnnouncementView(
        announcement: announcement,
        onChoice: (c) => Navigator.of(context).pop(c),
      ),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: KMotion.standard,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
  return choice ?? EventAnnouncementChoice.later;
}

/// v1.105-social (D340, §10.134.2): asks for the person's announcements once
/// signed in, on each return to the foreground and when a live is left, and
/// shows them one at a time — never while the person hosts a live (the
/// go-live screen or its minimized window) or watches one (a live room or
/// its minimized window): they wait until the live is left. Each one shown is
/// marked seen when closed; «شارك الآن» / «عرض النتائج» opens the event.
class EventAnnouncementGate extends ConsumerStatefulWidget {
  const new({required this.router, super.key});

  final GoRouter router;

  @override
  ConsumerState<EventAnnouncementGate> createState() =>
      _EventAnnouncementGateState();
}

class _EventAnnouncementGateState extends ConsumerState<EventAnnouncementGate> {
  final List<EventAnnouncement> _queue = [];

  /// Ids shown (or being shown) in this run: never shown twice even if the
  /// «seen» call fails (the server lists it again on the next run).
  final Set<String> _done = {};
  AppLifecycleListener? _lifecycle;
  bool _fetching = false;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_fetch()));
    widget.router.routerDelegate.addListener(_onRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_fetch()));
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  /// A route change: once the navigator has its new pages (a route pushed
  /// before would sit under them, or be dropped with the page it was on).
  void _onRoute() {
    if (_queue.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  /// In a live: hosting (full screen or minimized) or watching.
  bool get _busy {
    if (ref.read(liveMinimizedProvider) ||
        ref.read(liveViewerMinimizedProvider) != null) {
      return true;
    }
    final String path;
    try {
      // The top route, pushed ones included (a live room is pushed).
      path = widget.router.state.matchedLocation;
    } on Object {
      return true;
    }
    // Not over the splash or the sign-in screens either.
    return path == AppRoutes.goLive ||
        path.startsWith('${AppRoutes.home}/room/') ||
        path == AppRoutes.splash ||
        path.startsWith('/auth/');
  }

  Future<void> _fetch() async {
    if (!mounted || _fetching || ref.read(currentUserProvider) == null) return;
    _fetching = true;
    try {
      final list = await ref
          .read(eventAnnouncementsRepositoryProvider)
          .pending();
      if (!mounted) return;
      for (final a in list) {
        if (_done.contains(a.id) || _queue.any((q) => q.id == a.id)) continue;
        _queue.add(a);
      }
    } on Object {
      // An announcement is never a reason to show an error.
    } finally {
      _fetching = false;
    }
    _maybeShow();
  }

  void _maybeShow() {
    if (!mounted || _showing || _queue.isEmpty || _busy) return;
    final navigator = widget.router.routerDelegate.navigatorKey.currentState;
    if (navigator == null) return;
    final next = _queue.removeAt(0);
    _done.add(next.id);
    _showing = true;
    unawaited(_show(navigator, next));
  }

  Future<void> _show(NavigatorState navigator, EventAnnouncement a) async {
    final repo = ref.read(eventAnnouncementsRepositoryProvider);
    EventAnnouncementChoice choice;
    try {
      choice = await showEventAnnouncement(navigator, a);
    } on Object {
      choice = EventAnnouncementChoice.later;
    }
    unawaited(() async {
      try {
        await repo.markSeen(a.id);
      } on Object {
        // Listed again next time: shown once more at worst.
      }
    }());
    _showing = false;
    if (!mounted) return;
    if (choice == EventAnnouncementChoice.open) {
      unawaited(widget.router.push(AppRoutes.event(a.event.id)));
    }
    // The next one after this frame (the route has settled).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  Widget build(BuildContext context) {
    // Signed in (again, or as someone else): ask.
    ref.listen(currentUserProvider.select((u) => u?.id), (before, now) {
      if (now == null) {
        _queue.clear();
        _done.clear();
      } else if (now != before) {
        unawaited(_fetch());
      }
    });
    // Leaving a minimized live: maybe now.
    ref
      ..listen(liveMinimizedProvider, (_, _) => _maybeShow())
      ..listen(liveViewerMinimizedProvider, (_, _) => _maybeShow());
    return const SizedBox.shrink();
  }
}
