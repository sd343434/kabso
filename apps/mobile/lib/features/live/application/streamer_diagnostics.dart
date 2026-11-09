import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/features/live/application/live_background.dart';

/// D346 (CONVENTIONS §10.145): the steps of starting a streamer live's
/// screen, in order. A failure names the step it happened at.
enum StreamerStep {
  /// The system's screen-capture consent (`requestCapture`).
  consent,

  /// The live's foreground service, started again with `mediaProjection`.
  service,

  /// The room, its token and the camera / microphone (the usual go-live).
  room,

  /// The screen capture itself (`captureCheck` + `getDisplayMedia`).
  capture,

  /// Publishing the screen track.
  publish,

  /// The game sound and the capture's watch (`attach`).
  attach,

  /// The system ended a running capture.
  stopped,
}

/// D346: what went wrong, each with its own message to the host — never one
/// generic fallback.
enum StreamerProblem {
  /// The person said no in Android's dialog.
  refused,

  /// The consent could not be asked or never showed (D262's codes).
  consentFailed,

  /// The live's foreground service with the `mediaProjection` type could not
  /// start, or was not running when the capture started (Android 10+
  /// refuses — or stops — a projection without it).
  serviceDenied,

  /// Android threw a SecurityException for the capture (a spent consent,
  /// a projection Android 14 does not allow).
  security,

  /// The system stopped a running capture because the service was gone.
  stoppedBySystem,

  /// This Android version cannot capture the screen.
  unsupportedOs,

  /// The capture could not start for another reason.
  captureFailed,

  /// The screen track could not be published.
  publishFailed,

  /// A step of the usual go-live (room, token, camera) — its own message
  /// is the usual one; the report is still offered.
  other,
}

/// D346: one failure of the streamer start: the [step], the [problem], the
/// exception's class and a short, scrubbed [detail] (no ids, no URLs, no
/// tokens), plus the short [code] shown in the message.
@immutable
class StreamerFailure {
  const new({
    required this.step,
    required this.problem,
    required this.errorClass,
    this.detail = '',
    this.code = 'unknown',
  });

  /// From the native `captureCheck`'s refusal [reason].
  factory blocked(String reason) => StreamerFailure(
    step: StreamerStep.capture,
    problem: switch (reason) {
      'no_service' => StreamerProblem.serviceDenied,
      'consent_used' => StreamerProblem.security,
      'unsupported_os' => StreamerProblem.unsupportedOs,
      'no_consent' => StreamerProblem.consentFailed,
      _ => StreamerProblem.captureFailed,
    },
    errorClass: 'CaptureBlocked',
    detail: reason,
    code: _code(reason),
  );

  /// From an [error] thrown at [step]: a PlatformException carries the Java
  /// exception (in its details) that says what Android refused.
  factory of(StreamerStep step, Object error) {
    if (error is StreamerStartException) return error.failure;
    final String text;
    var errorClass = error.runtimeType.toString();
    var code = _code(errorClass);
    if (error is PlatformException) {
      text = '${error.message ?? ''} ${error.details ?? ''}';
      final java = RegExp(r'((?:[a-z]+\.)+[A-Z]\w*(?:Exception|Error))')
          .firstMatch(text)
          ?.group(1);
      errorClass = java == null
          ? 'PlatformException(${error.code})'
          : 'PlatformException(${error.code}) $java';
      code = _code(java?.split('.').last ?? error.code);
    } else if (error is LiveBackgroundStartException) {
      text = '${error.error}';
      errorClass = 'LiveBackgroundStartException(${error.error.runtimeType})';
      code = _code(error.error.runtimeType);
    } else {
      text = '$error';
    }
    final lower = text.toLowerCase();
    final security =
        lower.contains('securityexception') ||
        errorClass.contains('SecurityException');
    final noService =
        lower.contains('foreground service') ||
        lower.contains('foregroundservice') ||
        lower.contains('foreground_service');
    final problem = switch (step) {
      StreamerStep.service => StreamerProblem.serviceDenied,
      StreamerStep.capture when noService => StreamerProblem.serviceDenied,
      StreamerStep.capture when security => StreamerProblem.security,
      // flutter_webrtc's own wording when its (second) consent was refused.
      StreamerStep.capture when lower.contains("didn't give permission") =>
        StreamerProblem.refused,
      StreamerStep.capture => StreamerProblem.captureFailed,
      StreamerStep.publish => StreamerProblem.publishFailed,
      StreamerStep.consent => StreamerProblem.consentFailed,
      _ => StreamerProblem.other,
    };
    return StreamerFailure(
      step: step,
      problem: problem,
      errorClass: errorClass,
      detail: scrub(error is PlatformException ? error.message ?? '' : text),
      code: code,
    );
  }

  final StreamerStep step;
  final StreamerProblem problem;
  final String errorClass;
  final String detail;
  final String code;

  /// The detail without anything personal or secret: URLs, e-mails, tokens,
  /// long numbers (ids) and paths go; at most 160 characters on one line.
  static String scrub(String raw) {
    var out = AppLogger.redact(raw.split('\n').first);
    out = out
        .replaceAll(RegExp(r'\b\w+://\S+'), '<url>')
        .replaceAll(RegExp(r'\S+@\S+\.\S+'), '<email>')
        .replaceAll(RegExp(r'(?:/[\w.\-]+){2,}'), '<path>')
        .replaceAll(RegExp(r'[A-Za-z0-9_\-]{24,}'), '<id>')
        .replaceAll(RegExp(r'\d{6,}'), '<n>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return out.length > 160 ? '${out.substring(0, 160)}…' : out;
  }

  static String _code(Object? raw) {
    final cleaned = '${raw ?? ''}'
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }

  @override
  bool operator ==(Object other) =>
      other is StreamerFailure &&
      other.step == step &&
      other.problem == problem &&
      other.errorClass == errorClass &&
      other.detail == detail &&
      other.code == code;

  @override
  int get hashCode => Object.hash(step, problem, errorClass, detail, code);

  @override
  String toString() =>
      'StreamerFailure(${step.name}, ${problem.name}, $errorClass)';
}

/// D346: thrown by the streamer steps so the go-live keeps the precise
/// failure (not a generic one).
class StreamerStartException implements Exception {
  const new(this.failure);
  final StreamerFailure failure;

  @override
  String toString() => 'StreamerStartException($failure)';
}

/// D346: the phone's facts for the report (`kabso_streamer` `diagnostics`).
/// No account, no ids: Android's version, the maker and model, the live
/// service's state.
@immutable
class StreamerDeviceInfo {
  const new({
    this.sdk,
    this.release,
    this.manufacturer,
    this.model,
    this.serviceForeground,
    this.serviceTypes = const [],
    this.consentHanded,
    this.consentUsed,
  });

  factory parse(Object? wire) {
    final m = wire is Map ? wire : const <Object?, Object?>{};
    String? s(String k) => m[k] is String ? m[k]! as String : null;
    bool? b(String k) => m[k] is bool ? m[k]! as bool : null;
    return StreamerDeviceInfo(
      sdk: m['sdk'] is int ? m['sdk']! as int : null,
      release: s('release'),
      manufacturer: s('manufacturer'),
      model: s('model'),
      serviceForeground: b('serviceForeground'),
      serviceTypes: [
        for (final t
            in (m['serviceTypes'] is List
                ? m['serviceTypes']! as List
                : const []))
          if (t is String) t,
      ],
      consentHanded: b('consentHanded'),
      consentUsed: b('consentUsed'),
    );
  }

  final int? sdk;
  final String? release;
  final String? manufacturer;
  final String? model;
  final bool? serviceForeground;
  final List<String> serviceTypes;
  final bool? consentHanded;
  final bool? consentUsed;
}

/// D346: the short text the host copies with «نسخ تقرير المشكلة» and pastes
/// to us. English keys (we read it), one fact per line, no personal data.
String streamerReport({
  required StreamerFailure failure,
  required String appVersion,
  required StreamerDeviceInfo device,
  required List<String> trail,
  required DateTime at,
}) {
  String yn({required bool? v}) => v == null ? '?' : (v ? 'yes' : 'no');
  final types = device.serviceTypes.isEmpty
      ? 'none'
      : device.serviceTypes.join('|');
  final service = yn(v: device.serviceForeground);
  final handed = yn(v: device.consentHanded);
  final used = yn(v: device.consentUsed);
  final android = device.release == null && device.sdk == null
      ? '?'
      : '${device.release ?? '?'} (SDK ${device.sdk ?? '?'})';
  final app = appVersion.replaceAll(RegExp(r'[^\w.+\-]'), '');
  final model = [
    device.manufacturer,
    device.model,
  ].whereType<String>().map(StreamerFailure.scrub).join(' ');
  return [
    'Kabso Live — streamer problem report',
    // The build's own APP_VERSION (not personal): kept whole (a commit's
    // digits are not an id), only odd characters dropped.
    'app: ${app.isEmpty ? '?' : app}',
    'android: $android',
    'device: ${model.isEmpty ? '?' : model}',
    'step: ${failure.step.name}',
    'problem: ${failure.problem.name}',
    'error: ${failure.errorClass}',
    if (failure.detail.isNotEmpty) 'detail: ${failure.detail}',
    'service: foreground=$service types=$types',
    'consent: handed=$handed used=$used',
    'steps: ${trail.isEmpty ? '-' : trail.join(' > ')}',
    'time: ${at.toUtc().toIso8601String()}',
  ].join('\n');
}
