import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';

/// v1.68-live (D273, §10.96.6): the caller's «فريق كابسو» state — the roles,
/// the tools' capabilities, the authenticator and the shift. Read when a
/// staff surface opens (the Me tab's «فريق كابسو», a live's «أدوات فريق
/// كابسو»); never for other accounts. D286 (v1.76-live): no step-up any more —
/// the tools open as soon as the role is held.
class StaffStatusController extends AsyncNotifier<StaffStatus> {
  StaffRepository get _repo => ref.read(staffRepositoryProvider);

  @override
  Future<StaffStatus> build() => ref.watch(staffRepositoryProvider).status();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.status);
  }

  /// D286 (§10.96.14; owner: «عندما يقوم المشرف بالعمل يتم تفعيل زر
  /// مناوبة»): the server switched the shift on for staff work (entering a
  /// live as staff, a staff tool, «بثوثي») — the switch shows it at once.
  void staffWorked() {
    final now = state.value;
    if (now != null && now.isStaff && !now.onShift) {
      state = AsyncData(now.copyWith(onShift: true));
    }
  }

  Future<void> setShift({required bool onShift}) async {
    final shift = await _repo.setShift(onShift: onShift);
    final now = state.value;
    if (now != null) state = AsyncData(now.copyWith(onShift: shift));
  }
}

final AsyncNotifierProvider<StaffStatusController, StaffStatus>
staffStatusProvider = AsyncNotifierProvider<StaffStatusController, StaffStatus>(
  StaffStatusController.new,
);

/// D273 (owner: «دخول ظاهر» or «مراقبة خفية», remembered per session): how
/// this app run enters lives as staff; null until chosen.
class StaffWatchModeController extends Notifier<StaffVisibility?> {
  @override
  StaffVisibility? build() => null;

  // A method reads better at the call site («choose visible»).
  // ignore: use_setters_to_change_properties
  void choose(StaffVisibility mode) => state = mode;
}

final NotifierProvider<StaffWatchModeController, StaffVisibility?>
staffWatchModeProvider =
    NotifierProvider<StaffWatchModeController, StaffVisibility?>(
      StaffWatchModeController.new,
    );

/// «بثوثي»: the lives assigned to the caller.
final FutureProvider<List<StaffLive>> staffLivesProvider =
    FutureProvider.autoDispose<List<StaffLive>>(
      (ref) => ref.watch(staffRepositoryProvider).myLives(),
    );

/// A live's reports for the staff tools.
final FutureProviderFamily<List<StaffReport>, String> staffReportsProvider =
    FutureProvider.autoDispose.family<List<StaffReport>, String>(
      (ref, roomId) => ref.watch(staffRepositoryProvider).reports(roomId),
    );

/// v1.78-live (D288, §10.101): the «بلاغات» row's unresolved count — read when
/// the Me tab shows the row, every [refreshEvery] while it is on screen,
/// after «تم حله», and when a `STAFF_REPORT_NEW` push arrives. Never throws
/// to the row: an error reads as no badge.
class StaffOpenReportsController extends AsyncNotifier<int> {
  static const refreshEvery = Duration(seconds: 60);

  Timer? _timer;

  @override
  Future<int> build() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    ref.onDispose(() => _timer?.cancel());
    return ref.watch(staffRepositoryProvider).openReportsCount();
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(
      ref.read(staffRepositoryProvider).openReportsCount,
    );
    // A failed read (offline) keeps the last count: no flicker.
    if (next.hasValue || !state.hasValue) state = next;
  }
}

final AsyncNotifierProvider<StaffOpenReportsController, int>
staffOpenReportsProvider =
    AsyncNotifierProvider.autoDispose<StaffOpenReportsController, int>(
      StaffOpenReportsController.new,
    );

/// D288: «بلاغات» — the first page of one tab of the shared queue.
final FutureProviderFamily<SharedReportPage, SharedReportTab>
staffSharedReportsProvider = FutureProvider.autoDispose
    .family<SharedReportPage, SharedReportTab>(
      (ref, tab) => ref.watch(staffRepositoryProvider).sharedReports(tab),
    );
