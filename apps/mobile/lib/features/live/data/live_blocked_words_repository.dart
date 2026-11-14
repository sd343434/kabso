import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';

/// The most blocked words a host keeps (CONVENTIONS §10.14).
const int maxLiveBlockedWords = 100;

/// The longest blocked word or phrase, in characters.
const int maxLiveBlockedWordLength = 30;

/// The host's blocked words (CP-016 B, CONVENTIONS §10.14): the server masks
/// them in the chat of every live of this host. Every method throws an
/// `AppFailure`.
abstract interface class LiveBlockedWordsRepository {
  /// `GET /me/live-blocked-words`.
  Future<List<String>> get();

  /// `PUT /me/live-blocked-words`: replaces the list; returns it as saved
  /// (normalized, duplicates dropped).
  Future<List<String>> set(List<String> words);
}

class LiveBlockedWordsRepositoryImpl implements LiveBlockedWordsRepository {
  new(this._api);

  final Dio _api;

  static List<String> _words(Map<String, dynamic> body) => [
    for (final w in body['words']! as List<dynamic>) w as String,
  ];

  @override
  Future<List<String>> get() => guardApiCall(() async {
    final res = await _api.get<Map<String, dynamic>>('/me/live-blocked-words');
    return _words(res.data!);
  });

  @override
  Future<List<String>> set(List<String> words) => guardApiCall(() async {
    final res = await _api.put<Map<String, dynamic>>(
      '/me/live-blocked-words',
      data: {'words': words},
    );
    return _words(res.data!);
  });
}

final liveBlockedWordsRepositoryProvider = Provider<LiveBlockedWordsRepository>(
  (ref) => LiveBlockedWordsRepositoryImpl(ref.watch(apiDioProvider)),
);

/// The host's blocked words (refreshed after every change).
final FutureProvider<List<String>> liveBlockedWordsProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(liveBlockedWordsRepositoryProvider).get(),
    );
