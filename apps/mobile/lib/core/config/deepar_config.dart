/// D144: the DeepAR licence key, from `--dart-define=DEEPAR_LICENSE_ANDROID`
/// (CI: the `DEEPAR_LICENSE_ANDROID` secret; locally:
/// `--dart-define-from-file=deepar.local.json`, git-ignored).
///
/// It is a client key: DeepAR binds it to the app's package name and it ends
/// up inside the APK like any SDK key — but it is billed per monthly active
/// user, so it stays out of the public repository. Empty (the default)
/// means AR effects are off; colour filters do not need it.
abstract final class DeepArConfig {
  static const String licenseAndroid = String.fromEnvironment(
    'DEEPAR_LICENSE_ANDROID',
  );
}
