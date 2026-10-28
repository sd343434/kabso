import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the launch intro has finished (D63, D156: the launch video ended,
/// was skipped, could not play, or the reduced-motion still was shown). The
/// router keeps the splash until it has; after that the auth redirect
/// applies as before.
class SplashIntro extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashIntroProvider = NotifierProvider<SplashIntro, bool>(
  SplashIntro.new,
);
