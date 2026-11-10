// D356 (CONVENTIONS §10.152): the event page preview the panel embeds — the
// app's real `EventDetailScreen` (so a designed event draws `EventDesignedPage`
// and anything else today's page, exactly as on a phone), fed from the draft
// the panel posts instead of the API, with SAMPLE leaderboards. No sign-in, no
// API, no navigation away (the only route is the page; a link elsewhere lands
// back on it).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:kabso_live/preview/event_preview_protocol.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The latest request (null until the panel's first message).
class EventPreviewController extends ValueNotifier<PreviewRequest?> {
  new() : super(null);
}

/// The draft as the page's repository: the event and the panel's SAMPLE
/// boards, as posted.
class PreviewProgramsRepository implements ProgramsRepository {
  PreviewRequest? request;

  PreviewRequest get _r => request ?? (throw StateError('no preview yet'));

  @override
  Future<EventDetail> event(String eventId) async => _r.event;

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) async {
    final e = _r.event;
    final kind =
        EventBoardKind.fromWire(board) ??
        (e.boards.isEmpty ? EventBoardKind.senders : e.boards.first.kind);
    final info = e.boards.where((b) => b.kind == kind).firstOrNull;
    return _r.leaderboards[kind] ??
        previewEmptyBoard(
          kind,
          ended: _r.state == PreviewState.ended,
          minPoints: info?.minPoints ?? 0,
        );
  }

  // The page reads only the event and its boards; anything else is a bug
  // in the preview, not a reason to call the API.
  @override
  Never noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'The event preview has no ${invocation.memberName}',
  );
}

class _PreviewLanguage extends LanguageController {
  new(this._initial);

  final AppLanguage _initial;

  @override
  AppLanguage build() => _initial;

  // A method, not a setter: the page reads the language, never sets it.
  // ignore: use_setters_to_change_properties
  void show(AppLanguage language) => state = language;
}

/// The preview's app: the theme, the language and reduce-motion the panel
/// asked for, the page, and a «معاينة · بيانات تجريبية» label.
class EventPreviewApp extends StatefulWidget {
  const new({
    required this.controller,
    required this.prefs,
    this.onRendered,
    super.key,
  });

  final EventPreviewController controller;
  final SharedPreferences prefs;

  /// After each request is on screen (the bridge tells the panel).
  final void Function(PreviewRequest request, {required bool designed})?
  onRendered;

  static const waitingKey = Key('event.preview.waiting');
  static const labelKey = Key('event.preview.sampleLabel');

  @override
  State<EventPreviewApp> createState() => _EventPreviewAppState();
}

class _EventPreviewAppState extends State<EventPreviewApp> {
  late final PreviewProgramsRepository _repo = PreviewProgramsRepository();
  late final _PreviewLanguage _language = _PreviewLanguage(
    widget.controller.value?.language ?? AppLanguage.ar,
  );
  late final ProviderContainer _container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(widget.prefs),
      currentUserProvider.overrideWithValue(null),
      programsRepositoryProvider.overrideWithValue(_repo),
      languageControllerProvider.overrideWith(() => _language),
    ],
  );
  late final GoRouter _router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const _PreviewPage())],
    // Nothing leaves the page: «اذهب إلى البث» and friends land back here.
    redirect: (_, state) => state.uri.path == '/' ? null : '/',
    errorBuilder: (_, _) => const _PreviewPage(),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onRequest);
    _onRequest();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onRequest);
    _router.dispose();
    _container.dispose();
    super.dispose();
  }

  void _onRequest() {
    final r = widget.controller.value;
    if (r == null) return;
    _repo.request = r;
    if (_container.read(languageControllerProvider) != r.language) {
      _language.show(r.language);
    }
    _container
      ..invalidate(eventDetailProvider)
      ..invalidate(eventBoardProvider);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.value?.seq != r.seq) return;
      final designed = r.event.isGiftEvent && r.event.design != null;
      widget.onRendered?.call(r, designed: designed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.controller.value;
    final locale = (r?.language ?? AppLanguage.ar).locale;
    return UncontrolledProviderScope(
      container: _container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        locale: locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        themeMode: (r?.dark ?? true) ? ThemeMode.dark : ThemeMode.light,
        theme: buildAppTheme(brightness: Brightness.light, locale: locale),
        darkTheme: buildAppTheme(brightness: Brightness.dark, locale: locale),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  (r?.reduceMotion ?? false) || media.disableAnimations,
            ),
            child: _PreviewScope(request: r, child: child!),
          );
        },
      ),
    );
  }
}

class _PreviewScope extends InheritedWidget {
  const new({required this.request, required super.child});

  final PreviewRequest? request;

  static PreviewRequest? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PreviewScope>()?.request;

  @override
  bool updateShouldNotify(_PreviewScope old) => old.request != request;
}

class _PreviewPage extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final r = _PreviewScope.of(context);
    if (r == null) {
      return const Scaffold(
        key: EventPreviewApp.waitingKey,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: EventDetailScreen(
            // The page picks its first tab when it opens (REWARDS before
            // BOARDS opens on the rewards): a new order opens it afresh, as a
            // phone would; any other change redraws in place.
            key: ValueKey(previewPageKey(r)),
            eventId: r.event.id,
          ),
        ),
        // At the top, between the bar's buttons: the bottom is the «مركزي»
        // bar's place.
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + KSpacing.xs,
          start: 0,
          end: 0,
          child: IgnorePointer(
            child: Center(
              child: DecoratedBox(
                key: EventPreviewApp.labelKey,
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                    vertical: KSpacing.xs,
                  ),
                  child: Text(
                    // The panel's preview only: never shown in the app.
                    context.l10n.eventPreviewSampleLabel,
                    style: context.textStyles.caption.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The page's identity in the preview: the event and its visible sections'
/// order (see `_PreviewPage`).
String previewPageKey(PreviewRequest r) {
  final d = r.event.design;
  return [
    r.event.id,
    if (d == null) 'today' else ...d.visibleSections.map((s) => s.wire),
  ].join('/');
}
