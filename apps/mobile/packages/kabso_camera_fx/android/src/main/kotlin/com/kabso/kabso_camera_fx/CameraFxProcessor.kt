package com.kabso.kabso_camera_fx

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import org.webrtc.VideoFrame
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * D144: the camera processor, installed with flutter_webrtc's
 * `LocalVideoTrack.addProcessor`, so whatever it returns is what the local
 * preview renders and what the encoder sends.
 *
 * camera frame → [DeepArStage] (an effect is picked) → [ColorStage] (a colour
 * filter is picked) → the track. Each stage passes the frame untouched when it
 * has nothing to do, so with neither picked the processor costs nothing.
 *
 * flutter_webrtc releases only the frame the capturer made; a frame a stage
 * made is ours. The one handed to the track is released at the start of the
 * next call (the sink is done with it by then: `onFrameCaptured` is
 * synchronous); an intermediate one as soon as the next stage has drawn it.
 *
 * D144b: [cameraFrames] counts every frame the track hands us (effect or not)
 * and [framePath] says how the attach found the track ([FramePath]); the
 * overlay shows both, so "the processor gets no camera frames" is visible as
 * such instead of as a DeepAR that never starts.
 *
 * D228: a second, free effects engine ([FreeFxStage]: ML Kit + MediaPipe +
 * GLSL) can run **instead of** DeepAR — [setEngine]. One engine at a time:
 * switching turns the other one off (DeepAR released, never initialized
 * while the free engine is picked). The free stage is created only when
 * that engine is first chosen. The colour stage follows either.
 */
internal class CameraFxProcessor(
    activity: Activity,
    onStatus: (Map<String, Any?>) -> Unit,
) : LocalVideoTrack.ExternalVideoFrameProcessing {

    private val deepAr = DeepArStage(activity, onStatus)

    /** D228: which effects engine runs; the free stage is made on first use. */
    enum class Engine { DEEPAR, FREE }

    @Volatile private var engine = Engine.DEEPAR
    private val freeFx = lazy { FreeFxStage(activity, onStatus) }
    private val color = ColorStage()
    private val main = Handler(Looper.getMainLooper())

    /** The frame handed to the track last time; released on the next call. */
    private val lastReturned = AtomicReference<VideoFrame?>(null)

    /** D144b: frames the track handed to this processor. */
    private val cameraFrames = AtomicLong()

    /** D144b: how the last attach found its track ([FramePath.Result.code]). */
    @Volatile var framePath: String? = null

    fun setLicenseKey(key: String) = deepAr.setLicenseKey(key)

    /** DeepAR's effect; D228: ignored (None) while the free engine runs. */
    fun setEffect(effect: DeepArStage.Effect?) = deepAr.setEffect(if (engine == Engine.FREE) null else effect)

    fun setColorMatrix(matrix: FloatArray?) = color.setMatrix(matrix)

    /**
     * D228: picks the effects engine. The one left is switched off (DeepAR:
     * its effect to None, so it is released; the free stage: [FreeFxParams.NONE]).
     */
    fun setEngine(next: Engine) {
        if (next == engine) return
        engine = next
        if (next == Engine.FREE) {
            deepAr.setEffect(null)
        } else if (freeFx.isInitialized()) {
            freeFx.value.configure(FreeFxParams.NONE)
        }
    }

    /** D228: the free engine's blur and beauty (only used while it is the engine). */
    fun setFreeFx(params: FreeFxParams) {
        if (engine != Engine.FREE && !freeFx.isInitialized()) return
        freeFx.value.configure(if (engine == Engine.FREE) params else FreeFxParams.NONE)
    }

    /** D144a: the engine's state and counters for the diagnostics overlay. */
    fun diagnostics(): Map<String, Any?> {
        val stage = when {
            engine != Engine.FREE -> deepAr.diagnostics()
            freeFx.isInitialized() -> freeFx.value.diagnostics()
            else -> mapOf("state" to FreeFxMachine.STATE_OFF)
        }
        return stage + mapOf(
            "cameraFrames" to cameraFrames.get(),
            "framePath" to framePath,
            "fxEngine" to if (engine == Engine.FREE) "free" else "deepar",
        )
    }

    override fun onFrame(frame: VideoFrame): VideoFrame {
        // Before any bail-out: DeepAR's render texture is single and must
        // come back, and the colour stage's textures are a small pool.
        lastReturned.getAndSet(null)?.release()

        cameraFrames.incrementAndGet()
        // DeepAR (or, D228, the free engine), then the colour transform on
        // its output (D144b: FxChain).
        val effect: (VideoFrame) -> VideoFrame? = when {
            engine != Engine.FREE -> deepAr::process
            // Made by the first pick (setFreeFx); until then nothing to do.
            freeFx.isInitialized() -> freeFx.value::process
            else -> NO_EFFECT
        }
        val (out, ours) = FxChain.run(frame, effect, color::process) { it.release() }
        if (ours) lastReturned.set(out)
        return out
    }

    /** Takes the processor off [track]; called on the main thread. */
    fun detachFrom(track: LocalVideoTrack) {
        // removeProcessor waits for an onFrame in progress (same lock), but the
        // sink may still be reading the frame we returned for a moment: free it
        // a little later instead of under its feet.
        track.removeProcessor(this)
        val stale = lastReturned.getAndSet(null) ?: return
        main.postDelayed({ stale.release() }, STALE_RELEASE_DELAY_MS)
    }

    /** Releases DeepAR, the free stage and the GPU stage (after [detachFrom]). */
    fun dispose() {
        // After a frame the sink may still hold has been released.
        main.postDelayed({
            deepAr.dispose()
            if (freeFx.isInitialized()) freeFx.value.dispose()
            color.dispose()
        }, STALE_RELEASE_DELAY_MS * 2)
    }

    private companion object {
        const val STALE_RELEASE_DELAY_MS = 250L
        val NO_EFFECT: (VideoFrame) -> VideoFrame? = { null }
    }
}
