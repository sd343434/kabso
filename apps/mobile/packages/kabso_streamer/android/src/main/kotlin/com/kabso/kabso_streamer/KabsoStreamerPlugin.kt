package com.kabso.kabso_streamer

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.media.AudioManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Display
import android.view.WindowManager
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * D213: the Android side of the streamer live (`com.kabso/streamer`).
 *
 * The screen itself is flutter_webrtc's screen capture (livekit_client's
 * `createScreenShareTrack`); this plugin adds what it lacks:
 *
 * - `attach {gameAudio}` once the screen track runs: joins this engine's
 *   flutter_webrtc audio module with [StreamerMixer] (the microphone and the
 *   game muted separately), watches the capture's MediaProjection (stopped
 *   from the system → `projectionStopped`) and, on Android 10+ with
 *   `gameAudio`, starts [GameCapture] on that same projection. Answers
 *   `{projection, gameAudio}`: whether the projection was found, and `ok`,
 *   `unsupported_os` (< Android 10), `off`, `no_projection` or `failed`.
 *   Without the audio module: `not_ready` as an error.
 * - `setMicMuted {muted}`, `setGameMuted {muted}`.
 * - `detach`: undoes all of it (also when the engine detaches).
 * - `setSecure {on}`: FLAG_SECURE on the app's window while streaming, so
 *   the host's own Kabso screens (chat, wallet, messages) are never sent.
 * - `moveToBack`: the app goes to the background (to the game).
 * - Events: `projectionStopped`, `screen {on}`, `call {active}` (a phone
 *   call rings or is on; `AudioManager` mode, polled each second — no phone
 *   permission), `rotation {landscape}` (the display turned), `headset
 *   {connected}` (a headset was plugged in or out; polled with the call).
 * - `requestCapture {fullScreenOnly = true}` (D262, D262b): the system's screen-capture
 *   consent, asked from the attached Activity with our own result listener
 *   (`MediaProjectionManager.createScreenCaptureIntent`; on Android 14+ with
 *   `fullScreenOnly`, the whole display). Granted → the result Intent is
 *   handed to this engine's flutter_webrtc ([StreamerRules.putConsent]) so
 *   its `getDisplayMedia` uses it (Android 14: one consent, one projection).
 *   Answers `{outcome: granted|refused|failed, reason}`; reasons:
 *   `no_activity`, `no_service`, `no_dialog`, `security`, `error`,
 *   `superseded`, `activity_gone`, `no_data`, `instant_cancel`,
 *   `no_webrtc`. flutter_webrtc's own request (a deprecated framework
 *   Fragment) answered «refused» without ever showing the dialog.
 * - `captureCheck` (D346): right before the screen capture starts — whether
 *   it may ([StreamerRules.captureBlocker]): `{ok, reason, sdk,
 *   serviceForeground, serviceTypes}`. A capture that would fail is never
 *   started, so the consent is not spent on a SecurityException.
 * - `diagnostics` (D346): what the host's «نسخ تقرير المشكلة» report needs —
 *   Android release / SDK, maker and model, the live service's state and
 *   types, the consent's state. No account, no ids.
 * - `headset`: whether a wired, USB or Bluetooth headset is an output now
 *   (`AudioManager.getDevices`, no permission) — the setup's «use
 *   headphones» tip.
 *
 * D232 / D228 (OwnEngineFirst): the live's foreground service starts a SECOND
 * FlutterEngine whose flutter_webrtc overwrites the static
 * `FlutterWebRTCPlugin.sharedSingleton` (no factory, no tracks). Everything
 * here reads THIS engine's flutter_webrtc first, the singleton only as a
 * fallback.
 */
class KabsoStreamerPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var engine: FlutterEngine? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var consent: MethodChannel.Result? = null
    private var consentAskedAt = 0L

    /** D346: the consent handed to flutter_webrtc already started a capture. */
    private var consentUsed = true
    private val main = Handler(Looper.getMainLooper())

    private val mixer = StreamerMixer()
    private var joined: AudioProcessingController? = null
    private var projection: MediaProjection? = null
    private var game: GameCapture? = null
    private var wantGame = false
    private var secure = false
    private var screenReceiver: BroadcastReceiver? = null
    private var displayListener: DisplayManager.DisplayListener? = null
    private var lastLandscape: Boolean? = null
    private var callActive = false
    private var lastHeadset: Boolean? = null
    private val callPoll =
        object : Runnable {
            override fun run() {
                val am = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val active = am != null && StreamerRules.isPhoneCall(am.mode)
                if (active != callActive) {
                    callActive = active
                    emit("call", mapOf("active" to active))
                }
                val headset = headsetNow()
                if (headset != lastHeadset) {
                    lastHeadset = headset
                    emit("headset", mapOf("connected" to headset))
                }
                main.postDelayed(this, 1000)
            }
        }
    private val projectionCallback =
        object : MediaProjection.Callback() {
            override fun onStop() {
                // D346: whether the live service was still in the foreground
                // tells a stop from the system's chip (it was) from one the
                // lost service caused (it was not).
                val service = serviceState().first
                Log.w(TAG, "projection stopped (service ${if (service) "foreground" else "off"})")
                main.post {
                    stopGame()
                    projection = null
                    emit("projectionStopped", mapOf("serviceForeground" to service))
                }
            }
        }

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        @Suppress("DEPRECATION")
        engine = b.flutterEngine
        channel = MethodChannel(b.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        detach()
        engine = null
        context = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        activityBinding = b
        b.addActivityResultListener(this)
        applySecure()
    }

    // The consent's answer reaches the recreated Activity: keep it pending.
    override fun onDetachedFromActivityForConfigChanges() = unbindActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        unbindActivity()
        answerConsent("failed", "activity_gone")
    }

    private fun unbindActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "headset" -> result.success(headsetNow())
            "attach" -> attach(call.argument<Boolean>("gameAudio") ?: false, result)
            "setMicMuted" -> {
                mixer.micMuted = call.argument<Boolean>("muted") ?: false
                result.success(null)
            }
            "setGameMuted" -> {
                mixer.gameMuted = call.argument<Boolean>("muted") ?: false
                result.success(null)
            }
            "detach" -> {
                detach()
                result.success(null)
            }
            "setSecure" -> {
                secure = call.argument<Boolean>("on") ?: false
                applySecure()
                result.success(null)
            }
            "moveToBack" -> result.success(activity?.moveTaskToBack(true) ?: false)
            // D262b: the whole screen unless told otherwise.
            "requestCapture" -> requestCapture(call.argument<Boolean>("fullScreenOnly") ?: true, result)
            "captureCheck" -> result.success(captureCheck())
            "diagnostics" -> result.success(diagnostics())
            else -> result.notImplemented()
        }
    }

    /** D262: the consent dialog from the attached Activity (see the class doc). */
    private fun requestCapture(fullScreenOnly: Boolean, result: MethodChannel.Result) {
        // A request whose answer never came (the dialog was lost) ends here.
        answerConsent("failed", "superseded")
        val act = activity
        if (act == null) {
            result.success(consentAnswer("failed", "no_activity"))
            return
        }
        val manager = act.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
        if (manager == null) {
            result.success(consentAnswer("failed", "no_service"))
            return
        }
        consent = result
        consentAskedAt = SystemClock.elapsedRealtime()
        val reason =
            try {
                val intent =
                    if (StreamerRules.wholeDisplayConsent(Build.VERSION.SDK_INT, fullScreenOnly) &&
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
                    ) {
                        manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
                    } else {
                        manager.createScreenCaptureIntent()
                    }
                act.startActivityForResult(intent, CONSENT_REQUEST)
                Log.i(TAG, "consent: asked (sdk ${Build.VERSION.SDK_INT})")
                null
            } catch (_: ActivityNotFoundException) {
                "no_dialog"
            } catch (_: SecurityException) {
                "security"
            } catch (_: RuntimeException) {
                "error"
            }
        if (reason != null) {
            Log.w(TAG, "consent: could not ask ($reason)")
            answerConsent("failed", reason)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != CONSENT_REQUEST) return false
        val elapsed = SystemClock.elapsedRealtime() - consentAskedAt
        var (outcome, reason) = StreamerRules.consentOutcome(resultCode, data != null, elapsed)
        if (outcome == "granted" && data != null) {
            // D232: this engine's flutter_webrtc first (the one the live's
            // getDisplayMedia runs on), the singleton only without it.
            val handed = webrtcPlugins().any { StreamerRules.putConsent(it, data) }
            if (!handed) {
                outcome = "failed"
                reason = "no_webrtc"
            } else {
                // D346: a fresh consent; one capture may start from it.
                consentUsed = false
            }
        }
        Log.i(TAG, "consent: $outcome (${reason ?: "-"}), code $resultCode after ${elapsed}ms")
        answerConsent(outcome, reason)
        return true
    }

    private fun answerConsent(outcome: String, reason: String?) {
        val pending = consent ?: return
        consent = null
        pending.success(consentAnswer(outcome, reason))
    }

    private fun consentAnswer(outcome: String, reason: String?) = mapOf("outcome" to outcome, "reason" to reason)

    /**
     * D346: the capture may start now? Marks the consent as used when it may
     * (flutter_webrtc's `getDisplayMedia` follows at once), so a second
     * capture never reuses it (Android 14: SecurityException).
     */
    private fun captureCheck(): Map<String, Any?> {
        val sdk = Build.VERSION.SDK_INT
        val service = serviceState()
        val handed = webrtcPlugins().any { StreamerRules.consentHanded(it) }
        val reason =
            StreamerRules.captureBlocker(
                sdk,
                serviceForeground = service.first,
                consentHanded = handed,
                consentUsed = consentUsed,
            )
        if (reason == null) consentUsed = true
        Log.i(
            TAG,
            "capture check: ${reason ?: "ok"} (sdk $sdk, service ${if (service.first) "foreground" else "off"} " +
                "${service.second.joinToString("|")}, consent ${if (handed) "handed" else "none"})",
        )
        return mapOf(
            "ok" to (reason == null),
            "reason" to reason,
            "sdk" to sdk,
            "serviceForeground" to service.first,
            "serviceTypes" to service.second,
        )
    }

    /** D346: the device facts of the host's problem report (no personal data). */
    private fun diagnostics(): Map<String, Any?> {
        val service = serviceState()
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "serviceForeground" to service.first,
            "serviceTypes" to service.second,
            "consentHanded" to webrtcPlugins().any { StreamerRules.consentHanded(it) },
            "consentUsed" to consentUsed,
            "projection" to (projection != null),
        )
    }

    /**
     * D346: whether this app's live service (flutter_foreground_task's) runs in
     * the foreground now, and the types it was started with (its own
     * preferences; cleared when it stops). `getRunningServices` still lists
     * the caller's own services.
     */
    private fun serviceState(): Pair<Boolean, List<String>> {
        val ctx = context ?: return false to emptyList()
        val foreground =
            try {
                val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                @Suppress("DEPRECATION")
                am?.getRunningServices(Int.MAX_VALUE)?.any {
                    it.service.packageName == ctx.packageName && it.service.className == LIVE_SERVICE && it.foreground
                } ?: false
            } catch (_: RuntimeException) {
                false
            }
        val types =
            try {
                val prefs = ctx.getSharedPreferences(SERVICE_TYPES_PREFS, Context.MODE_PRIVATE)
                if (prefs.contains(SERVICE_TYPES_KEY)) {
                    StreamerRules.serviceTypeNames(prefs.getInt(SERVICE_TYPES_KEY, 0))
                } else {
                    emptyList()
                }
            } catch (_: RuntimeException) {
                emptyList()
            }
        return foreground to types
    }

    /** D232: this engine's flutter_webrtc first, then the singleton. */
    private fun webrtcPlugins(): List<FlutterWebRTCPlugin> {
        val own = engine?.plugins?.get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin
        return listOfNotNull(own, FlutterWebRTCPlugin.sharedSingleton).distinct()
    }

    private fun attach(gameAudio: Boolean, result: MethodChannel.Result) {
        val plugins = webrtcPlugins()
        val controller =
            plugins.firstNotNullOfOrNull {
                try {
                    it.audioProcessingController
                } catch (_: RuntimeException) {
                    null
                }
            }
        if (controller == null) {
            result.error("not_ready", "no live microphone", null)
            return
        }
        if (joined == null) {
            controller.capturePostProcessing.addProcessor(mixer)
            joined = controller
        }
        val found =
            plugins.firstNotNullOfOrNull { StreamerRules.findProjection(it, MediaProjection::class.java) }
        if (found != null && found !== projection) {
            projection?.unregisterCallback(projectionCallback)
            projection = found
            found.registerCallback(projectionCallback, main)
        }
        watchDevice()
        wantGame = gameAudio
        val status =
            when {
                !gameAudio -> "off"
                Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> "unsupported_os"
                found == null -> "no_projection"
                else -> if (startGame(found, mixer.rate)) "ok" else "failed"
            }
        mixer.onRate = { rate -> main.post { restartGame(rate) } }
        result.success(mapOf("projection" to (found != null), "gameAudio" to status))
    }

    private fun startGame(p: MediaProjection, rate: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        stopGame()
        return try {
            val capture = GameCapture(p, rate)
            capture.start()
            game = capture
            mixer.capture = capture
            true
        } catch (e: Exception) {
            Log.w(TAG, "game audio capture failed", e)
            false
        }
    }

    private fun restartGame(rate: Int) {
        val p = projection ?: return
        if (wantGame && game != null && game?.rate != rate) startGame(p, rate)
    }

    private fun stopGame() {
        val g = game
        game = null
        mixer.capture = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) g?.stop()
    }

    /** The screen going off / on, the display turning, phone calls. */
    private fun watchDevice() {
        val ctx = context ?: return
        if (screenReceiver == null) {
            val r =
                object : BroadcastReceiver() {
                    override fun onReceive(c: Context?, intent: Intent?) {
                        when (intent?.action) {
                            Intent.ACTION_SCREEN_OFF -> emit("screen", mapOf("on" to false))
                            Intent.ACTION_SCREEN_ON -> emit("screen", mapOf("on" to true))
                        }
                    }
                }
            val filter =
                IntentFilter().apply {
                    addAction(Intent.ACTION_SCREEN_OFF)
                    addAction(Intent.ACTION_SCREEN_ON)
                }
            // System broadcasts only; Android 13+ takes the flag explicitly.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ctx.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(r, filter)
            }
            screenReceiver = r
        }
        if (displayListener == null) {
            val dm = ctx.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val l =
                object : DisplayManager.DisplayListener {
                    override fun onDisplayAdded(displayId: Int) {}

                    override fun onDisplayRemoved(displayId: Int) {}

                    override fun onDisplayChanged(displayId: Int) {
                        if (displayId != Display.DEFAULT_DISPLAY) return
                        val rotation = dm.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: return
                        val landscape = StreamerRules.isLandscape(rotation)
                        if (landscape == lastLandscape) return
                        lastLandscape = landscape
                        emit("rotation", mapOf("landscape" to landscape))
                    }
                }
            dm.registerDisplayListener(l, main)
            displayListener = l
            lastLandscape =
                dm.getDisplay(Display.DEFAULT_DISPLAY)?.rotation?.let { StreamerRules.isLandscape(it) }
        }
        main.removeCallbacks(callPoll)
        main.post(callPoll)
    }

    private fun detach() {
        stopGame()
        wantGame = false
        mixer.onRate = null
        mixer.micMuted = false
        mixer.gameMuted = false
        joined?.capturePostProcessing?.removeProcessor(mixer)
        joined = null
        projection?.unregisterCallback(projectionCallback)
        projection = null
        main.removeCallbacks(callPoll)
        callActive = false
        lastHeadset = null
        screenReceiver?.let {
            try {
                context?.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Not registered.
            }
        }
        screenReceiver = null
        displayListener?.let {
            (context?.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager)?.unregisterDisplayListener(it)
        }
        displayListener = null
        lastLandscape = null
        secure = false
        applySecure()
    }

    private fun applySecure() {
        val window = activity?.window ?: return
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    /** A headset is an output now (the minimum SDK 23 has `getDevices`). */
    private fun headsetNow(): Boolean {
        val am = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        return StreamerRules.anyHeadset(
            am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toIntArray(),
        )
    }

    private fun emit(method: String, args: Any?) {
        main.post { channel?.invokeMethod(method, args) }
    }

    companion object {
        private const val CHANNEL = "com.kabso/streamer"
        private const val TAG = "KabsoStreamer"

        /** D262: our consent's request code (flutter_webrtc uses its own). */
        private const val CONSENT_REQUEST = 0x4B53

        /** D346: the live's foreground service (flutter_foreground_task 11.0.3) and where it keeps its types. */
        private const val LIVE_SERVICE = "com.pravera.flutter_foreground_task.service.ForegroundService"
        private const val SERVICE_TYPES_PREFS = "com.pravera.flutter_foreground_task.prefs.FOREGROUND_SERVICE_TYPES"
        private const val SERVICE_TYPES_KEY = "serviceTypes"
    }
}
