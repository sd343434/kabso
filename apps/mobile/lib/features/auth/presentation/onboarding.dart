import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';

/// Whether this installation has shown the welcome screen (D65). The first
/// signed-out launch shows welcome, then join; every later one goes from
/// the splash straight to login.
class WelcomeSeen extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(PreferenceKeys.welcomeSeen) ??
      false;

  void markSeen() {
    if (state) return;
    state = true;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(PreferenceKeys.welcomeSeen, true),
    );
  }
}

final welcomeSeenProvider = NotifierProvider<WelcomeSeen, bool>(
  WelcomeSeen.new,
);
