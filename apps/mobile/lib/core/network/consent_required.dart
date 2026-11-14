import 'package:flutter_riverpod/flutter_riverpod.dart';

/// v1.66-social (D198, §10.61.2): whether the signed-in person must accept a
/// new version of the terms or the privacy policy before using the app. Set
/// when `GET /me/consents` lists something after sign-in, or when any call
/// answers 428 `CONSENT_REQUIRED` (`ConsentRequiredInterceptor`); cleared
/// when they accept or sign out. While it is true the router keeps the
/// person on the consent screen (only the data export and the account
/// deletion stay reachable).
class ConsentRequiredController extends Notifier<bool> {
  @override
  bool build() => false;

  bool get value => state;

  set value(bool required) => state = required;
}

final NotifierProvider<ConsentRequiredController, bool>
consentRequiredProvider = NotifierProvider<ConsentRequiredController, bool>(
  ConsentRequiredController.new,
);
