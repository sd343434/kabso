package com.kabso.kabso_camera_fx

import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

// D228: the plain-Kotlin rules of [FreeFxStage] — the free engine (Google ML
// Kit selfie segmentation + MediaPipe Face Landmarker, GLSL on the GPU) — with
// no Android, GL or SDK type, so the JVM unit tests in src/test exercise
// exactly what the device runs. Removing the free engine removes this file
// with FreeFxStage.kt and FreeFxGl.kt (docs/KNOWN_LIMITATIONS.md, D228).

/**
 * What the host picked for the free engine. Strengths are 0 … 1 (the Magic
 * sheet's sliders are 0 … 100).
 */
internal data class FreeFxParams(
    val blur: Boolean = false,
    val smooth: Float = 0f,
    val brighten: Float = 0f,
    val slim: Float = 0f,
    val eyes: Float = 0f,
) {
    /** Beauty needs the face landmarks (and so the face model). */
    val beauty: Boolean get() = smooth > 0f || brighten > 0f || slim > 0f || eyes > 0f

    /** Nothing to do: the stage passes every frame untouched and costs nothing. */
    val none: Boolean get() = !blur && !beauty

    /** Values clamped to 0 … 1 (NaN → 0). */
    fun clamped() = FreeFxParams(blur, unit(smooth), unit(brighten), unit(slim), unit(eyes))

    companion object {
        val NONE = FreeFxParams()

        /** From the channel: missing or bad values are 0. */
        fun fromMap(map: Map<*, *>?): FreeFxParams {
            if (map == null) return NONE
            fun f(key: String) = (map[key] as? Number)?.toFloat() ?: 0f
            return FreeFxParams(
                blur = map["blur"] == true,
                smooth = f("smooth"),
                brighten = f("brighten"),
                slim = f("slim"),
                eyes = f("eyes"),
            ).clamped()
        }

        private fun unit(v: Float) = if (v.isNaN()) 0f else v.coerceIn(0f, 1f)
    }
}

/**
 * D228: the free stage's state, with the same names Dart parses for DeepAR
 * (`KabsoCameraFxState`), so Magic's honest messages work for both engines.
 *
 * - off → (a pick) initializing → (first processed frame) ready.
 * - Any failure → error / disabled with a reason; the raw camera goes on. A
 *   later pick starts again — except after a GL failure ([glBroken]), which
 *   keeps the stage off for the life of the processor (a new live retries).
 * - The face model missing while blur is on: still ready, reason
 *   `beauty_unavailable` (blur works, the beauty sliders say why); with
 *   beauty alone: error `model_unavailable`.
 *
 * Thread-safe (picks on the main thread, frames on the capture thread,
 * analysis and the start timer on their own).
 */
internal class FreeFxMachine(private val onChange: (String, String?) -> Unit = { _, _ -> }) {
    var state: String = STATE_OFF
        private set
    var reason: String? = null
        private set
    var glBroken = false
        private set
    private var params = FreeFxParams.NONE
    private var token = 0

    val active: Boolean @Synchronized get() = !params.none && (state == STATE_INITIALIZING || state == STATE_READY)

    @Synchronized fun params() = params

    /** The current pick's token (a later pick supersedes timers of this one). */
    @Synchronized fun token() = token

    /** A new pick (or None). Returns whether the stage should start (models, GL). */
    @Synchronized
    fun pick(next: FreeFxParams): Boolean {
        val was = params
        params = next
        if (next.none) {
            // A failure stays visible (Dart shows why) until the next pick.
            if (!isFailure(state)) set(STATE_OFF, null)
            return false
        }
        if (glBroken) {
            set(STATE_ERROR, REASON_GL)
            return false
        }
        val newPick = was.none || isFailure(state) || state == STATE_OFF
        if (newPick) {
            token++
            set(STATE_INITIALIZING, null)
            return true
        }
        // Strengths changed while running: nothing to restart; the beauty
        // reason may no longer apply.
        if (state == STATE_READY && reason == REASON_BEAUTY_UNAVAILABLE && !next.beauty) set(STATE_READY, null)
        if (state == STATE_READY && reason == null && next.beauty && faceModelFailed) {
            if (next.blur) set(STATE_READY, REASON_BEAUTY_UNAVAILABLE) else fail(STATE_ERROR, REASON_MODEL)
        }
        return false
    }

    /** A frame was published with the effect. */
    @Synchronized
    fun onOutput() {
        if (state != STATE_INITIALIZING) return
        set(STATE_READY, if (faceModelFailed && params.beauty) REASON_BEAUTY_UNAVAILABLE else null)
    }

    private var faceModelFailed = false

    /** The face model could not be loaded (download, checksum, MediaPipe). */
    @Synchronized
    fun onFaceModelFailed() {
        faceModelFailed = true
        if (params.none || isFailure(state)) return
        if (!params.beauty) return
        if (params.blur) {
            if (state == STATE_READY) set(STATE_READY, REASON_BEAUTY_UNAVAILABLE)
        } else {
            fail(STATE_ERROR, REASON_MODEL)
        }
    }

    /** A later attempt may load the model (a new pick after a failure). */
    @Synchronized
    fun onFaceModelReady() {
        faceModelFailed = false
        if (state == STATE_READY && reason == REASON_BEAUTY_UNAVAILABLE) set(STATE_READY, null)
    }

    /** The segmenter or the landmarker could not be created. */
    @Synchronized fun onInitFailed() = fail(STATE_ERROR, REASON_INIT)

    /** Any GL error: the stage is off for good (frames pass untouched). */
    @Synchronized
    fun onGlFailed() {
        glBroken = true
        fail(STATE_ERROR, REASON_GL)
    }

    /** [FrameBudget] gave up: frames kept taking longer than the budget. */
    @Synchronized fun onTooSlow() = fail(STATE_DISABLED, REASON_SLOW)

    /** The start watch ([StartWatch]) decided. */
    @Synchronized
    fun onStartVerdict(token: Int, verdict: StartWatch.Verdict) {
        if (token != this.token || state != STATE_INITIALIZING) return
        when (verdict) {
            StartWatch.Verdict.NO_FRAMES -> fail(STATE_ERROR, "no_frames")
            StartWatch.Verdict.INIT_TIMEOUT -> fail(STATE_ERROR, "init_timeout")
            StartWatch.Verdict.NO_OUTPUT -> fail(STATE_DISABLED, "no_output")
            StartWatch.Verdict.WAITING, StartWatch.Verdict.OK -> Unit
        }
    }

    private fun fail(next: String, why: String) {
        if (state == next && reason == why) return
        set(next, why)
    }

    private fun set(next: String, why: String?) {
        if (state == next && reason == why) return
        state = next
        reason = why
        try {
            onChange(next, why)
        } catch (_: Throwable) {
            // Status delivery never breaks the frame path.
        }
    }

    companion object {
        const val STATE_OFF = "off"
        const val STATE_INITIALIZING = "initializing"
        const val STATE_READY = "ready"
        const val STATE_ERROR = "error"
        const val STATE_DISABLED = "disabled"

        const val REASON_GL = "gl_failed"
        const val REASON_INIT = "init_failed"
        const val REASON_MODEL = "model_unavailable"
        const val REASON_BEAUTY_UNAVAILABLE = "beauty_unavailable"
        const val REASON_SLOW = "too_slow"

        fun isFailure(state: String) = state == STATE_ERROR || state == STATE_DISABLED
    }
}

/**
 * D228: the per-frame time budget. A frame whose GPU work is not done within
 * [budgetNanos] (~40 ms) goes out raw — the same rule as DeepAR's 40 ms wait.
 * [slowInARow] slow frames in a row → the next [backoffFrames] frames pass
 * raw without trying (the phone gets its breath back); [maxBackoffs] backoffs
 * without [recoverFrames] good frames in between → [Verdict.GIVE_UP]
 * (`too_slow`). Capture thread only.
 */
internal class FrameBudget(
    val budgetNanos: Long = 40_000_000L,
    private val slowInARow: Int = 3,
    private val backoffFrames: Int = 30,
    private val maxBackoffs: Int = 3,
    private val recoverFrames: Int = 90,
) {
    enum class Verdict { OK, BACKOFF, GIVE_UP }

    private var slowRun = 0
    private var goodRun = 0
    private var skipLeft = 0
    private var backoffs = 0

    var slowTotal = 0L
        private set
    var skippedTotal = 0L
        private set
    val backoffCount: Int get() = backoffs

    /** Before a frame: false — pass it raw without trying (backing off). */
    fun shouldTry(): Boolean {
        if (skipLeft <= 0) return true
        skipLeft--
        skippedTotal++
        return false
    }

    /** After a frame: how long its GPU work took (or that it timed out). */
    fun record(elapsedNanos: Long, timedOut: Boolean): Verdict {
        val slow = timedOut || elapsedNanos > budgetNanos
        if (!slow) {
            slowRun = 0
            if (++goodRun >= recoverFrames) backoffs = 0
            return Verdict.OK
        }
        slowTotal++
        goodRun = 0
        if (++slowRun < slowInARow) return Verdict.OK
        slowRun = 0
        backoffs++
        if (backoffs >= maxBackoffs) return Verdict.GIVE_UP
        skipLeft = backoffFrames
        return Verdict.BACKOFF
    }

    fun reset() {
        slowRun = 0
        goodRun = 0
        skipLeft = 0
        backoffs = 0
    }
}

/**
 * D228: temporal smoothing of the segmentation mask (one value 0 … 1 per
 * cell): an exponential moving average, so the edge of the person does not
 * flicker between analyses; a new size starts over. Output as bytes for a
 * `GL_LUMINANCE` texture. Analysis thread only.
 */
internal class MaskSmoother(private val alpha: Float = 0.6f) {
    private var values = FloatArray(0)
    var width = 0
        private set
    var height = 0
        private set

    /** [next]: row-major [w] × [h] confidences (0 … 1, clamped). */
    fun push(next: FloatArray, w: Int, h: Int): FloatArray {
        require(next.size >= w * h) { "mask too small" }
        if (w != width || h != height || values.size != w * h) {
            width = w
            height = h
            values = FloatArray(w * h) { next[it].coerceIn(0f, 1f) }
            return values
        }
        for (i in values.indices) {
            val v = next[i].coerceIn(0f, 1f)
            values[i] = alpha * v + (1 - alpha) * values[i]
        }
        return values
    }

    fun toBytes(out: ByteArray = ByteArray(values.size)): ByteArray {
        for (i in values.indices) out[i] = (values[i] * 255f + 0.5f).toInt().coerceIn(0, 255).toByte()
        return out
    }

    fun reset() {
        values = FloatArray(0)
        width = 0
        height = 0
    }
}

/**
 * D228: temporal smoothing of the face landmarks (x, y pairs, image
 * coordinates 0 … 1, y down). An EMA per point; a jump of the face's centre
 * by more than [jump] (fast movement, another face) takes the new points at
 * once instead of sliding. [presence] fades 0 … 1 so effects never pop on or
 * off: up when a face is seen, down after [lostAfter] analyses without one.
 */
internal class LandmarkSmoother(
    private val alpha: Float = 0.55f,
    private val jump: Float = 0.12f,
    private val lostAfter: Int = 3,
    private val fade: Float = 0.34f,
) {
    private var points: FloatArray? = null
    private var missing = 0

    var presence = 0f
        private set

    /** The smoothed points, or null (no face yet / any more). */
    fun current(): FloatArray? = points

    fun push(next: FloatArray?): FloatArray? {
        if (next == null || next.size < 2) {
            missing++
            if (missing >= lostAfter) {
                presence = max(0f, presence - fade)
                if (presence == 0f) points = null
            }
            return points
        }
        missing = 0
        presence = min(1f, presence + fade)
        val prev = points
        if (prev == null || prev.size != next.size || centreDistance(prev, next) > jump) {
            points = next.copyOf()
            return points
        }
        for (i in prev.indices) prev[i] = alpha * next[i] + (1 - alpha) * prev[i]
        return prev
    }

    fun reset() {
        points = null
        missing = 0
        presence = 0f
    }

    private fun centreDistance(a: FloatArray, b: FloatArray): Float {
        var ax = 0f
        var ay = 0f
        var bx = 0f
        var by = 0f
        val n = a.size / 2
        for (i in 0 until n) {
            ax += a[2 * i]; ay += a[2 * i + 1]
            bx += b[2 * i]; by += b[2 * i + 1]
        }
        return hypot((ax - bx) / n, (ay - by) / n)
    }
}

/**
 * D228: the shader's face uniforms from MediaPipe's 478 landmarks, in the
 * output texture's space: `u` 0 … 1 left → right, `v` 0 … 1 **bottom → top**
 * (WebRTC's texture convention; the analysis image is top-down, so
 * `v = 1 − y`), and distances measured with `u` scaled by the aspect
 * (`width / height`), so circles stay circles.
 *
 * Kept subtle on purpose: slimming moves each jaw point by at most
 * [MAX_SLIM] of the face width, the eyes are magnified by at most
 * [MAX_EYES]; [WarpMath] proves neither can fold the picture.
 */
internal data class FaceShape(
    /** Face ellipse: centre (aspect space), half-axes, rotation (radians). */
    val cx: Float, val cy: Float, val ax: Float, val ay: Float, val angle: Float,
    /** Eyes: centre (aspect space) and radius each, for magnification and the skin mask. */
    val eyes: List<Circle>,
    /** Mouth: centre and radius (excluded from smoothing). */
    val mouth: Circle,
    /** Slimming pulls: from (cx, cy) to (tx, ty) within radius r (aspect space). */
    val pulls: List<Pull>,
    val faceWidth: Float,
) {
    data class Circle(val x: Float, val y: Float, val r: Float)
    data class Pull(val cx: Float, val cy: Float, val tx: Float, val ty: Float, val r: Float)

    companion object {
        const val LANDMARKS = 468

        /** MediaPipe face mesh indices. */
        val FACE_OVAL = intArrayOf(
            10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377,
            152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
        )
        const val RIGHT_EYE_OUTER = 33
        const val RIGHT_EYE_INNER = 133
        const val LEFT_EYE_INNER = 362
        const val LEFT_EYE_OUTER = 263
        const val MOUTH_LEFT = 61
        const val MOUTH_RIGHT = 291
        const val LIP_TOP = 0
        const val LIP_BOTTOM = 17
        const val NOSE_TIP = 1
        const val CHIN = 152
        const val FOREHEAD = 10

        /** Jaw points pulled inwards (both sides). */
        val SLIM_POINTS = intArrayOf(132, 361, 172, 397)

        /** Largest jaw shift, as a share of the face width (strength 1). */
        const val MAX_SLIM = 0.035f

        /** Largest eye magnification (strength 1): the centre grows by 1 / (1 − s). */
        const val MAX_EYES = 0.16f

        /**
         * [pts]: x, y pairs (image space, top-down, 0 … 1) for at least
         * [LANDMARKS] points; [aspect]: width / height of the image. Null
         * when the points are too few or degenerate.
         */
        fun from(pts: FloatArray, aspect: Float, slim: Float): FaceShape? {
            if (pts.size < LANDMARKS * 2 || aspect <= 0f) return null
            fun x(i: Int) = pts[2 * i] * aspect
            fun y(i: Int) = 1f - pts[2 * i + 1]

            // Rotation from the eye line (in the upright aspect space).
            val rex = (x(RIGHT_EYE_OUTER) + x(RIGHT_EYE_INNER)) / 2
            val rey = (y(RIGHT_EYE_OUTER) + y(RIGHT_EYE_INNER)) / 2
            val lex = (x(LEFT_EYE_OUTER) + x(LEFT_EYE_INNER)) / 2
            val ley = (y(LEFT_EYE_OUTER) + y(LEFT_EYE_INNER)) / 2
            val angle = atan2(ley - rey, lex - rex)
            val c = cos(-angle)
            val s = sin(-angle)

            var mx = 0f
            var my = 0f
            for (i in FACE_OVAL) { mx += x(i); my += y(i) }
            mx /= FACE_OVAL.size
            my /= FACE_OVAL.size
            // Extents of the oval in the face's own frame.
            var minU = Float.MAX_VALUE; var maxU = -Float.MAX_VALUE
            var minV = Float.MAX_VALUE; var maxV = -Float.MAX_VALUE
            for (i in FACE_OVAL) {
                val dx = x(i) - mx
                val dy = y(i) - my
                val u = dx * c - dy * s
                val v = dx * s + dy * c
                minU = min(minU, u); maxU = max(maxU, u)
                minV = min(minV, v); maxV = max(maxV, v)
            }
            val width = maxU - minU
            val height = maxV - minV
            if (width < 1e-3f || height < 1e-3f || width.isNaN() || height.isNaN()) return null

            val eyeR = hypot(x(RIGHT_EYE_OUTER) - x(RIGHT_EYE_INNER), y(RIGHT_EYE_OUTER) - y(RIGHT_EYE_INNER))
            val eyeL = hypot(x(LEFT_EYE_OUTER) - x(LEFT_EYE_INNER), y(LEFT_EYE_OUTER) - y(LEFT_EYE_INNER))
            val eyes = listOf(Circle(rex, rey, eyeR * 0.9f), Circle(lex, ley, eyeL * 0.9f))

            val mouthW = hypot(x(MOUTH_LEFT) - x(MOUTH_RIGHT), y(MOUTH_LEFT) - y(MOUTH_RIGHT))
            val mouth = Circle(
                (x(MOUTH_LEFT) + x(MOUTH_RIGHT)) / 2,
                (y(LIP_TOP) + y(LIP_BOTTOM)) / 2,
                mouthW * 0.62f,
            )

            // Slimming: each jaw point moves towards the nose–chin line.
            val k = slim.coerceIn(0f, 1f) * MAX_SLIM * width
            val axisX = (x(NOSE_TIP) + x(CHIN)) / 2
            val axisY = (y(NOSE_TIP) + y(CHIN)) / 2
            val pulls = SLIM_POINTS.map { i ->
                val px = x(i)
                val py = y(i)
                val d = hypot(axisX - px, axisY - py).coerceAtLeast(1e-6f)
                Pull(px, py, px + (axisX - px) / d * k, py + (axisY - py) / d * k, width * 0.32f)
            }
            return FaceShape(mx, my, width / 2, height / 2, angle, eyes, mouth, pulls, width)
        }
    }
}

/**
 * D228: the warp the beauty shader applies, as an **inverse map** (for each
 * output point, where to sample the input): the Kotlin twin of
 * `FreeFxGl.FX_FRAGMENT`'s `warp()`, kept equal by hand and tested here.
 * Points are in aspect space ([FaceShape]).
 */
internal object WarpMath {
    /** Smooth 1 → 0 over 0 … 1, zero slope at 1: `(1 − t²)²`. */
    fun falloff(t: Float): Float {
        if (t >= 1f) return 0f
        val q = 1f - t * t
        return q * q
    }

    /** Largest |f'(t)| of [falloff]: 8 / (3√3). */
    val FALLOFF_MAX_SLOPE = 8f / (3f * sqrt(3f))

    /**
     * A pull moving content from (cx, cy) to (tx, ty): the output point p
     * samples `p + (c − t) · falloff(|p − t| / r)`. Identity outside r.
     */
    fun pull(px: Float, py: Float, p: FaceShape.Pull): Pair<Float, Float> {
        val dx = p.cx - p.tx
        val dy = p.cy - p.ty
        val w = falloff(hypot(px - p.tx, py - p.ty) / p.r)
        return (px + dx * w) to (py + dy * w)
    }

    /**
     * The pull never folds the picture (the map stays one-to-one) while its
     * shift is below `r / FALLOFF_MAX_SLOPE`.
     */
    fun pullIsFoldFree(p: FaceShape.Pull): Boolean =
        hypot(p.cx - p.tx, p.cy - p.ty) * FALLOFF_MAX_SLOPE < p.r

    /**
     * Eye magnification by [strength] (0 … [FaceShape.MAX_EYES]) around
     * (ex, ey) within radius r: the output point at distance d samples the
     * input at `d · (1 − s · (1 − d² / r²))` — identity at d ≥ r, the centre
     * enlarged by `1 / (1 − s)`; monotonic in d for s < 1.
     */
    fun magnify(px: Float, py: Float, e: FaceShape.Circle, strength: Float): Pair<Float, Float> {
        val dx = px - e.x
        val dy = py - e.y
        val d = hypot(dx, dy)
        if (d >= e.r || e.r <= 0f) return px to py
        val t = d / e.r
        val scale = 1f - strength * (1f - t * t)
        return (e.x + dx * scale) to (e.y + dy * scale)
    }

    /** The full inverse map: the pulls, then both eyes. */
    fun warp(px: Float, py: Float, shape: FaceShape, eyes: Float): Pair<Float, Float> {
        var x = px
        var y = py
        for (p in shape.pulls) {
            val (nx, ny) = pull(x, y, p)
            x = nx; y = ny
        }
        val s = eyes.coerceIn(0f, 1f) * FaceShape.MAX_EYES
        if (s > 0f) {
            for (e in shape.eyes) {
                val (nx, ny) = magnify(x, y, e, s)
                x = nx; y = ny
            }
        }
        return x to y
    }

    /**
     * The skin weight the shader uses (0 … 1): inside the face ellipse
     * (soft edge), outside the eyes and the mouth.
     */
    fun skin(px: Float, py: Float, shape: FaceShape): Float {
        val c = cos(-shape.angle)
        val s = sin(-shape.angle)
        val dx = px - shape.cx
        val dy = py - shape.cy
        val u = (dx * c - dy * s) / shape.ax
        val v = (dx * s + dy * c) / shape.ay
        val inFace = 1f - smoothstep(0.8f, 1.0f, sqrt(u * u + v * v))
        var w = inFace
        for (e in shape.eyes) w *= smoothstep(0.9f, 1.4f, hypot(px - e.x, py - e.y) / e.r)
        w *= smoothstep(0.9f, 1.3f, hypot(px - shape.mouth.x, py - shape.mouth.y) / shape.mouth.r)
        return w
    }

    fun smoothstep(e0: Float, e1: Float, x: Float): Float {
        val t = ((x - e0) / (e1 - e0)).coerceIn(0f, 1f)
        return t * t * (3 - 2 * t)
    }

    /** The brighten curve per channel (0 … 1): a lift of the mid-tones, never past white. */
    fun brighten(v: Float, amount: Float): Float {
        val k = amount.coerceIn(0f, 1f) * 0.45f
        val x = v.coerceIn(0f, 1f)
        return (x + k * x * (1f - x) * 1.6f).coerceIn(0f, 1f)
    }

    /** Whether two values differ by more than [eps]. */
    fun differs(a: Float, b: Float, eps: Float = 1e-4f) = abs(a - b) > eps
}

/**
 * D228: the face model, downloaded on first use from Google's public model
 * storage into the app's own files (not bundled in the APK) and checked
 * against a pinned SHA-256 before MediaPipe may read it. A download writes
 * `<name>.part` and renames it only when the checksum matches; a file that
 * does not match is deleted. Plain java.io / java.net: tested on the JVM
 * with `file:` URLs.
 *
 * The request sends nothing but a plain GET for the public file (no key, no
 * account, no picture).
 */
internal class ModelFile(
    private val dir: File,
    val name: String,
    private val url: String,
    private val sha256: String,
    private val maxBytes: Long = 16L * 1024 * 1024,
    private val timeoutMs: Int = 20_000,
) {
    val file: File get() = File(dir, name)

    /** The verified file: already there, or downloaded now (blocking; not the main thread). */
    @Throws(IOException::class)
    fun ensure(): File {
        val target = file
        if (target.isFile && sha256Of(target) == sha256) return target
        if (target.exists()) target.delete()
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException("cannot create ${dir.name}")
        val part = File(dir, "$name.part")
        part.delete()
        try {
            download(part)
            val got = sha256Of(part)
            if (got != sha256) throw IOException("checksum mismatch")
            if (!part.renameTo(target)) throw IOException("cannot install $name")
            return target
        } finally {
            part.delete()
        }
    }

    private fun download(to: File) {
        val connection = URL(url).openConnection()
        connection.connectTimeout = timeoutMs
        connection.readTimeout = timeoutMs
        connection.useCaches = false
        if (connection is HttpURLConnection) {
            connection.instanceFollowRedirects = true
            val code = connection.responseCode
            if (code != 200) {
                connection.disconnect()
                throw IOException("HTTP $code")
            }
        }
        try {
            connection.getInputStream().use { input -> copyBounded(input, to) }
        } finally {
            (connection as? HttpURLConnection)?.disconnect()
        }
    }

    private fun copyBounded(input: InputStream, to: File) {
        var total = 0L
        val buffer = ByteArray(64 * 1024)
        to.outputStream().use { out ->
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                total += n
                if (total > maxBytes) throw IOException("model larger than $maxBytes bytes")
                out.write(buffer, 0, n)
            }
        }
    }

    companion object {
        /**
         * MediaPipe Face Landmarker (float16, version 1; Apache-2.0, see
         * THIRD_PARTY_NOTICES.md): 3 758 596 bytes.
         */
        const val FACE_LANDMARKER_URL =
            "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
        const val FACE_LANDMARKER_SHA256 = "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"
        const val FACE_LANDMARKER_NAME = "face_landmarker.task"

        fun sha256Of(file: File): String {
            val digest = MessageDigest.getInstance("SHA-256")
            FileInputStream(file).use { input ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    digest.update(buffer, 0, n)
                }
            }
            return digest.digest().joinToString("") { "%02x".format(it) }
        }
    }
}

/** D228: the analysis image's size — long side [longSide] px, the frame's aspect kept, even. */
internal object AnalysisSize {
    fun of(width: Int, height: Int, longSide: Int = 256): Pair<Int, Int> {
        if (width <= 0 || height <= 0) return 0 to 0
        val scale = longSide.toDouble() / max(width, height)
        if (scale >= 1.0) return even(width) to even(height)
        return even((width * scale).toInt()) to even((height * scale).toInt())
    }

    private fun even(v: Int) = max(2, v and 1.inv())
}

/**
 * D228: which frames are sent for analysis: only when the analysis thread is
 * idle, and at most every [every]th frame — "every frame or every other
 * frame" depending on how fast the phone is. Capture/GL thread only.
 */
internal class AnalysisPacer(private val every: Int = 2) {
    private var count = 0

    fun shouldAnalyze(analyzerIdle: Boolean): Boolean {
        count++
        if (!analyzerIdle) return false
        if (count < every) return false
        count = 0
        return true
    }
}

/**
 * D228: the free stage's frame path without Android: try the effect within
 * the [budget], pass the raw frame on time-out or failure, report the first
 * output and give up when the [budget] says so. [F] is a `VideoFrame` on the
 * device and a fake in the tests; `render` runs the GPU work and answers an
 * [Outcome] — the frame (owned by the caller), [Outcome.Warming] (drawn for
 * the analysis, but what the effect needs is not there yet: the raw frame
 * goes on, not counted against the budget) or [Outcome.TimedOut] — and
 * throws [GlFailure] for a GL error (the stage turns off for good).
 */
internal class FreeFxFramePath<F : Any>(
    private val machine: FreeFxMachine,
    private val budget: FrameBudget,
    private val clock: () -> Long = System::nanoTime,
) {
    class GlFailure(message: String, cause: Throwable? = null) : Exception(message, cause)

    sealed interface Outcome<out F> {
        data class Drawn<F>(val frame: F) : Outcome<F>
        data object Warming : Outcome<Nothing>
        data object TimedOut : Outcome<Nothing>
    }

    private val avg = RollingAverage()

    /** The last frame's GPU time and the last second's average (ms). */
    @Volatile var lastMs = 0.0
        private set
    val avgMs: Double get() = avg.lastMs

    @Volatile var framesIn = 0L
        private set
    @Volatile var framesOut = 0L
        private set
    @Volatile var raw = 0L
        private set

    fun process(frame: F, render: (F, FreeFxParams) -> Outcome<F>): F? {
        val params = machine.params()
        if (!machine.active || params.none) return null
        framesIn++
        if (!budget.shouldTry()) {
            raw++
            return null
        }
        val start = clock()
        val outcome = try {
            render(frame, params)
        } catch (failure: GlFailure) {
            machine.onGlFailed()
            raw++
            return null
        }
        val elapsed = clock() - start
        if (outcome == Outcome.Warming) {
            raw++
            return null
        }
        lastMs = elapsed / 1e6
        avg.add(elapsed, start + elapsed)
        val drawn = (outcome as? Outcome.Drawn<F>)?.frame
        // Too slow overall: the stage stops (this frame, if drawn, still goes).
        if (budget.record(elapsed, drawn == null) == FrameBudget.Verdict.GIVE_UP) machine.onTooSlow()
        if (drawn == null) {
            raw++
            return null
        }
        framesOut++
        machine.onOutput()
        return drawn
    }
}

/**
 * D228: one GPU job with a deadline, without waiting past it. The job runs on
 * another thread ([post]); the caller waits at most [timeoutNanos]. Whoever
 * comes second loses the race cleanly: a job finishing after the caller gave
 * up hands its result to [discard] (the output texture goes back to the
 * pool) instead of leaking it; a job that finished just as the caller timed
 * out is still taken. A failure inside the job is rethrown to the caller.
 */
internal object TimedJob {
    sealed interface Result<out T> {
        data class Done<T>(val value: T) : Result<T>
        data object Late : Result<Nothing>
        data object NotPosted : Result<Nothing>
    }

    fun <T> run(
        timeoutNanos: Long,
        post: (Runnable) -> Boolean,
        discard: (T) -> Unit,
        work: () -> T,
    ): Result<T> {
        // 0 pending, 1 the job finished first, 2 the caller gave up first.
        val handoff = java.util.concurrent.atomic.AtomicInteger(0)
        val task = java.util.concurrent.FutureTask<T> {
            val value = work()
            if (!handoff.compareAndSet(0, 1)) {
                discard(value)
            }
            value
        }
        if (!post(task)) return Result.NotPosted
        return try {
            Result.Done(task.get(timeoutNanos, java.util.concurrent.TimeUnit.NANOSECONDS))
        } catch (_: java.util.concurrent.TimeoutException) {
            if (handoff.compareAndSet(0, 2)) {
                Result.Late
            } else {
                // Finished between the time-out and now: it is ours.
                try {
                    Result.Done(task.get())
                } catch (error: java.util.concurrent.ExecutionException) {
                    throw error.cause ?: error
                }
            }
        } catch (error: java.util.concurrent.ExecutionException) {
            throw error.cause ?: error
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            if (handoff.compareAndSet(0, 2)) Result.Late else Result.Done(task.get())
        }
    }
}
