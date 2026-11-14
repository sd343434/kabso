// D356 (CONVENTIONS §10.152): the preview's window.postMessage bridge — the
// web implementation in `event_preview_bridge_web.dart`; elsewhere (VM tests,
// a phone) there is no parent window and nothing is listened to.
export 'event_preview_bridge_stub.dart'
    if (dart.library.js_interop) 'event_preview_bridge_web.dart';
