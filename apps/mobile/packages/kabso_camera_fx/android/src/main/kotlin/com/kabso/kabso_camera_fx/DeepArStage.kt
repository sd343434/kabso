package com.kabso.kabso_camera_fx

import android.app.Activity
import android.graphics.Bitmap
import android.media.Image
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import ai.deepar.ar.ARErrorType
import ai.deepar.ar.AREventListener
import ai.deepar.ar.DeepAR
import ai.deepar.ar.DeepARImageFormat
import com.cloudwebrtc.webrtc.utils.EglUtils
import org.webrtc.SurfaceTextureHelper
import org.webrtc.VideoFrame
import org.webrtc.YuvHelper
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * D144: the DeepAR stage of [CameraFxProcessor]. D144a: it can no longer
 * freeze the picture.
 *
 * Per frame (capture thread): texture frame → (crop/scale to the latched
 * [InputGeometry]) → `toI420()` → NV21 (libyuv via [YuvHelper], two rotating
 * direct buffers) → DeepAR's own thread `receiveFrame` → DeepAR renders into
 * a [Surface] owned by a WebRTC [SurfaceTextureHelper] on flutter_webrtc's
 * root EGL context → [FreshGate] → that texture frame (rotation 0: DeepAR
 * renders upright, capture timestamp) is handed back. The output never leaves
 * the GPU.
 *
 * Rules (D144a, after the owner's device froze on background blur with the
 * watermark showing — DeepAR alive, the camera image no longer advancing):
 * - **Only fresh output** ([FreshGate]): a render is published only if DeepAR
 *   took a newer camera frame since the last one published; re-draws are
 *   released at once. No fresh render within [RENDER_TIMEOUT_MS] → the raw
 *   frame passes. Never a held or repeated picture.
 * - **One frame in flight** to DeepAR: while it is busy no new frame is
 *   queued behind it (D144 posted one per camera frame without bound).
 * - **Fixed input geometry** per DeepAR instance ([InputGeometry]): WebRTC's
 *   resolution changes are absorbed by a GPU crop/scale; the render surface
 *   is set once. The other camera (rotation change) → a new instance.
 * - **Safety net** ([OutputHealth]): no fresh render for [MAX_MISSES] frames
 *   in a row (or none in the first [WARMUP_MS]), DeepAR's thread stuck for
 *   [STALL_MS], a licence error or a failing `receiveFrame` → the effect turns
 *   itself off (raw camera) and [onStatus] says why.
 * - No effect selected → [process] returns null (the frame passes untouched)
 *   and DeepAR is paused. DeepAR is initialized only when an effect is first
 *   picked (DeepAR counts monthly active users by initialization).
 * - Viewers get the true (unmirrored) picture: `mirror=false`.
 *
 * Adapted from voxa_deepar's DeepArBridgeFilter (MIT; see the package's
 * THIRD_PARTY_NOTICES.md).
 */
internal class DeepArStage(
    private val activity: Activity,
    private val onStatus: (Map<String, Any?>) -> Unit,
) {

    /** What [setEffect] can load. */
    sealed interface Effect {
        /** An effect built into the DeepAR SDK (no file). */
        data class Builtin(val name: String) : Effect

        /** A `.deepar` file in the APK's assets. */
        data class Asset(val path: String) : Effect
    }

    // DeepAR pins itself to the thread that first set its render surface:
    // every DeepAR call goes through this one, never the capture or main
    // thread.
    private val deepArThread = HandlerThread("KabsoDeepAr").apply { start() }
    private val deepAr = Handler(deepArThread.looper)

    private val lock = Any()

    // Guarded by [lock].
    private var instance: DeepAR? = null
    private var generation = 0
    private var licenseKey: String? = null
    private var effect: Effect? = null
    private var surfaceHelper: SurfaceTextureHelper? = null
    private var renderSurface: Surface? = null
    private var geometry: InputGeometry? = null
    private var surfaceFor: InputGeometry? = null
    private var configuring = false
    private var recreating = false
    private val inputBuffers = arrayOfNulls<ByteBuffer>(2)
    private var inputSlot = 0

    /** An effect is selected and not given up on: frames go to DeepAR. */
    @Volatile private var active = false

    /** Generation whose DeepAR said `initialized()` (-1: none). */
    @Volatile private var initializedGen = -1
    private val disposed = AtomicBoolean(false)

    // DeepAR's thread only.
    private var blurOn = false

    private val gate = FreshGate<VideoFrame> { it.release() }

    // Capture thread only.
    private val health = OutputHealth(MAX_MISSES, TimeUnit.MILLISECONDS.toNanos(WARMUP_MS))
    @Volatile private var armPending = false
    private var fedSeq = 0L
    private val waitAvg = RollingAverage()
    private val packAvg = RollingAverage()
    private var reportedTimeout = false

    // One frame in flight to DeepAR's thread.
    private val inFlight = AtomicBoolean(false)
    @Volatile private var inFlightSince = 0L

    // Diagnostics (any thread).
    private val framesIn = AtomicLong()
    private val fed = AtomicLong()
    private val busySkips = AtomicLong()
    private val framesOut = AtomicLong()
    private val misses = AtomicLong()
    private val deepArRenders = AtomicLong()
    private val instances = AtomicLong()
    @Volatile private var state = STATE_OFF
    @Volatile private var reason: String? = null
    @Volatile private var lastError: String? = null
    @Volatile private var sdkVersion: String? = null

    fun setLicenseKey(key: String) {
        synchronized(lock) { licenseKey = key }
    }

    /** `null`: no effect (pass-through, DeepAR paused). */
    fun setEffect(next: Effect?) {
        synchronized(lock) { effect = next }
        if (next != null) {
            gate.clear()
            armPending = true
            active = true
            setState(STATE_INITIALIZING, null)
        } else {
            active = false
            gate.clear()
            // A failure stays visible (Dart shows why) until the next pick.
            if (!isFailure(state)) setState(STATE_OFF, null)
        }
        deepAr.post {
            if (next != null) startIfNeeded()
            applyEffect()
        }
    }

    /** Releases DeepAR and stops its thread. */
    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        active = false
        deepAr.post {
            teardown()
            deepArThread.quitSafely()
        }
    }

    /** What the diagnostics overlay shows (never the licence key). */
    fun diagnostics(): Map<String, Any?> {
        val (delivered, stale) = gate.counts()
        val geo = synchronized(lock) { geometry }
        val since = inFlightSince
        return mapOf(
            "state" to state,
            "reason" to reason,
            "lastError" to lastError,
            "licencePresent" to !synchronized(lock) { licenseKey }.isNullOrEmpty(),
            "sdkVersion" to sdkVersion,
            "initialized" to (initializedGen >= 0),
            "framesIn" to framesIn.get(),
            "fed" to fed.get(),
            "busySkips" to busySkips.get(),
            "rendered" to deepArRenders.get(),
            "delivered" to delivered,
            "staleDropped" to stale,
            "framesOut" to framesOut.get(),
            "timeouts" to misses.get(),
            "consecutiveMisses" to health.consecutiveMisses,
            "avgWaitMs" to waitAvg.lastMs,
            "avgPackMs" to packAvg.lastMs,
            "inFlightMs" to if (inFlight.get() && since > 0) (System.nanoTime() - since) / 1_000_000 else 0L,
            "input" to geo?.let { "${it.width}x${it.height}@${it.rotation}" },
            "instances" to instances.get(),
        )
    }

    // ------------------------------------------------------------ DeepAR thread

    private fun startIfNeeded() {
        val key: String?
        var created: DeepAR? = null
        var gen = 0
        synchronized(lock) {
            if (instance != null || disposed.get()) return
            key = licenseKey
            if (!key.isNullOrEmpty()) {
                created = DeepAR(activity)
                generation++
                gen = generation
                instance = created
            }
        }
        val deepAR = created
        if (key.isNullOrEmpty() || deepAR == null) {
            Log.w(TAG, "an effect was picked before init(licenseKey): ignored")
            fail(STATE_LICENCE_FAILED, "no_key")
            return
        }
        instances.incrementAndGet()
        try {
            deepAR.setLicenseKey(key)
            deepAR.initialize(activity, Listener(gen))
            deepAR.setFrameRenderedCallback { deepArRenders.incrementAndGet() }
            // Live mode: no still-capture pipeline kept warm.
            deepAR.changeLiveMode(true)
            sdkVersion = try {
                DeepAR.getSdkVersion()
            } catch (_: Throwable) {
                null
            }
            Log.i(TAG, "DeepAR initializing (SDK $sdkVersion)")
        } catch (error: Throwable) {
            lastError = error.toString()
            Log.w(TAG, "DeepAR could not start: $error")
            fail(STATE_ERROR, "start_failed")
        }
    }

    private fun applyEffect() {
        val deepAR: DeepAR
        val next: Effect?
        val gen: Int
        synchronized(lock) {
            deepAR = instance ?: return
            next = effect
            gen = generation
        }
        if (initializedGen != gen) return // re-applied from initialized()
        try {
            when (next) {
                null -> {
                    if (blurOn) deepAR.backgroundBlur(false, 0)
                    blurOn = false
                    deepAR.switchEffect(SLOT, null as String?)
                    deepAR.setPaused(true)
                }
                is Effect.Builtin -> {
                    deepAR.setPaused(false)
                    deepAR.switchEffect(SLOT, null as String?)
                    when (next.name) {
                        "background_blur" -> {
                            deepAR.backgroundBlur(true, BLUR_STRENGTH)
                            blurOn = true
                        }
                        else -> Log.w(TAG, "unknown built-in effect ${next.name}")
                    }
                }
                is Effect.Asset -> {
                    deepAR.setPaused(false)
                    if (blurOn) deepAR.backgroundBlur(false, 0)
                    blurOn = false
                    activity.assets.open(next.path).use { stream ->
                        deepAR.switchEffect(SLOT, stream)
                    }
                }
            }
        } catch (error: Throwable) {
            lastError = error.toString()
            Log.w(TAG, "switching the effect failed: $error")
            fail(STATE_ERROR, "effect_failed")
        }
    }

    private fun teardown() {
        val deepAR: DeepAR?
        val helper: SurfaceTextureHelper?
        val surface: Surface?
        synchronized(lock) {
            deepAR = instance
            helper = surfaceHelper
            surface = renderSurface
            instance = null
            surfaceHelper = null
            renderSurface = null
            geometry = null
            surfaceFor = null
            configuring = false
            inputBuffers[0] = null
            inputBuffers[1] = null
        }
        initializedGen = -1
        blurOn = false
        // The producer stops first, then its surface and consumer go.
        try {
            deepAR?.release()
        } catch (error: Throwable) {
            Log.w(TAG, "DeepAR release failed: $error")
        }
        gate.clear()
        helper?.stopListening()
        helper?.dispose()
        surface?.release()
        if (deepAR != null) Log.i(TAG, "DeepAR released")
    }

    /** The other camera: DeepAR keys to its first input; start a new one. */
    private fun recreate() {
        teardown()
        synchronized(lock) { recreating = false }
        if (!active) return
        startIfNeeded()
        applyEffect()
    }

    private fun configureSurface(geo: InputGeometry) {
        val oldHelper: SurfaceTextureHelper?
        val oldSurface: Surface?
        val deepAR: DeepAR?
        synchronized(lock) {
            oldHelper = surfaceHelper
            oldSurface = renderSurface
            deepAR = instance
        }
        if (deepAR == null) {
            synchronized(lock) { configuring = false }
            return
        }
        try {
            val helper = SurfaceTextureHelper.create("KabsoDeepArRender", EglUtils.getRootEglBaseContext())
                ?: throw IllegalStateException("no SurfaceTextureHelper")
            helper.setTextureSize(geo.outWidth, geo.outHeight)
            val surface = Surface(helper.surfaceTexture)
            helper.startListening(::onRendered)
            // The new surface first, then the old one goes: DeepAR never
            // renders into a released surface (D144 freed it first).
            deepAR.setRenderSurface(surface, geo.outWidth, geo.outHeight)
            synchronized(lock) {
                surfaceHelper = helper
                renderSurface = surface
                surfaceFor = geo
                configuring = false
            }
            gate.clear()
            oldHelper?.stopListening()
            oldHelper?.dispose()
            oldSurface?.release()
            Log.i(TAG, "render surface ${geo.outWidth}x${geo.outHeight} (input $geo)")
        } catch (error: Throwable) {
            synchronized(lock) { configuring = false }
            lastError = error.toString()
            Log.w(TAG, "could not create the render surface: $error")
            fail(STATE_ERROR, "surface_failed")
        }
    }

    // ----------------------------------------------------------- capture thread

    /**
     * The frame with the effect, owned by the caller (release it before the
     * next call), or null: pass [frame] on as it is.
     */
    fun process(frame: VideoFrame): VideoFrame? {
        if (!active) return null
        framesIn.incrementAndGet()
        val now = System.nanoTime()
        if (armPending) {
            armPending = false
            health.arm(now)
        }

        // DeepAR's thread has been stuck on one frame: it will not recover.
        val since = inFlightSince
        if (inFlight.get() && since > 0 && now - since > TimeUnit.MILLISECONDS.toNanos(STALL_MS)) {
            fail(STATE_DISABLED, "stalled")
            return null
        }

        val deepAR: DeepAR
        val gen: Int
        val latched: InputGeometry?
        synchronized(lock) {
            deepAR = instance ?: return miss(now)
            gen = generation
            latched = geometry
        }

        val rotation = frame.rotation
        val input: InputGeometry
        if (latched == null) {
            input = InputGeometry.latch(frame.buffer.width, frame.buffer.height, rotation, MAX_LONG_SIDE)
            synchronized(lock) { if (generation == gen && geometry == null) geometry = input }
        } else if (latched.rotation != rotation) {
            requestRecreate(now)
            return miss(now)
        } else {
            input = latched
        }

        // Surface first, then the initialized gate: DeepAR initializes on
        // its first setRenderSurface.
        if (!ensureSurface(input)) return miss(now)
        if (initializedGen != gen) return miss(now)

        feed(frame, deepAR, gen, input)

        val waitStart = System.nanoTime()
        val rendered = gate.take(TimeUnit.MILLISECONDS.toNanos(RENDER_TIMEOUT_MS))
        val done = System.nanoTime()
        waitAvg.add(done - waitStart, done)
        if (rendered == null) {
            if (!reportedTimeout) {
                reportedTimeout = true
                Log.w(TAG, "no fresh render within $RENDER_TIMEOUT_MS ms: raw frame passed (once)")
            }
            return miss(done)
        }
        health.onOutput()
        framesOut.incrementAndGet()
        if (state != STATE_READY) setState(STATE_READY, null)
        return outputFor(rendered, frame, input)
    }

    /** One frame to DeepAR's thread, unless the previous is still there. */
    private fun feed(frame: VideoFrame, deepAR: DeepAR, gen: Int, geo: InputGeometry) {
        if (!inFlight.compareAndSet(false, true)) {
            // Still busy: wait below for the render of the one in flight.
            busySkips.incrementAndGet()
            return
        }
        val packStart = System.nanoTime()
        val input = packNv21(frame, geo)
        if (input == null) {
            inFlight.set(false)
            return
        }
        val packed = System.nanoTime()
        packAvg.add(packed - packStart, packed)
        val seq = ++fedSeq
        inFlightSince = packed
        val posted = deepAr.post {
            try {
                val current = synchronized(lock) { instance === deepAR && generation == gen }
                if (current && active) {
                    gate.feedStarted(seq)
                    deepAR.receiveFrame(
                        input, geo.width, geo.height, geo.rotation, false, DeepARImageFormat.YUV_NV21, 1,
                    )
                    gate.feedDone(seq)
                    fed.incrementAndGet()
                }
            } catch (error: Throwable) {
                // Wrong thread, not initialized, bad buffer: it will not get
                // better frame by frame, and tags must not advance on input
                // DeepAR never took.
                lastError = error.toString()
                Log.w(TAG, "receiveFrame failed: $error")
                fail(STATE_ERROR, "feed_failed")
            } finally {
                inFlightSince = 0L
                inFlight.set(false)
            }
        }
        if (!posted) {
            inFlightSince = 0L
            inFlight.set(false)
        }
    }

    /** No effect on this frame; gives up when [health] says so. */
    private fun miss(nowNanos: Long): VideoFrame? {
        misses.incrementAndGet()
        if (health.onMiss(nowNanos) == OutputHealth.Verdict.GIVE_UP) {
            if (initializedGen < 0) {
                fail(STATE_ERROR, "init_timeout")
            } else {
                fail(STATE_DISABLED, "no_output")
            }
        }
        return null
    }

    private fun requestRecreate(nowNanos: Long) {
        synchronized(lock) {
            if (recreating) return
            recreating = true
        }
        Log.i(TAG, "camera rotation changed: new DeepAR instance")
        health.arm(nowNanos)
        setState(STATE_INITIALIZING, null)
        deepAr.post(::recreate)
    }

    /** DeepAR's upright render, cropped/scaled to what WebRTC sent now. */
    private fun outputFor(rendered: VideoFrame, frame: VideoFrame, geo: InputGeometry): VideoFrame {
        val wantW = frame.rotatedWidth
        val wantH = frame.rotatedHeight
        // The capture timestamp, not the render one: keeps A/V sync.
        if (wantW == geo.outWidth && wantH == geo.outHeight) {
            return VideoFrame(rendered.buffer, 0, frame.timestampNs)
        }
        val crop = InputGeometry.centreCrop(geo.outWidth, geo.outHeight, wantW, wantH)
        val scaled = rendered.buffer.cropAndScale(crop.x, crop.y, crop.width, crop.height, wantW, wantH)
        rendered.release()
        return VideoFrame(scaled, 0, frame.timestampNs)
    }

    private fun ensureSurface(geo: InputGeometry): Boolean {
        synchronized(lock) {
            if (surfaceHelper != null && surfaceFor == geo) return true
            if (configuring) return false
            configuring = true
        }
        deepAr.post { configureSurface(geo) }
        return false
    }

    /** I420 → NV21 (Y plane, then V/U interleaved) in libyuv; 2 rotating buffers. */
    private fun packNv21(frame: VideoFrame, geo: InputGeometry): ByteBuffer? {
        val source = frame.buffer
        val scaled = source.width != geo.width || source.height != geo.height
        val i420 = try {
            if (scaled) {
                val crop = geo.cropFor(source.width, source.height)
                val sized = source.cropAndScale(crop.x, crop.y, crop.width, crop.height, geo.width, geo.height)
                try {
                    sized.toI420()
                } finally {
                    sized.release()
                }
            } else {
                source.toI420()
            }
        } catch (error: Throwable) {
            Log.w(TAG, "toI420 failed: $error")
            null
        } ?: return null
        try {
            val width = i420.width
            val height = i420.height
            val chromaWidth = (width + 1) / 2
            val chromaHeight = (height + 1) / 2
            val ySize = width * height
            val needed = ySize + chromaWidth * chromaHeight * 2
            val out: ByteBuffer
            synchronized(lock) {
                inputSlot = (inputSlot + 1) % inputBuffers.size
                val existing = inputBuffers[inputSlot]
                out = if (existing != null && existing.capacity() >= needed) {
                    existing
                } else {
                    ByteBuffer.allocateDirect(needed).also { inputBuffers[inputSlot] = it }
                }
            }
            out.clear()
            out.limit(ySize)
            val dstY = out.slice()
            out.clear()
            out.position(ySize)
            out.limit(needed)
            val dstVu = out.slice()
            // NV12 with U and V swapped is NV21.
            YuvHelper.I420ToNV12(
                i420.dataY, i420.strideY,
                i420.dataV, i420.strideV,
                i420.dataU, i420.strideU,
                dstY, width,
                dstVu, chromaWidth * 2,
                width, height,
            )
            out.clear()
            out.limit(needed)
            return out
        } catch (error: Throwable) {
            Log.w(TAG, "NV21 pack failed: $error")
            return null
        } finally {
            i420.release()
        }
    }

    // ------------------------------------------------------- render (helper) thread

    private fun onRendered(frame: VideoFrame) {
        // The helper releases this frame when we return: retain to keep it.
        // The gate releases it at once if it is a re-draw of an image already
        // published, which also gives the helper's one texture back.
        frame.buffer.retain()
        gate.offer(VideoFrame(frame.buffer, 0, frame.timestampNs))
    }

    // ------------------------------------------------------------------ status

    /** Turns the effect off for a reason Dart shows; the raw camera goes on. */
    private fun fail(newState: String, why: String) {
        active = false
        gate.clear()
        setState(newState, why)
        Log.w(TAG, "effect off: $newState ($why)")
        deepAr.post {
            if (newState == STATE_LICENCE_FAILED || newState == STATE_ERROR) {
                // Start clean on the next pick.
                teardown()
            } else {
                pauseDeepAr()
            }
        }
    }

    private fun pauseDeepAr() {
        val deepAR = synchronized(lock) { instance } ?: return
        try {
            if (blurOn) deepAR.backgroundBlur(false, 0)
            blurOn = false
            deepAR.setPaused(true)
        } catch (error: Throwable) {
            Log.w(TAG, "pausing DeepAR failed: $error")
        }
    }

    private fun setState(next: String, why: String?) {
        if (state == next && reason == why) return
        state = next
        reason = why
        try {
            onStatus(mapOf("state" to next, "reason" to why))
        } catch (error: Throwable) {
            Log.w(TAG, "status not delivered: $error")
        }
    }

    private inner class Listener(private val gen: Int) : AREventListener {
        private fun current() = synchronized(lock) { generation == gen && instance != null }

        override fun initialized() {
            if (!current()) return
            initializedGen = gen
            Log.i(TAG, "DeepAR initialized")
            deepAr.post(::applyEffect)
        }

        override fun error(type: ARErrorType?, message: String?) {
            // Licence problems land here (never contains the key).
            Log.w(TAG, "DeepAR $type: $message")
            if (!current()) return
            lastError = "$type: $message"
            val text = message?.lowercase(Locale.ROOT).orEmpty()
            if (type == ARErrorType.ERROR && (text.contains("licen") || text.contains("license"))) {
                fail(STATE_LICENCE_FAILED, "licence")
            }
        }

        override fun effectSwitched(slot: String?) {
            Log.i(TAG, "effect switched in slot $slot")
        }

        override fun screenshotTaken(bitmap: Bitmap?) {}
        override fun videoRecordingStarted() {}
        override fun videoRecordingFinished() {}
        override fun videoRecordingFailed() {}
        override fun videoRecordingPrepared() {}
        override fun shutdownFinished() {}
        override fun faceVisibilityChanged(visible: Boolean) {}
        override fun imageVisibilityChanged(name: String?, visible: Boolean) {}
        override fun frameAvailable(image: Image?) {}
    }

    companion object {
        private const val TAG = "KabsoCameraFx"
        private const val SLOT = "effect"
        private const val RENDER_TIMEOUT_MS = 40L
        private const val BLUR_STRENGTH = 6

        /** Fresh-render misses in a row (≈ 1 s at 30 fps) before giving up. */
        const val MAX_MISSES = 30

        /** Time to the first fresh render (initialization included). */
        const val WARMUP_MS = 10_000L

        /**
         * One frame handed to DeepAR's thread and not taken for this long
         * (queued behind an effect load included): the thread is stuck.
         */
        const val STALL_MS = 6_000L

        /** DeepAR's input, long side (WebRTC's 720p camera is 1280). */
        const val MAX_LONG_SIDE = 1280

        const val STATE_OFF = "off"
        const val STATE_INITIALIZING = "initializing"
        const val STATE_READY = "ready"
        const val STATE_LICENCE_FAILED = "licence_failed"
        const val STATE_ERROR = "error"
        const val STATE_DISABLED = "disabled"

        fun isFailure(state: String) =
            state == STATE_LICENCE_FAILED || state == STATE_ERROR || state == STATE_DISABLED
    }
}
