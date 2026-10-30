import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';

// Names (tasks, perks, events) are localized by the server, so a language
// change reloads them; a new signed-in person reloads everything.

/// The caller's Task Center (`GET /me/tasks`, D166).
final FutureProvider<MyTasks> myTasksProvider = FutureProvider.autoDispose((
  ref,
) {
  ref
    ..watch(languageControllerProvider)
    ..watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(programsRepositoryProvider).tasks();
});

/// The caller's SVIP status (`GET /me/svip`, D166).
final FutureProvider<SvipStatus> mySvipProvider = FutureProvider.autoDispose((
  ref,
) {
  ref
    ..watch(languageControllerProvider)
    ..watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(programsRepositoryProvider).svip();
});

/// One Event Center list: a tab, and for the calendar its month
/// (`YYYY-MM`).
typedef EventListKey = ({EventTab tab, String? month});

/// `GET /events?tab=&month=` (D166).
final FutureProviderFamily<EventList, EventListKey> eventListProvider =
    FutureProvider.autoDispose.family((ref, key) {
      ref.watch(languageControllerProvider);
      return ref
          .watch(programsRepositoryProvider)
          .events(key.tab, month: key.month);
    });

/// `GET /events/{eventId}` (D166).
final FutureProviderFamily<EventDetail, String> eventDetailProvider =
    FutureProvider.autoDispose.family((ref, id) {
      ref.watch(languageControllerProvider);
      return ref.watch(programsRepositoryProvider).event(id);
    });

/// `GET /events/{eventId}/leaderboard` (D166).
final FutureProviderFamily<EventLeaderboard, String> eventLeaderboardProvider =
    FutureProvider.autoDispose.family(
      (ref, id) => ref.watch(programsRepositoryProvider).leaderboard(id),
    );

/// The recharge packages (`GET /wallet/recharge-packages`, D166).
final FutureProvider<RechargeOffer> rechargeOfferProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(programsRepositoryProvider).rechargePackages(),
    );
