package com.kabso.kabso_streamer

import java.util.concurrent.atomic.AtomicInteger

/**
 * D213: the plain-Kotlin rules of the streamer live (no Android types), so the
 * JVM tests run them without a device.
 */
object StreamerRules {
    /** The largest sample of WebRTC's float buffers (the 16-bit range). */
    const val FULL_SCALE = 32767f

    /** The game sits a little under the voice so the host stays clear. */
    const val GAME_GAIN = 0.8f

    /**
     * One 10 ms capture frame: the microphone's [voice] (silenced when
     * [micMuted]) plus [game] at [gameGain] (nothing when [gameMuted] or when
     * [gameFrames] is 0), soft-limited so a loud game never wraps around.
     * Writes into [voice]; returns the peak of the result.
     */
    fun mix(
        voice: FloatArray,
        n: Int,
        micMuted: Boolean,
        game: FloatArray,
        gameFrames: Int,
        gameMuted: Boolean,
        gameGain: Float = GAME_GAIN,
    ): Float {
        var peak = 0f
        val g = if (gameMuted) 0f else gameGain
        for (i in 0 until n) {
            val v = if (micMuted) 0f else voice[i]
            val s = if (i < gameFrames) game[i] * g else 0f
            val out = limit(v + s)
            voice[i] = out
            val a = if (out < 0) -out else out
            if (a > peak) peak = a
        }
        return peak
    }

    /** A soft knee above 80 % of full scale; never past full scale. */
    fun limit(x: Float): Float {
        val knee = FULL_SCALE * 0.8f
        val a = if (x < 0) -x else x
        if (a <= knee) return x
        val over = (a - knee) / (FULL_SCALE - knee)
        val soft = knee + (FULL_SCALE - knee) * (over / (1f + over))
        return if (x < 0) -soft else soft
    }

    /** 16-bit PCM (mono) to floats in the 16-bit range, as WebRTC uses. */
    fun pcm16ToFloat(src: ShortArray, count: Int, dst: FloatArray) {
        for (i in 0 until count) dst[i] = src[i].toFloat()
    }

    /**
     * Android's `AudioManager.getMode()`: a phone call rings
     * (`MODE_RINGTONE` 1), is on (`MODE_IN_CALL` 2) or is screened
     * (`MODE_CALL_SCREENING` 4, Android 11). `MODE_IN_COMMUNICATION` (3) is
     * a VoIP call — our own live sets it, so it is not one.
     */
    fun isPhoneCall(mode: Int): Boolean = mode == 1 || mode == 2 || mode == 4

    /**
     * `AudioDeviceInfo.getType()` outputs that play into the host's ears, so
     * the game sound does not reach the microphone a second time: wired
     * headset (3) and headphones (4), Bluetooth SCO (7) and A2DP (8), USB
     * headset (22), hearing aid (23), BLE headset (26). A BLE speaker (27) is
     * not one. A2DP is also a car or a Bluetooth speaker — Android cannot
     * tell them apart cheaply, so the tip is then hidden too.
     */
    val HEADSET_TYPES = setOf(3, 4, 7, 8, 22, 23, 26)

    /** Any of the connected output [types] is a headset. */
    fun anyHeadset(types: IntArray): Boolean = types.any { it in HEADSET_TYPES }

    /** `Display.getRotation()`: 1 (90°) and 3 (270°) are landscape. */
    fun isLandscape(rotation: Int): Boolean = rotation == 1 || rotation == 3

    /**
     * The path from flutter_webrtc's plugin object to the screen capturer's
     * running `MediaProjection` (flutter_webrtc 1.6.2+hotfix.4; its ProGuard
     * rules keep `com.cloudwebrtc.webrtc.**` with every member):
     * `FlutterWebRTCPlugin.methodCallHandler` → `MethodCallHandlerImpl
     * .getUserMediaImpl` → `GetUserMediaImpl.mVideoCapturers` (track id →
     * `VideoCapturerInfoEx`) → `.capturer` (an `OrientationAwareScreenCapturer`)
     * → `.mediaProjection`. Android 14 lets one consent start ONE projection,
     * so the game audio must use this one rather than ask again.
     */
    val PROJECTION_PATH = listOf("methodCallHandler", "getUserMediaImpl", "mVideoCapturers")

    /**
     * Finds the first value of [type] behind [root] along [PROJECTION_PATH];
     * null when any step is missing (another flutter_webrtc version: the app
     * then streams the microphone only and says why).
     */
    fun <T> findProjection(root: Any?, type: Class<T>): T? {
        var at: Any? = root
        for (name in PROJECTION_PATH) {
            at = field(at, name) ?: return null
        }
        val capturers = (at as? Map<*, *>)?.values ?: return null
        for (info in capturers) {
            val capturer = field(info, "capturer") ?: continue
            val projection = field(capturer, "mediaProjection") ?: continue
            if (type.isInstance(projection)) return type.cast(projection)
        }
        return null
    }

    /**
     * D262: where flutter_webrtc 1.6.2+hotfix.4 keeps the screen-capture
     * consent: `FlutterWebRTCPlugin.methodCallHandler` → `MethodCallHandlerImpl
     * .getUserMediaImpl`, field `mediaProjectionData` (the system's result
     * Intent). `getDisplayMedia` uses it when set and only asks (with its own
     * deprecated fragment) when it is null.
     */
    val CONSENT_PATH = listOf("methodCallHandler", "getUserMediaImpl")
    const val CONSENT_FIELD = "mediaProjectionData"

    /**
     * D262: hands our own consent [data] to flutter_webrtc behind [root]
     * (along [CONSENT_PATH]); false when a step is missing or the field does
     * not take it (another flutter_webrtc version).
     */
    fun putConsent(root: Any?, data: Any): Boolean {
        var at: Any? = root
        for (name in CONSENT_PATH) {
            at = field(at, name) ?: return false
        }
        return setField(at, CONSENT_FIELD, data)
    }

    /** Sets a declared field of [obj]'s class or a superclass; false when it cannot. */
    fun setField(obj: Any?, name: String, value: Any): Boolean {
        if (obj == null) return false
        var c: Class<*>? = obj.javaClass
        while (c != null) {
            try {
                val f = c.getDeclaredField(name)
                if (!f.type.isInstance(value)) return false
                f.isAccessible = true
                f.set(obj, value)
                return true
            } catch (_: NoSuchFieldException) {
                c = c.superclass
            } catch (_: ReflectiveOperationException) {
                return false
            } catch (_: RuntimeException) {
                return false
            }
        }
        return false
    }

    /** Android 14 (`UPSIDE_DOWN_CAKE`): `MediaProjectionConfig` exists. */
    const val SDK_PROJECTION_CONFIG = 34

    /**
     * D262b (owner): the consent intent carries
     * `MediaProjectionConfig.createConfigForDefaultDisplay()` — the dialog
     * then offers only the entire screen, no «single app» (whose app picker,
     * left with back, read as a refusal). Below Android 14 the plain intent
     * already means the whole screen. flutter_webrtc's capturer is unchanged
     * by it: `getMediaProjection(RESULT_OK, data)` + a virtual display of the
     * default display.
     */
    fun wholeDisplayConsent(sdkInt: Int, fullScreenOnly: Boolean): Boolean =
        fullScreenOnly && sdkInt >= SDK_PROJECTION_CONFIG

    /** `Activity.RESULT_OK`. */
    const val RESULT_OK = -1

    /**
     * D262: a «cancel» this soon after asking never came from a person — the
     * consent dialog did not show (the system closed it at once).
     */
    const val INSTANT_CANCEL_MS = 400L

    /**
     * D262: the system's answer to the consent dialog as `(outcome, reason)`:
     * `granted`; `refused` (the person said no); or `failed` with
     * `no_data` (OK without the Intent) or `instant_cancel` (cancelled before
     * [INSTANT_CANCEL_MS]: the dialog never showed).
     */
    fun consentOutcome(resultCode: Int, hasData: Boolean, elapsedMs: Long): Pair<String, String?> =
        when {
            resultCode == RESULT_OK && hasData -> "granted" to null
            resultCode == RESULT_OK -> "failed" to "no_data"
            elapsedMs in 0 until INSTANT_CANCEL_MS -> "failed" to "instant_cancel"
            else -> "refused" to null
        }

    /**
     * D346: Android 10 (Q) and later stop — or refuse to start — a
     * MediaProjection whose app has no running foreground service of type
     * `mediaProjection` (targetSdk ≥ 29): `MediaProjection.start` throws
     * SecurityException «Media projections require a foreground service of
     * type ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION», and the
     * system ends a running projection as soon as that service stops.
     */
    const val SDK_PROJECTION_NEEDS_SERVICE = 29

    /** D346: `MediaProjectionManager` exists from Android 5 (21). */
    const val SDK_MIN_CAPTURE = 21

    /**
     * D346: checked right before flutter_webrtc's `getDisplayMedia` spends
     * the consent (Android 14 lets one consent start ONE projection; a reused
     * one throws SecurityException). Null: the capture may start. Otherwise
     * the reason: `unsupported_os` (below Android 5), `no_consent` (our
     * consent was not handed to flutter_webrtc — it would ask again with its
     * own dialog), `consent_used` (that consent already started a capture: a
     * new one must be asked), `no_service` (Android 10+: the live's
     * foreground service is not in the foreground, so the projection would
     * be refused or stopped at once).
     */
    fun captureBlocker(
        sdkInt: Int,
        serviceForeground: Boolean,
        consentHanded: Boolean,
        consentUsed: Boolean,
    ): String? =
        when {
            sdkInt < SDK_MIN_CAPTURE -> "unsupported_os"
            !consentHanded -> "no_consent"
            consentUsed -> "consent_used"
            sdkInt >= SDK_PROJECTION_NEEDS_SERVICE && !serviceForeground -> "no_service"
            else -> null
        }

    /** D346: whether a consent Intent sits in flutter_webrtc behind [root] (along [CONSENT_PATH]). */
    fun consentHanded(root: Any?): Boolean {
        var at: Any? = root
        for (name in CONSENT_PATH) {
            at = field(at, name) ?: return false
        }
        return field(at, CONSENT_FIELD) != null
    }

    /**
     * D346: `ServiceInfo.FOREGROUND_SERVICE_TYPE_*` bits as names, for the
     * diagnostics report (what the live's service was started with).
     */
    val SERVICE_TYPE_NAMES =
        linkedMapOf(
            0x40 to "camera",
            0x80 to "microphone",
            0x02 to "mediaPlayback",
            0x20 to "mediaProjection",
        )

    fun serviceTypeNames(bits: Int): List<String> =
        if (bits < 0) listOf("manifest") else SERVICE_TYPE_NAMES.filterKeys { bits and it != 0 }.values.toList()

    /** A declared field of [obj]'s class or a superclass (private too). */
    fun field(obj: Any?, name: String): Any? {
        if (obj == null) return null
        var c: Class<*>? = obj.javaClass
        while (c != null) {
            try {
                val f = c.getDeclaredField(name)
                f.isAccessible = true
                return f.get(obj)
            } catch (_: NoSuchFieldException) {
                c = c.superclass
            } catch (_: ReflectiveOperationException) {
                return null
            } catch (_: RuntimeException) {
                // InaccessibleObjectException / SecurityException.
                return null
            }
        }
        return null
    }
}

/**
 * A single-producer, single-consumer ring of floats (the capture thread
 * writes, WebRTC's audio thread reads). When full, the oldest samples are
 * dropped by the reader's next skip, so the game never lags behind.
 */
class FloatRing(capacity: Int) {
    private val buf = FloatArray(capacity)
    private val head = AtomicInteger(0) // next write
    private val tail = AtomicInteger(0) // next read
    val capacity: Int get() = buf.size

    fun available(): Int {
        val h = head.get()
        val t = tail.get()
        return if (h >= t) h - t else buf.size - t + h
    }

    /** Writes [count] samples; when there is no room the oldest are dropped. */
    fun write(src: FloatArray, count: Int) {
        var h = head.get()
        for (i in 0 until count) {
            buf[h] = src[i]
            h = (h + 1) % buf.size
            if (h == tail.get()) {
                // Full: drop the oldest sample.
                tail.set((tail.get() + 1) % buf.size)
            }
        }
        head.set(h)
    }

    /** Reads up to [count] samples into [dst]; returns how many. */
    fun poll(dst: FloatArray, count: Int): Int {
        val n = minOf(count, available())
        var t = tail.get()
        for (i in 0 until n) {
            dst[i] = buf[t]
            t = (t + 1) % buf.size
        }
        tail.set(t)
        return n
    }

    fun clear() {
        tail.set(head.get())
    }
}
