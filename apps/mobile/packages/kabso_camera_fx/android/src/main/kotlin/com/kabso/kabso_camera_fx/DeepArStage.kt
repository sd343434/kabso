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
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * D144: the DeepAR stage of [CameraFxProcessor].
 *
 * Per frame (capture thread): texture frame → `toI420()` → NV21 (libyuv via
 * [YuvHelper], into one of two rotating direct buffers) → DeepAR's own thread
 * `receiveFrame` → DeepAR renders into a [Surface] owned by a WebRTC
 * [SurfaceTextureHelper] created on flutter_webrtc's root EGL context (the
 * capturer's and encoder's share group) → that texture frame (rotation 0:
 * DeepAR renders upright) is handed back. The output never leaves the GPU.
 *
 * Rules that keep it safe:
 * - No effect selected → [process] returns null (the frame passes untouched)
 *   and DeepAR is paused. DeepAR is initialized only when an effect is first
 *   picked (DeepAR counts monthly active users by initialization).
 * - The capture thread waits at most [RENDER_TIMEOUT_MS] for DeepAR's render,
 *   then the raw frame passes.
 * - Never hold a "latest output" frame: the helper owns ONE texture, so a
 *   held frame stops it rendering again (deadlock). The caller releases the
 *   frame [process] returns before the next call.
 * - Viewers get the true (unmirrored) picture: `mirror=false`. The host's
 *   preview still mirrors the front camera in its renderer.
 *
 * Adapted from voxa_deepar's DeepArBridgeFilter (MIT; see the package's
 * THIRD_PARTY_NOTICES.md).
 */
internal class DeepArStage(private val activity: Activity) {

    /** What [setEffect] can load. */
    sealed interface Effect {
        /** An effect built into the DeepAR SDK (no file). */
        data class Builtin(val name: String) : Effect

        /** A `.deepar` file in the APK's assets. */
        data class Asset(val path: String) : Effect
    }

    // DeepAR pins itself to the thread that initialized it: every call goes
    // through this one, never the capture or main thread.
    private val deepArThread = HandlerThread("KabsoDeepAr").apply { start() }
    private val deepAr = Handler(deepArThread.looper)

    private val lock = Any()

    // Guarded by [lock].
    private var instance: DeepAR? = null
    private var licenseKey: String? = null
    private var effect: Effect? = null
    private var surfaceHelper: SurfaceTextureHelper? = null
    private var renderSurface: Surface? = null
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var surfaceRotation = -1
    private var configuring = false
    private val inputBuffers = arrayOfNulls<ByteBuffer>(2)
    private var inputSlot = 0

    /** An effect is selected: the only state in which frames are touched. */
    @Volatile private var active = false
    private val initialized = AtomicBoolean(false)
    private val disposed = AtomicBoolean(false)

    private val slot = Slot()

    private var reportedTimeout = false
    private var statFrames = 0
    private var statRendered = 0
    private var statWaitNanos = 0L
    private var statWindowStart = 0L

    fun setLicenseKey(key: String) {
        synchronized(lock) { licenseKey = key }
    }

    /** `null`: no effect (pass-through, DeepAR paused). */
    fun setEffect(next: Effect?) {
        synchronized(lock) { effect = next }
        active = next != null
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

    // ------------------------------------------------------------ DeepAR thread

    private fun startIfNeeded() {
        val key: String
        val created: DeepAR
        synchronized(lock) {
            if (instance != null || disposed.get()) return
            key = licenseKey ?: run {
                Log.w(TAG, "an effect was picked before init(licenseKey): ignored")
                return
            }
            created = DeepAR(activity)
            instance = created
        }
        created.setLicenseKey(key)
        created.initialize(activity, Listener())
        // Live mode: no still-capture pipeline kept warm.
        created.changeLiveMode(true)
        Log.i(TAG, "DeepAR initializing (SDK ${DeepAR.getSdkVersion()})")
    }

    private fun applyEffect() {
        val deepAR: DeepAR
        val next: Effect?
        synchronized(lock) {
            deepAR = instance ?: return
            next = effect
        }
        if (!initialized.get()) return // re-applied from initialized()
        try {
            when (next) {
                null -> {
                    deepAR.backgroundBlur(false, 0)
                    deepAR.switchEffect(SLOT, null as String?)
                    deepAR.setPaused(true)
                }
                is Effect.Builtin -> {
                    deepAR.setPaused(false)
                    deepAR.switchEffect(SLOT, null as String?)
                    when (next.name) {
                        "background_blur" -> deepAR.backgroundBlur(true, BLUR_STRENGTH)
                        else -> Log.w(TAG, "unknown built-in effect ${next.name}")
                    }
                }
                is Effect.Asset -> {
                    deepAR.setPaused(false)
                    deepAR.backgroundBlur(false, 0)
                    activity.assets.open(next.path).use { stream ->
                        deepAR.switchEffect(SLOT, stream)
                    }
                }
            }
        } catch (error: Throwable) {
            Log.w(TAG, "switching the effect failed: $error")
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
            surfaceRotation = -1
            inputBuffers[0] = null
            inputBuffers[1] = null
        }
        initialized.set(false)
        slot.clear()
        helper?.stopListening()
        helper?.dispose()
        surface?.release()
        try {
            deepAR?.release()
        } catch (error: Throwable) {
            Log.w(TAG, "DeepAR release failed: $error")
        }
        Log.i(TAG, "DeepAR released")
    }

    private fun configureSurface(width: Int, height: Int, rotation: Int) {
        val oldHelper: SurfaceTextureHelper?
        val oldSurface: Surface?
        val deepAR: DeepAR?
        synchronized(lock) {
            oldHelper = surfaceHelper
            oldSurface = renderSurface
            deepAR = instance
            surfaceHelper = null
            renderSurface = null
        }
        slot.clear()
        oldHelper?.stopListening()
        oldHelper?.dispose()
        oldSurface?.release()
        if (deepAR == null) {
            synchronized(lock) { configuring = false }
            return
        }
        try {
            val helper = SurfaceTextureHelper.create("KabsoDeepArRender", EglUtils.getRootEglBaseContext())
                ?: throw IllegalStateException("no SurfaceTextureHelper")
            helper.setTextureSize(width, height)
            val surface = Surface(helper.surfaceTexture)
            helper.startListening(::onRendered)
            deepAR.setRenderSurface(surface, width, height)
            synchronized(lock) {
                surfaceHelper = helper
                renderSurface = surface
                surfaceWidth = width
                surfaceHeight = height
                surfaceRotation = rotation
                configuring = false
            }
            Log.i(TAG, "render surface ${width}x$height")
        } catch (error: Throwable) {
            synchronized(lock) { configuring = false }
            Log.w(TAG, "could not create the render surface: $error")
        }
    }

    // ----------------------------------------------------------- capture thread

    /**
     * The frame with the effect, owned by the caller (release it before the
     * next call), or null: pass [frame] on as it is.
     */
    fun process(frame: VideoFrame): VideoFrame? {
        if (!active) return null
        val deepAR = synchronized(lock) { instance } ?: return null

        val rotation = frame.rotation
        val width = frame.buffer.width
        val height = frame.buffer.height
        val quarterTurn = rotation == 90 || rotation == 270
        val outWidth = if (quarterTurn) height else width
        val outHeight = if (quarterTurn) width else height

        // Surface first, then the initialized gate: DeepAR signals
        // initialized() from its render thread, which needs a surface.
        if (!ensureSurface(outWidth, outHeight, rotation)) return null
        if (!initialized.get()) return null

        val input = packNv21(frame) ?: return null
        deepAr.post {
            try {
                deepAR.receiveFrame(
                    input, width, height, rotation, false, DeepARImageFormat.YUV_NV21, 1,
                )
            } catch (error: Throwable) {
                Log.w(TAG, "receiveFrame failed: $error")
            }
        }

        val waitStart = System.nanoTime()
        val rendered = slot.take(RENDER_TIMEOUT_MS)
        record(rendered != null, System.nanoTime() - waitStart)
        if (rendered == null) {
            if (!reportedTimeout) {
                reportedTimeout = true
                Log.w(TAG, "no render within $RENDER_TIMEOUT_MS ms: raw frame passed (once)")
            }
            return null
        }
        // The capture timestamp, not the render one: keeps A/V sync.
        return VideoFrame(rendered.buffer, 0, frame.timestampNs)
    }

    private fun ensureSurface(width: Int, height: Int, rotation: Int): Boolean {
        synchronized(lock) {
            if (surfaceHelper != null && surfaceWidth == width &&
                surfaceHeight == height && surfaceRotation == rotation
            ) {
                return true
            }
            if (configuring) return false
            configuring = true
        }
        deepAr.post { configureSurface(width, height, rotation) }
        return false
    }

    /** I420 → NV21 (Y plane, then V/U interleaved) in libyuv; 2 rotating buffers. */
    private fun packNv21(frame: VideoFrame): ByteBuffer? {
        val i420 = try {
            frame.buffer.toI420()
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

    /** Once a second: effective fps, share with the effect, average wait. */
    private fun record(rendered: Boolean, waitNanos: Long) {
        val now = System.nanoTime()
        if (statWindowStart == 0L) statWindowStart = now
        statFrames++
        if (rendered) statRendered++
        statWaitNanos += waitNanos
        val elapsed = now - statWindowStart
        if (elapsed < 1_000_000_000L) return
        Log.i(
            TAG,
            String.format(
                java.util.Locale.ROOT,
                "%.1f fps, %d/%d with effect, wait %.1f ms",
                statFrames / (elapsed / 1e9), statRendered, statFrames,
                statWaitNanos / 1e6 / statFrames,
            ),
        )
        statWindowStart = now
        statFrames = 0
        statRendered = 0
        statWaitNanos = 0
    }

    // ------------------------------------------------------- render (helper) thread

    private fun onRendered(frame: VideoFrame) {
        // The helper releases this frame when we return: retain to keep it.
        frame.buffer.retain()
        slot.offer(VideoFrame(frame.buffer, 0, frame.timestampNs))
    }

    /** One-deep handoff render thread → capture thread; holder releases. */
    private class Slot {
        private val lock = ReentrantLock()
        private val filled = lock.newCondition()
        private var frame: VideoFrame? = null

        fun offer(next: VideoFrame) {
            val stale = lock.withLock {
                val previous = frame
                frame = next
                filled.signalAll()
                previous
            }
            stale?.release()
        }

        fun take(timeoutMs: Long): VideoFrame? = lock.withLock {
            var remaining = TimeUnit.MILLISECONDS.toNanos(timeoutMs)
            try {
                while (frame == null && remaining > 0) remaining = filled.awaitNanos(remaining)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            val taken = frame
            frame = null
            taken
        }

        fun clear() {
            val stale = lock.withLock {
                val previous = frame
                frame = null
                previous
            }
            stale?.release()
        }
    }

    private inner class Listener : AREventListener {
        override fun initialized() {
            initialized.set(true)
            Log.i(TAG, "DeepAR initialized")
            deepAr.post(::applyEffect)
        }

        override fun error(type: ARErrorType?, message: String?) {
            // Licence problems land here (never contains the key).
            Log.w(TAG, "DeepAR $type: $message")
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

    private companion object {
        const val TAG = "KabsoCameraFx"
        const val SLOT = "effect"
        const val RENDER_TIMEOUT_MS = 40L
        const val BLUR_STRENGTH = 6
    }
}
