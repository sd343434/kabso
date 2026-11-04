package com.kabso.kabso_camera_fx

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.GetUserMediaImpl
import io.flutter.plugin.common.MethodChannel
import org.webrtc.Camera1Enumerator
import org.webrtc.Camera2Enumerator
import org.webrtc.CameraEnumerator
import org.webrtc.CameraVideoCapturer

/**
 * D251c (the owner's second-camera log: every flip failed in 1–6 ms with
 * `PlatformException(switchCamera)`): flutter_webrtc 1.6.2+hotfix.4's
 * `switchCamera` (a) picks the target from ONE plugin-wide `isFacing` flag
 * (rewritten by every getUserMedia — the HD probe, a second track — not the
 * track's own camera), (b) needs a running camera session: a camera that was
 * disconnected (evicted, a dialog, an away/back) answers «camera is not
 * running» at once and every later flip fails the same way, the picture
 * frozen. This flips one TRACK's camera: the target is the other side of the
 * camera the track's capturer really has; a running session switches in place
 * (WebRTC's own switch, non-blocking); a capturer with no session (and none
 * opening) is restarted on the other camera with `startCapture` — never
 * `stopCapture`, so nothing waits on the main thread (D251's busy-wait in
 * `waitForCameraClosed`). The plugin's `isFacing` and the track's entry follow.
 *
 * Errors carry fixed words only (no ids): code `cameraFlip`, message
 * `why=<no-capturer|no-device|switch-busy|switch-error> state=<camera state>`.
 */
internal class CameraFlip(
    private val context: Context,
    private val main: Handler = Handler(Looper.getMainLooper()),
) {
    fun flip(webrtc: FlutterWebRTCPlugin, trackId: String, result: MethodChannel.Result) {
        val gum = try {
            webrtc.field("methodCallHandler")?.field("getUserMediaImpl") as? GetUserMediaImpl
        } catch (e: ReflectiveOperationException) {
            null
        }
        @Suppress("UNCHECKED_CAST")
        val capturers = try {
            gum?.field("mVideoCapturers") as? Map<String, GetUserMediaImpl.VideoCapturerInfoEx>
        } catch (e: ReflectiveOperationException) {
            null
        }
        var info = capturers?.get(trackId)
        info?.primaryTrackId?.let { primary -> capturers?.get(primary)?.let { info = it } }
        val entry = info
        val capturer = entry?.capturer as? CameraVideoCapturer
        if (gum == null || entry == null || capturer == null) {
            return fail(result, FlipRules.Why.NO_CAPTURER, null)
        }
        val state = stateOf(entry)
        val enumerator: CameraEnumerator =
            if (Camera2Enumerator.isSupported(context)) Camera2Enumerator(context) else Camera1Enumerator(false)
        val names = enumerator.deviceNames.toList()
        val currentName = entry.cameraName ?: cameraNameOf(capturer)
        val front = currentName?.let { enumerator.isFrontFacing(it) } ?: (entry.facingMode != "environment")
        val target = names.firstOrNull { enumerator.isFrontFacing(it) == !front }
            ?: return fail(result, FlipRules.Why.NO_DEVICE, state)
        val session = sessionOf(capturer)
        when (FlipRules.decide(session.running, session.opening, session.switchIdle)) {
            FlipRules.Action.SWITCH -> capturer.switchCamera(
                object : CameraVideoCapturer.CameraSwitchHandler {
                    override fun onCameraSwitchDone(isFrontCamera: Boolean) {
                        main.post {
                            follow(gum, entry, target, isFrontCamera)
                            result.success(mapOf("front" to isFrontCamera, "path" to "switch", "state" to state))
                        }
                    }

                    override fun onCameraSwitchError(error: String?) {
                        main.post {
                            // The session went away meanwhile: open the other camera instead.
                            if (error?.contains("not running") == true && restart(capturer, entry, target)) {
                                follow(gum, entry, target, enumerator.isFrontFacing(target))
                                result.success(
                                    mapOf("front" to enumerator.isFrontFacing(target), "path" to "restart", "state" to state),
                                )
                            } else {
                                fail(result, FlipRules.Why.SWITCH_ERROR, state)
                            }
                        }
                    }
                },
                target,
            )
            FlipRules.Action.RESTART -> if (restart(capturer, entry, target)) {
                follow(gum, entry, target, enumerator.isFrontFacing(target))
                result.success(mapOf("front" to enumerator.isFrontFacing(target), "path" to "restart", "state" to state))
            } else {
                fail(result, FlipRules.Why.SWITCH_ERROR, state)
            }
            FlipRules.Action.BUSY -> fail(result, FlipRules.Why.SWITCH_BUSY, state)
        }
    }

    /** No session and none opening: point the capturer at [target] and start it (never stops). */
    private fun restart(
        capturer: CameraVideoCapturer,
        entry: GetUserMediaImpl.VideoCapturerInfoEx,
        target: String,
    ): Boolean = try {
        cameraCapturerField("cameraName").set(capturer, target)
        capturer.startCapture(entry.width, entry.height, entry.fps)
        true
    } catch (e: ReflectiveOperationException) {
        Log.w(TAG, "flip: restart unavailable: $e")
        false
    } catch (e: RuntimeException) {
        Log.w(TAG, "flip: restart failed: $e")
        false
    }

    /** The track's entry and the plugin's single facing flag follow the camera now on. */
    private fun follow(gum: GetUserMediaImpl, entry: GetUserMediaImpl.VideoCapturerInfoEx, name: String, front: Boolean) {
        entry.cameraName = name
        entry.facingMode = if (front) "user" else "environment"
        try {
            gum.javaClass.getDeclaredField("isFacing").apply { isAccessible = true }.setBoolean(gum, front)
        } catch (e: ReflectiveOperationException) {
            Log.w(TAG, "flip: facing flag not updated: $e")
        }
    }

    private fun fail(result: MethodChannel.Result, why: FlipRules.Why, state: String?) {
        result.error(CODE, FlipRules.message(why, state), null)
    }

    private data class Session(val running: Boolean, val opening: Boolean, val switchIdle: Boolean)

    /** org.webrtc.CameraCapturer's private state (kept by ProGuard: `org.webrtc.**`). Unknown → "running". */
    private fun sessionOf(capturer: CameraVideoCapturer): Session = try {
        val running = cameraCapturerField("currentSession").get(capturer) != null
        val opening = cameraCapturerField("sessionOpening").getBoolean(capturer)
        val switchState = cameraCapturerField("switchState").get(capturer)?.toString()
        Session(running, opening, switchState == null || switchState == "IDLE")
    } catch (e: ReflectiveOperationException) {
        Session(running = true, opening = false, switchIdle = true)
    }

    private fun cameraNameOf(capturer: CameraVideoCapturer): String? = try {
        cameraCapturerField("cameraName").get(capturer) as? String
    } catch (e: ReflectiveOperationException) {
        null
    }

    private fun stateOf(entry: GetUserMediaImpl.VideoCapturerInfoEx): String? = try {
        // CameraEventsHandler is package-private: by reflection only.
        entry.field("cameraEventsHandler")?.field("state")?.toString()
    } catch (e: ReflectiveOperationException) {
        null
    }

    private fun cameraCapturerField(name: String) =
        Class.forName("org.webrtc.CameraCapturer").getDeclaredField(name).apply { isAccessible = true }

    private fun Any.field(name: String): Any? {
        var type: Class<*>? = javaClass
        while (type != null) {
            try {
                return type.getDeclaredField(name).apply { isAccessible = true }.get(this)
            } catch (_: NoSuchFieldException) {
                type = type.superclass
            }
        }
        throw NoSuchFieldException(name)
    }

    private companion object {
        const val TAG = "KabsoCameraFx"
        const val CODE = "cameraFlip"
    }
}

/** D251c: the flip's decision and its fixed-vocabulary message (unit-tested on the JVM). */
internal object FlipRules {
    enum class Action { SWITCH, RESTART, BUSY }

    enum class Why(val word: String) {
        NO_CAPTURER("no-capturer"),
        NO_DEVICE("no-device"),
        SWITCH_BUSY("switch-busy"),
        SWITCH_ERROR("switch-error"),
    }

    /** The camera states CameraEventsHandler has; anything else is not reported. */
    private val STATES = setOf("NEW", "OPENING", "OPENED", "CLOSED", "DISCONNECTED", "ERROR", "FREEZED")

    fun decide(running: Boolean, opening: Boolean, switchIdle: Boolean): Action = when {
        !switchIdle -> Action.BUSY
        running || opening -> Action.SWITCH
        else -> Action.RESTART
    }

    fun message(why: Why, state: String?): String =
        if (state != null && state in STATES) "why=${why.word} state=$state" else "why=${why.word}"
}
