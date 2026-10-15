import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/bootstrap.dart';

/// Run with e.g.
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`.
Future<void> main() => bootstrap(KabsoApp.new);
