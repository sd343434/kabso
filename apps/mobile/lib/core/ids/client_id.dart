import 'dart:math';

final Random _random = Random.secure();

/// A random UUID v4 for a spending request's `clientId` (CONVENTIONS §3:
/// unique per caller; a retry with the same id is never charged twice).
/// Keep one per user intent and reuse it when retrying that intent.
String newClientId() {
  String hex(int n) =>
      List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
  final variant = (8 + _random.nextInt(4)).toRadixString(16);
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
}
