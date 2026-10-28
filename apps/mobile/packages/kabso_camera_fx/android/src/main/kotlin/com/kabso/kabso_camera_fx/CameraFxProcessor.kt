package com.kabso.kabso_camera_fx

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import org.webrtc.VideoFrame
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
 */
internal class CameraFxProcessor(
    activity: Activity,
    onStatus: (Map<String, Any?>) -> Unit,
) : LocalVideoTrack.ExternalVideoFrameProcessing {

    private val deepAr = DeepArStage(activity, onStatus)
    private val color = ColorStage()
    private val main = Handler(Looper.getMainLooper())

    /** The frame handed to the track last time; released on the next call. */
    private val lastReturned = AtomicReference<VideoFrame?>(null)

    fun setLicenseKey(key: String) = deepAr.setLicenseKey(key)

    fun setEffect(effect: DeepArStage.Effect?) = deepAr.setEffect(effect)

    fun setColorMatrix(matrix: FloatArray?) = color.setMatrix(matrix)

    /** D144a: DeepAR's state and counters for the diagnostics overlay. */
    fun diagnostics(): Map<String, Any?> = deepAr.diagnostics()

    override fun onFrame(frame: VideoFrame): VideoFrame {
        // Before any bail-out: DeepAR's render texture is single and must
        // come back, and the colour stage's textures are a small pool.
        lastReturned.getAndSet(null)?.release()

        val effected = deepAr.process(frame)
        val input = effected ?: frame
        val colored = color.process(input)
        if (colored != null) {
            // Drawn and finished on the GPU: DeepAR's texture can go back.
            effected?.release()
            lastReturned.set(colored)
            return colored
        }
        if (effected != null) {
            lastReturned.set(effected)
            return effected
        }
        return frame
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

    /** Releases DeepAR and the GPU stage (after [detachFrom]). */
    fun dispose() {
        // After a frame the sink may still hold has been released.
        main.postDelayed({
            deepAr.dispose()
            color.dispose()
        }, STALE_RELEASE_DELAY_MS * 2)
    }

    private companion object {
        const val STALE_RELEASE_DELAY_MS = 250L
    }
}
