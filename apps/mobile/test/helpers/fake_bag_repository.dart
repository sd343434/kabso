// In-memory bag (CP-019; D171: only owned items, expiry, sending; tests
// only). Every call is recorded in `calls`; a failure set in
// `failNext[method]` is thrown once by it.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

import '../fixtures/bag/bag_api_fixtures.dart';

class FakeBagRepository implements BagRepository {
  /// Owns [owned] (in catalogue order) and wears [worn]; [items] replaces
  /// the generated items (any category, expiry or source).
  new({
    List<String> owned = const ['bunny_royal'],
    this.worn = 'bunny_royal',
    this.ar = false,
    List<Map<String, Object?>>? items,
  }) : owned = List.of(owned),
       items = items == null ? null : List.of(items);

  final List<String> owned;
  final List<Map<String, Object?>>? items;
  String? worn;
  final bool ar;

  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};

  /// What `send` returns (its recipient), set by the test.
  Map<String, Object?>? sendResult;

  /// D186: `GET /me/host-frame` (by default: not an agency host). A style
  /// choice updates it (and, while [hostFrame]'s `active`, gives or swaps
  /// the frame in [items]).
  Map<String, Object?> hostFrameJson = const {
    'agencyHost': false,
    'active': false,
    'liveDays': 0,
    'liveSeconds': 0,
    'style': null,
    'styleFrom': null,
    'canChoose': false,
    'frame': null,
    'rule': {'minDays': 7, 'minHours': 10, 'windowDays': 30},
  };

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
    if (items case final list?) {
      return [
        for (final i in list)
          BagItem.fromJson({...i, 'equipped': i['code'] == worn}),
      ];
    }
    return [
      for (final code in bagCatalogueCodes)
        if (owned.contains(code))
          BagItem.fromJson(bagItemJson(code, ar: ar, equipped: code == worn)),
    ];
  }

  @override
  Future<BagEquipped> setEquipped(String category, String? code) async {
    _record('setEquipped:${code ?? 'null'}');
    worn = code;
    return BagEquipped.fromJson(bagEquippedJson(code, ar: ar));
  }

  @override
  Future<HostFrame> hostFrame() async {
    _record('hostFrame');
    return HostFrame.fromJson(hostFrameJson);
  }

  @override
  Future<HostFrame> setHostFrameStyle(HostFrameStyle style) async {
    _record('setHostFrameStyle:${style.wire}');
    final active = hostFrameJson['active'] == true;
    final old = items
        ?.where((i) => i['source'] == 'HOST_ACTIVE')
        .map((i) => i['code'])
        .firstOrNull;
    final wasWorn = old != null && worn == old;
    if (active) {
      items?.removeWhere((i) => i['source'] == 'HOST_ACTIVE');
      items?.insert(0, {
        'code': style.assetKey,
        'category': 'AVATAR_FRAME',
        'name': style == HostFrameStyle.blue
            ? (ar ? 'إطار المضيف الأزرق' : 'Blue host frame')
            : (ar ? 'إطار المضيف الوردي' : 'Pink host frame'),
        'assetKey': style.assetKey,
        'acquiredAt': '2026-10-30T08:00:00.000Z',
        'source': 'HOST_ACTIVE',
        'expiresAt': null,
        'giftedBy': null,
        'transferable': false,
      });
      if (wasWorn) worn = style.assetKey;
    }
    hostFrameJson = {
      ...hostFrameJson,
      'style': style.wire,
      'styleFrom': 'CHOICE',
      'frame': active
          ? {
              'code': style.assetKey,
              'assetKey': style.assetKey,
              'equipped': wasWorn,
            }
          : null,
    };
    return HostFrame.fromJson(hostFrameJson);
  }

  @override
  Future<BagTransfer> send({
    required String code,
    required String username,
    int? days,
  }) async {
    _record('send:$code:$username:${days ?? 'all'}');
    if (days == null) {
      owned.remove(code);
      items?.removeWhere((i) => i['code'] == code);
      if (worn == code) worn = null;
    }
    return BagTransfer.fromJson(
      sendResult ??
          bagTransferJson(
            code,
            days: days,
            ar: ar,
            recipient: {
              'id': '0192e4a0-7c1d-7000-8000-0000000000b0',
              'username': username,
              'displayName': username,
              'avatarUrl': null,
            },
          ),
    );
  }
}
