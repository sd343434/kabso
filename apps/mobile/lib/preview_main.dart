// D356 (CONVENTIONS §10.152): the entry of the event page preview bundle —
// `flutter build web -t lib/preview_main.dart` (infra/deploy/build-event-preview.sh,
// CI `event-preview-web`). Never part of the phone app: the APK and the IPA
// build `lib/main.dart`, which does not import this.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:kabso_live/preview/event_preview_app.dart';
import 'package:kabso_live/preview/event_preview_bridge.dart';
import 'package:kabso_live/preview/event_preview_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The page's text in the DOM (screen readers in the panel; the smoke test
  // reads it).
  SemanticsBinding.instance.ensureSemantics();
  final prefs = await SharedPreferences.getInstance();
  final controller = EventPreviewController();
  late final EventPreviewBridge bridge;
  bridge = EventPreviewBridge(
    onMessage: (m) => switch (m) {
      PreviewOk(:final request) => controller.value = request,
      PreviewInvalid(:final reason, :final seq) => bridge.send(
        previewReply(kPreviewError, seq: seq, reason: reason),
      ),
      PreviewIgnored() => null,
    },
  );
  runApp(
    EventPreviewApp(
      controller: controller,
      prefs: prefs,
      onRendered: (r, {required designed}) => bridge.send(
        previewReply(kPreviewRendered, seq: r.seq, designed: designed),
      ),
    ),
  );
  bridge.start();
}
