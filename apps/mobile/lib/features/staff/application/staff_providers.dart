import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';

/// v1.68-live (D273, §10.96.6): the caller's «فريق كابسو» state — the roles,
/// the tools' capabilities, the authenticator, this session's step-up and
/// the shift. Read when a staff surface opens (the Me tab's «فريق كابسو», a
/// live's «أدوات فريق كابسو»); never for other accounts.
class StaffStatusController extends AsyncNotifier<StaffStatus> {
  StaffRepository get _repo => ref.read(staffRepositoryProvider);

  @override
  Future<StaffStatus> build() => ref.watch(staffRepositoryProvider).status();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.status);
  }

  /// The step-up with the authenticator [code]; throws the server's refusal
  /// (a wrong code counts towards the panel lockout).
  Future<void> stepUp(String code) async {
    final until = await _repo.stepUp(code);
    final now = state.value;
    if (now != null) state = AsyncData(now.copyWith(stepUpUntil: until));
    await refresh();
  }

  /// «إنهاء»: this session's step-up ends.
  Future<void> endStepUp() async {
    await _repo.endStepUp();
    await refresh();
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
