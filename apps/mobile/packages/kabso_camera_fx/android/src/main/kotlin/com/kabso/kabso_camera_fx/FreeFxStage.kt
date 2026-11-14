package com.kabso.kabso_camera_fx

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.cloudwebrtc.webrtc.utils.EglUtils
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import org.webrtc.EglBase
import org.webrtc.GlRectDrawer
import org.webrtc.GlTextureFrameBuffer
import org.webrtc.RendererCommon
import org.webrtc.TextureBufferImpl
import org.webrtc.VideoFrame
import org.webrtc.VideoFrameDrawer
import org.webrtc.YuvConverter
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * D228: the **free** effects engine — runs instead of [DeepArStage] when the
 * engine switch says `free` ([CameraFxProcessor.setEngine]). DeepAR stays as
 * it is; this stage and its two dependencies can be removed on their own
 * (docs/KNOWN_LIMITATIONS.md, D228).
 *
 * - **Background blur:** Google ML Kit Selfie Segmentation (on-device, the
 *   model ships inside its AAR), stream mode, raw 256 × 256 mask on a
 *   downscaled frame; the mask is smoothed over time ([MaskSmoother]),
 *   uploaded as a texture and composited over a quarter-size Gaussian blur
 *   of the frame ([FreeFxGl]).
 * - **Beauty:** MediaPipe Face Landmarker (on-device; the model
 *   `face_landmarker.task` is downloaded once from Google's public storage
 *   into the app's files and checked against a pinned SHA-256 — [ModelFile];
 *   not in the APK) → [LandmarkSmoother] → [FaceShape] → one GLSL pass:
 *   skin smoothing (bilateral, masked to the face skin), brighten/whiten,
 *   subtle face slimming and eye enlargement ([WarpMath]).
 *
 * Frame path (capture thread, [process]): the frame is retained and drawn on
 * this stage's own GL thread (EGL context sharing flutter_webrtc's root
 * context, like [ColorStage]): copied upright into an RGBA texture, every
 * other frame a 256-px copy read back for the analysis thread (only when it
 * is idle — the analysis never blocks a frame; its results apply to the next
 * frames), then the effect passes into one of three output textures.
 * Not done within [FRAME_BUDGET_MS] → the raw frame goes on (as DeepAR's
 * 40 ms rule); repeatedly slow → [FrameBudget] backs off, then gives up
 * (`too_slow`). Any GL error turns the stage off for good ([FreeFxMachine]),
 * any init failure turns the effect off with a reason — never a crash, never
 * a frozen or black picture: until what the effect needs is there (the
 * first mask, the face model) the raw frames go out.
 *
 * Nothing of the picture leaves the device: ML Kit and MediaPipe run
 * locally. (Both SDKs send Google their own usage/performance statistics
 * through Google's `datatransport` — see THIRD_PARTY_NOTICES.md.)
 */
internal class FreeFxStage(
    context: Context,
    private val onStatus: (Map<String, Any?>) -> Unit,
) {
    private val appContext = context.applicationContext
    private val machine = FreeFxMachine { state, reason -> report(state, reason) }
    private val budget = FrameBudget(budgetNanos = TimeUnit.MILLISECONDS.toNanos(FRAME_BUDGET_MS))
    private val path = FreeFxFramePath<VideoFrame>(machine, budget)

    private val glThread = HandlerThread("KabsoFreeFxGl").apply { start() }
    private val gl = Handler(glThread.looper)
    private val analysisThread = HandlerThread("KabsoFreeFxAnalysis").apply { start() }
    private val analysis = Handler(analysisThread.looper)
    private val main = Handler(Looper.getMainLooper())
    private val disposed = AtomicBoolean(false)

    // GL thread only.
    private var egl: EglBase? = null
    private var rect: GlRectDrawer? = null
    private var frameDrawer: VideoFrameDrawer? = null
    private var yuvConverter: YuvConverter? = null
    private var fx: FreeFxGl? = null
    private var source: GlTextureFrameBuffer? = null
    private var analysisTarget: GlTextureFrameBuffer? = null
    private var readback: ByteBuffer? = null
    private val pacer = AnalysisPacer(every = 2)
    private val targets = ArrayList<Target>()
    private var shapeFor: Analysis? = null
    private var shapeParams: FreeFxParams? = null
    private var shape: FaceShape? = null

    /** One GPU job at a time; a frame arriving while it runs passes raw. */
    private val inFlight = AtomicBoolean(false)

    // Analysis thread only.
    private var segmenter: Segmenter? = null
    private var landmarker: FaceLandmarker? = null
    private var bitmap: Bitmap? = null
    private val masks = MaskSmoother()
    private val faces = LandmarkSmoother()
    private var lastTimestampMs = 0L
    private var segFailures = 0

    // Shared.
    private val analyzing = AtomicBoolean(false)
    private val latest = AtomicReference<Analysis?>(null)
    private val maskSeq = AtomicLong()
    @Volatile private var segmenterReady = false
    @Volatile private var landmarkerReady = false
    @Volatile private var faceModelFailed = false
    @Volatile private var model: String = MODEL_ABSENT
    @Volatile private var lastError: String? = null
    @Volatile private var segMs = 0.0
    @Volatile private var faceMs = 0.0
    @Volatile private var analysisMs = 0.0
    private val analyses = AtomicLong()
    private val startWatch = StartWatch(TimeUnit.MILLISECONDS.toNanos(WARMUP_MS))

    private class Target(val buffer: GlTextureFrameBuffer) {
        var busy = false
        var stale = false
    }

    /** What the analysis thread found last (immutable once published). */
    private class Analysis(
        val seq: Long,
        val mask: ByteArray?,
        val maskW: Int,
        val maskH: Int,
        val maskSeq: Long,
        val landmarks: FloatArray?,
        val presence: Float,
    )

    /** The host's pick for the free engine (main thread). [FreeFxParams.NONE]: off. */
    fun configure(next: FreeFxParams) {
        if (disposed.get()) return
        val start = machine.pick(next)
        if (next.none) {
            startWatch.disarm()
            return
        }
        if (start) {
            budget.reset()
            val token = machine.token()
            startWatch.arm(System.nanoTime(), path.framesIn)
            main.postDelayed({ checkStart(token) }, WARMUP_MS)
        }
        // Load what the pick needs (no-op when already loaded).
        analysis.post { prepare(next) }
    }

    /**
     * The frame with the effect (owned by the caller), or null: pass [frame]
     * on as it is. Capture thread.
     */
    fun process(frame: VideoFrame): VideoFrame? {
        if (disposed.get()) return null
        return path.process(frame, ::render)
    }

    fun diagnostics(): Map<String, Any?> = mapOf(
        "state" to machine.state,
        "reason" to machine.reason,
        "lastError" to lastError,
        "framesIn" to path.framesIn,
        "framesOut" to path.framesOut,
        "timeouts" to path.raw,
        "frameMs" to path.avgMs,
        "lastFrameMs" to path.lastMs,
        "budgetMs" to FRAME_BUDGET_MS,
        "slowFrames" to budget.slowTotal,
        "skippedFrames" to budget.skippedTotal,
        "backoffs" to budget.backoffCount,
        "analysisMs" to analysisMs,
        "segmentMs" to segMs,
        "landmarkMs" to faceMs,
        "analyses" to analyses.get(),
        "facePresent" to ((latest.get()?.presence ?: 0f) > 0f),
        "faceModel" to model,
        "initialized" to (segmenterReady || landmarkerReady),
    )

    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        startWatch.disarm()
        gl.post {
            for (target in targets) if (!target.busy) target.buffer.release()
            targets.clear()
            fx?.release()
            source?.release()
            analysisTarget?.release()
            rect?.release()
            frameDrawer?.release()
            yuvConverter?.release()
            fx = null
            source = null
            analysisTarget = null
            rect = null
            frameDrawer = null
            yuvConverter = null
            egl?.release()
            egl = null
            glThread.quitSafely()
        }
        analysis.post {
            try {
                segmenter?.close()
                landmarker?.close()
            } catch (error: Throwable) {
                Log.w(TAG, "free fx: closing the models failed: $error")
            }
            segmenter = null
            landmarker = null
            bitmap?.recycle()
            bitmap = null
            analysisThread.quitSafely()
        }
    }

    // ------------------------------------------------------------ capture thread

    private fun render(frame: VideoFrame, params: FreeFxParams): FreeFxFramePath.Outcome<VideoFrame> {
        // One GPU job at a time: a frame arriving while the last one still
        // runs (it went out raw) goes out raw too.
        if (!inFlight.compareAndSet(false, true)) return FreeFxFramePath.Outcome.TimedOut
        // The job owns a reference: a late job never reads a texture the
        // camera already reuses.
        frame.retain()
        val result = try {
            TimedJob.run(
                TimeUnit.MILLISECONDS.toNanos(FRAME_BUDGET_MS),
                post = { job ->
                    gl.post {
                        try {
                            job.run()
                        } finally {
                            frame.release()
                            inFlight.set(false)
                        }
                    }
                },
                discard = { late -> (late as? FreeFxFramePath.Outcome.Drawn)?.frame?.release() },
            ) { draw(frame, params) }
        } catch (failure: FreeFxFramePath.GlFailure) {
            throw failure
        } catch (error: Throwable) {
            throw FreeFxFramePath.GlFailure("draw", error)
        }
        return when (result) {
            is TimedJob.Result.Done -> result.value
            TimedJob.Result.Late -> FreeFxFramePath.Outcome.TimedOut
            TimedJob.Result.NotPosted -> {
                frame.release()
                inFlight.set(false)
                FreeFxFramePath.Outcome.TimedOut
            }
        }
    }

    // ---------------------------------------------------------------- GL thread

    private fun draw(frame: VideoFrame, params: FreeFxParams): FreeFxFramePath.Outcome<VideoFrame> {
        if (disposed.get()) return FreeFxFramePath.Outcome.TimedOut
        if (!ensureGl()) throw FreeFxFramePath.GlFailure("EGL setup")
        val width = frame.rotatedWidth
        val height = frame.rotatedHeight
        if (width <= 0 || height <= 0) return FreeFxFramePath.Outcome.Warming
        try {
            val src = source ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { source = it }
            src.setSize(width, height)
            // 1. The frame (camera OES, RGB or I420) upright into an RGBA texture.
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, src.frameBufferId)
            frameDrawer!!.drawFrame(frame, rect!!, null, 0, 0, width, height)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)

            // 2. Every other frame, while the analysis is idle: a 256-px
            // top-down copy for ML Kit / MediaPipe.
            if (pacer.shouldAnalyze(!analyzing.get())) submitAnalysis(src, frame.timestampNs, params)

            // 3. What the effect needs must be there, else the raw frame goes.
            val result = latest.get()
            val fxGl = fx!!
            if (result?.mask != null && result.maskSeq != fxGl.maskSeq) {
                fxGl.uploadMask(result.mask, result.maskW, result.maskH, result.maskSeq)
            }
            if (!ready(params)) return FreeFxFramePath.Outcome.Warming

            // 4. The background, the face, the output.
            val background = if (params.blur && fxGl.hasMask) {
                fxGl.blurBackground(src.textureId, width, height) { texture, into ->
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, into.frameBufferId)
                    rect!!.drawRgb(texture, IDENTITY, width, height, 0, 0, into.width, into.height)
                    GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                }
            } else {
                0
            }
            val face = faceShape(result, params, width.toFloat() / height)
            val target = targetFor(width, height) ?: return FreeFxFramePath.Outcome.TimedOut
            fxGl.drawFx(src.textureId, background, target.buffer, params, face, result?.presence ?: 0f)
            // Read on other threads' contexts (encoder, preview, colour stage).
            GLES20.glFinish()
            target.busy = true
            val buffer = TextureBufferImpl(
                width, height, VideoFrame.TextureBuffer.Type.RGB,
                target.buffer.textureId, Matrix(), gl, yuvConverter!!,
            ) { gl.post { giveBack(target) } }
            return FreeFxFramePath.Outcome.Drawn(VideoFrame(buffer, 0, frame.timestampNs))
        } catch (failure: FreeFxFramePath.GlFailure) {
            throw failure
        } catch (error: Throwable) {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            lastError = "gl: $error"
            Log.w(TAG, "free fx: GL failure, stage off: $error")
            throw FreeFxFramePath.GlFailure("draw", error)
        }
    }

    /** Blur needs a mask; beauty needs the landmarker (or blur with beauty given up on). */
    private fun ready(params: FreeFxParams): Boolean {
        val blurOk = !params.blur || fx?.hasMask == true
        val beautyOk = !params.beauty || landmarkerReady || (faceModelFailed && params.blur)
        return blurOk && beautyOk
    }

    private fun faceShape(result: Analysis?, params: FreeFxParams, aspect: Float): FaceShape? {
        if (result?.landmarks == null || !params.beauty || result.presence <= 0f) return null
        if (result === shapeFor && params == shapeParams) return shape
        shapeFor = result
        shapeParams = params
        shape = FaceShape.from(result.landmarks, aspect, params.slim * result.presence)
        return shape
    }

    private fun submitAnalysis(src: GlTextureFrameBuffer, timestampNs: Long, params: FreeFxParams) {
        val (aw, ah) = AnalysisSize.of(src.width, src.height, ANALYSIS_LONG_SIDE)
        val target = analysisTarget ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { analysisTarget = it }
        target.setSize(aw, ah)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, target.frameBufferId)
        // Flipped: rows come back top-down, as the models expect.
        rect!!.drawRgb(src.textureId, FLIP, src.width, src.height, 0, 0, aw, ah)
        val bytes = aw * ah * 4
        val buffer = readback?.takeIf { it.capacity() >= bytes }
            ?: ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder()).also { readback = it }
        buffer.clear()
        GLES20.glReadPixels(0, 0, aw, ah, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        if (!analyzing.compareAndSet(false, true)) return
        val posted = analysis.post { analyze(buffer, aw, ah, timestampNs / 1_000_000, params) }
        if (!posted) analyzing.set(false)
    }

    private fun giveBack(target: Target) {
        target.busy = false
        if (target.stale || disposed.get()) {
            targets.remove(target)
            target.buffer.release()
        }
    }

    private fun targetFor(width: Int, height: Int): Target? {
        val iterator = targets.iterator()
        while (iterator.hasNext()) {
            val target = iterator.next()
            if (target.buffer.width == width && target.buffer.height == height) continue
            if (target.busy) {
                target.stale = true
            } else {
                target.buffer.release()
                iterator.remove()
            }
        }
        targets.firstOrNull { !it.busy && !it.stale }?.let { return it }
        if (targets.count { !it.stale } >= POOL_SIZE) return null
        val buffer = GlTextureFrameBuffer(GLES20.GL_RGBA)
        buffer.setSize(width, height)
        return Target(buffer).also(targets::add)
    }

    private fun ensureGl(): Boolean {
        if (egl != null) return true
        return try {
            val root = EglUtils.getRootEglBaseContext() ?: throw IllegalStateException("no root EGL context")
            val base = EglBase.create(root, EglBase.CONFIG_PIXEL_BUFFER)
            base.createDummyPbufferSurface()
            base.makeCurrent()
            egl = base
            rect = GlRectDrawer()
            frameDrawer = VideoFrameDrawer()
            yuvConverter = YuvConverter()
            fx = FreeFxGl()
            true
        } catch (error: Throwable) {
            lastError = "egl: $error"
            Log.w(TAG, "free fx: EGL setup failed, stage off: $error")
            false
        }
    }

    // ----------------------------------------------------------- analysis thread

    /** Creates what [params] needs: the segmenter for blur, the landmarker for beauty. */
    private fun prepare(params: FreeFxParams) {
        if (disposed.get()) return
        if (params.blur && segmenter == null) {
            try {
                segmenter = Segmentation.getClient(
                    SelfieSegmenterOptions.Builder()
                        .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE)
                        .enableRawSizeMask()
                        .build(),
                )
                segmenterReady = true
                segFailures = 0
            } catch (error: Throwable) {
                lastError = "segmenter: $error"
                Log.w(TAG, "free fx: ML Kit segmenter could not start: $error")
                machine.onInitFailed()
                return
            }
        }
        if (params.beauty && landmarker == null) {
            if (faceModelFailed && machine.state == FreeFxMachine.STATE_READY) return
            model = MODEL_DOWNLOADING
            try {
                val file = ModelFile(
                    File(appContext.filesDir, MODEL_DIR),
                    ModelFile.FACE_LANDMARKER_NAME,
                    ModelFile.FACE_LANDMARKER_URL,
                    ModelFile.FACE_LANDMARKER_SHA256,
                ).ensure()
                val mapped = RandomAccessFile(file, "r").use { raf ->
                    raf.channel.map(FileChannel.MapMode.READ_ONLY, 0, raf.length())
                }
                landmarker = FaceLandmarker.createFromOptions(
                    appContext,
                    FaceLandmarker.FaceLandmarkerOptions.builder()
                        .setBaseOptions(BaseOptions.builder().setModelAssetBuffer(mapped).build())
                        .setRunningMode(RunningMode.VIDEO)
                        .setNumFaces(1)
                        .setMinFaceDetectionConfidence(0.5f)
                        .setMinFacePresenceConfidence(0.5f)
                        .setMinTrackingConfidence(0.5f)
                        .setOutputFaceBlendshapes(false)
                        .setOutputFacialTransformationMatrixes(false)
                        .build(),
                )
                model = MODEL_READY
                faceModelFailed = false
                landmarkerReady = true
                machine.onFaceModelReady()
            } catch (error: Throwable) {
                model = MODEL_FAILED
                faceModelFailed = true
                lastError = "face model: $error"
                Log.w(TAG, "free fx: face model unavailable: $error")
                machine.onFaceModelFailed()
            }
        }
    }

    private fun analyze(rgba: ByteBuffer, w: Int, h: Int, timestampMs: Long, params: FreeFxParams) {
        try {
            if (disposed.get()) return
            val start = SystemClock.elapsedRealtimeNanos()
            val bmp = bitmap?.takeIf { it.width == w && it.height == h }
                ?: Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also {
                    bitmap?.recycle()
                    bitmap = it
                }
            rgba.position(0)
            bmp.copyPixelsFromBuffer(rgba)
            val previous = latest.get()

            var mask = previous?.mask
            var maskW = previous?.maskW ?: 0
            var maskH = previous?.maskH ?: 0
            var maskId = previous?.maskSeq ?: -1L
            val seg = segmenter
            if (params.blur && seg != null) {
                val t0 = SystemClock.elapsedRealtimeNanos()
                try {
                    val result = Tasks.await(seg.process(InputImage.fromBitmap(bmp, 0)), 500, TimeUnit.MILLISECONDS)
                    val buffer = result.buffer
                    buffer.rewind()
                    val floats = buffer.asFloatBuffer()
                    val cells = result.width * result.height
                    val values = FloatArray(cells)
                    floats.get(values, 0, minOf(cells, floats.remaining()))
                    masks.push(values, result.width, result.height)
                    mask = masks.toBytes()
                    maskW = result.width
                    maskH = result.height
                    maskId = maskSeq.incrementAndGet()
                    segFailures = 0
                } catch (error: Throwable) {
                    lastError = "segment: $error"
                    if (++segFailures >= MAX_SEG_FAILURES) {
                        Log.w(TAG, "free fx: segmentation keeps failing: $error")
                        machine.onInitFailed()
                    }
                }
                segMs = (SystemClock.elapsedRealtimeNanos() - t0) / 1e6
            }

            var points = previous?.landmarks
            val marker = landmarker
            if (params.beauty && marker != null) {
                val t0 = SystemClock.elapsedRealtimeNanos()
                // detectForVideo needs strictly increasing timestamps.
                val ts = if (timestampMs > lastTimestampMs) timestampMs else lastTimestampMs + 1
                lastTimestampMs = ts
                try {
                    val result = marker.detectForVideo(BitmapImageBuilder(bmp).build(), ts)
                    val face = result.faceLandmarks().firstOrNull()
                    val found = face?.let { list ->
                        FloatArray(list.size * 2).also { out ->
                            for (i in list.indices) {
                                out[2 * i] = list[i].x()
                                out[2 * i + 1] = list[i].y()
                            }
                        }
                    }
                    points = faces.push(found)?.copyOf()
                } catch (error: Throwable) {
                    lastError = "landmarks: $error"
                    points = faces.push(null)?.copyOf()
                }
                faceMs = (SystemClock.elapsedRealtimeNanos() - t0) / 1e6
            } else if (!params.beauty) {
                faces.reset()
                points = null
            }
            latest.set(
                Analysis(
                    analyses.incrementAndGet(), mask, maskW, maskH, maskId, points,
                    if (points == null) 0f else faces.presence,
                ),
            )
            analysisMs = (SystemClock.elapsedRealtimeNanos() - start) / 1e6
        } catch (error: Throwable) {
            lastError = "analysis: $error"
            Log.w(TAG, "free fx: analysis failed: $error")
        } finally {
            analyzing.set(false)
        }
    }

    // ------------------------------------------------------------------ status

    private fun checkStart(token: Int) {
        if (disposed.get() || token != machine.token()) return
        val initialized = segmenterReady || landmarkerReady
        val verdict = startWatch.check(System.nanoTime(), path.framesIn, initialized)
        if (verdict == StartWatch.Verdict.WAITING) {
            main.postDelayed({ checkStart(token) }, START_RECHECK_MS)
            return
        }
        if (path.framesOut > 0) startWatch.onOutput()
        machine.onStartVerdict(token, verdict)
    }

    private fun report(state: String, reason: String?) {
        if (state == FreeFxMachine.STATE_READY) startWatch.onOutput()
        if (FreeFxMachine.isFailure(state)) {
            startWatch.disarm()
            Log.w(TAG, "free fx off: $state ($reason)")
        }
        try {
            onStatus(mapOf("state" to state, "reason" to reason, "engine" to "free"))
        } catch (error: Throwable) {
            Log.w(TAG, "free fx: status not delivered: $error")
        }
    }

    companion object {
        private const val TAG = "KabsoCameraFx"

        /** Like DeepAR's wait: a frame not done in 40 ms goes out raw. */
        const val FRAME_BUDGET_MS = 40L

        /** The start watch: the face model download is included. */
        const val WARMUP_MS = 20_000L
        private const val START_RECHECK_MS = 500L
        private const val POOL_SIZE = 3
        private const val ANALYSIS_LONG_SIDE = 256
        private const val MAX_SEG_FAILURES = 10
        private const val MODEL_DIR = "kabso_camera_fx"

        const val MODEL_ABSENT = "absent"
        const val MODEL_DOWNLOADING = "downloading"
        const val MODEL_READY = "ready"
        const val MODEL_FAILED = "failed"

        private val IDENTITY = RendererCommon.convertMatrixFromAndroidGraphicsMatrix(Matrix())
        private val FLIP = RendererCommon.convertMatrixFromAndroidGraphicsMatrix(
            Matrix().apply {
                preTranslate(0.5f, 0.5f)
                preScale(1f, -1f)
                preTranslate(-0.5f, -0.5f)
            },
        )
    }
}
