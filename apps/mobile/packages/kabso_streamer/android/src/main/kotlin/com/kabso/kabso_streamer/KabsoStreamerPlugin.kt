package com.kabso.kabso_streamer

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.media.AudioManager
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.Looper
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
 *   permission), `rotation {landscape}` (the display turned).
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
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var engine: FlutterEngine? = null
    private var activity: Activity? = null
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
    private val callPoll =
        object : Runnable {
            override fun run() {
                val am = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val active = am != null && StreamerRules.isPhoneCall(am.mode)
                if (active != callActive) {
                    callActive = active
                    emit("call", mapOf("active" to active))
                }
                main.postDelayed(this, 1000)
            }
        }
    private val projectionCallback =
        object : MediaProjection.Callback() {
            override fun onStop() {
                main.post {
                    stopGame()
                    projection = null
                    emit("projectionStopped", null)
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
        applySecure()
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
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
            else -> result.notImplemented()
        }
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

    private fun emit(method: String, args: Any?) {
        main.post { channel?.invokeMethod(method, args) }
    }

    companion object {
        private const val CHANNEL = "com.kabso/streamer"
        private const val TAG = "KabsoStreamer"
    }
}
