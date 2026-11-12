// D376 «الحالة»: the status packs as `GET /status-packs` answers them
// (contract v1.130-social), for tests and goldens.

import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_repository.dart';

/// A fixed "now" for the store (the pack's end is shown as a date).
final DateTime statusFixtureNow = DateTime.utc(2027, 5, 5, 10);

/// The «المميزة» offer: 100 000 coins for 30 days, held until [heldUntil].
StatusPackList statusPackListFixture({
  DateTime? heldUntil,
  int coins = 250000,
  bool priced = true,
}) => StatusPackList(
  packs: [
    StatusPackOffer(
      id: 'premium',
      emojiIds: [
        for (final e in StatusCatalogue.pack('premium')!.emojis) e.id,
      ],
      options: priced
          ? const [StatusPackOption(days: 30, coins: 100000)]
          : const [],
      expiresAt: heldUntil,
    ),
  ],
  coins: coins,
);

/// The JSON of [statusPackListFixture] (repository tests).
Map<String, Object?> statusPackListJson({String? expiresAt, int coins = 0}) => {
  'data': [
    {
      'id': 'premium',
      'emojiIds': ['premium.eagle', 'premium.crown'],
      'options': [
        {'days': 30, 'coins': 100000},
      ],
      'expiresAt': expiresAt,
    },
  ],
  'coins': coins,
};
