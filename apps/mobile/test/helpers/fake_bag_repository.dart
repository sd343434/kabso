// In-memory CP-019 bag (tests only). Every call is recorded in `calls`; a
// failure set in `failNext[method]` is thrown once by it.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

import '../fixtures/bag/bag_api_fixtures.dart';

class FakeBagRepository implements BagRepository {
  /// Owns [owned] (in catalogue order) and wears [worn].
  new({
    List<String> owned = const ['bunny_royal'],
    this.worn = 'bunny_royal',
    this.ar = false,
  }) : owned = List.of(owned);

  final List<String> owned;
  String? worn;
  final bool ar;

  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};

  void _record(String call) {
    calls.add(call);
    final name = call.split(':').first;
    if (failNext.remove(name) case final failure?) throw failure;
  }

  @override
  Future<List<BagCatalogueItem>> catalogue({BagCategory? category}) async {
    _record('catalogue');
    return [
      for (final code in bagCatalogueCodes)
        BagCatalogueItem.fromJson(bagCatalogueItemJson(code, ar: ar)),
    ];
  }

  @override
  Future<List<BagItem>> myBag({BagCategory? category}) async {
    _record('myBag');
    return [
      for (final code in bagCatalogueCodes)
        if (owned.contains(code))
          BagItem.fromJson(bagItemJson(code, ar: ar, equipped: code == worn)),
    ];
  }

  @override
  Future<BagEquipped> setEquipped(BagCategory category, String? code) async {
    _record('setEquipped:${code ?? 'null'}');
    worn = code;
    return BagEquipped.fromJson(bagEquippedJson(code, ar: ar));
  }
}
