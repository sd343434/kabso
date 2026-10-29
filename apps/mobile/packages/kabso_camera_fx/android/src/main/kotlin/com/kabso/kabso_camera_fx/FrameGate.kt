package com.kabso.kabso_camera_fx

import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import kotlin.math.max
import kotlin.math.roundToInt

// D144a: the plain-Kotlin rules of [DeepArStage] (no Android, no WebRTC), so
// the JVM unit tests in src/test exercise exactly the code the device runs.

/**
 * The hand-off between DeepAR's output (the render helper's thread) and the
 * capture thread, which only ever lets a **fresh** render through.
 *
 * D144's slot handed the capture thread whatever render was waiting. DeepAR
 * in live mode keeps re-drawing its last camera image into the surface, so a
 * render was nearly always waiting — also when DeepAR had stopped taking new
 * camera frames — and the stage published the same picture again and again:
 * the frozen still (watermark and all) the owner saw.
 *
 * Here every frame fed to DeepAR gets a sequence number: [feedStarted] on
 * DeepAR's thread right before `receiveFrame`, [feedDone] once it returned
 * (DeepAR has the image). A render is tagged with the newest feed started
 * when it arrived; the capture thread takes a render only if its tag is newer
 * than that of the last render it published **and** that feed is done.
 * Re-draws of an image already published are released at once (which also
 * gives the helper's single texture back, so the next render can come). If
 * DeepAR stops taking input — its thread stuck in or before `receiveFrame` —
 * no feed completes, no render qualifies, [take] times out and the raw camera
 * frame passes: the picture never freezes, and the re-draws made while it
 * hangs are never published.
 *
 * Exactly one render is held at a time; whoever holds it releases it.
 */
internal class FreshGate<T : Any>(private val release: (T) -> Unit) {
    private val lock = ReentrantLock()
    private val filled = lock.newCondition()

    // Guarded by [lock].
    private var pending: T? = null
    private var pendingTag = 0L
    private var startedSeq = 0L
    private var doneSeq = 0L
    private var publishedTag = 0L

    private var droppedStale = 0L
    private var delivered = 0L

    /** DeepAR's thread: it is about to take feed [seq] (increasing). */
    fun feedStarted(seq: Long) {
        lock.withLock { if (seq > startedSeq) startedSeq = seq }
    }

    /** DeepAR's thread: `receiveFrame` for feed [seq] returned. */
    fun feedDone(seq: Long) {
        lock.withLock {
            if (seq > doneSeq) doneSeq = seq
            filled.signalAll()
        }
    }

    /**
     * The render helper's thread: DeepAR rendered [frame] (already retained:
     * the gate owns it now). False when it was a re-draw of an image already
     * published (released at once).
     */
    fun offer(frame: T): Boolean {
        var drop: T? = null
        val fresh = lock.withLock {
            delivered++
            val tag = startedSeq
            if (tag <= publishedTag) {
                droppedStale++
                drop = frame
                false
            } else {
                // A newer one replaces an older one nobody took.
                drop = pending
                pending = frame
                pendingTag = tag
                filled.signalAll()
                true
            }
        }
        drop?.let(release)
        return fresh
    }

    /**
     * The capture thread: a render newer than the last one published, within
     * [timeoutNanos]; null: none (pass the raw frame). The caller owns it.
     */
    fun take(timeoutNanos: Long): T? = lock.withLock {
        var remaining = timeoutNanos
        try {
            while (!ready() && remaining > 0) remaining = filled.awaitNanos(remaining)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        if (!ready()) return@withLock null
        val taken = pending ?: return@withLock null
        pending = null
        publishedTag = pendingTag
        taken
    }

    // Under [lock]: a render newer than the last published, its feed done.
    private fun ready() = pending != null && pendingTag <= doneSeq

    /** Releases a render nobody took (effect off, surface gone). */
    fun clear() {
        val stale = lock.withLock {
            val previous = pending
            pending = null
            previous
        }
        stale?.let(release)
    }

    /** Renders that arrived, and those dropped as already published. */
    fun counts(): Pair<Long, Long> = lock.withLock { delivered to droppedStale }
}

/**
 * When to give up on DeepAR and switch the effect off (the raw camera goes on,
 * and Dart is told why).
 *
 * - Before the first fresh render: [warmupNanos] (initialization, shaders and
 *   the segmentation model take a moment; raw frames pass meanwhile).
 * - After it: [maxMisses] frames in a row without a fresh render.
 */
internal class OutputHealth(private val maxMisses: Int, private val warmupNanos: Long) {
    enum class Verdict { OK, GIVE_UP }

    private var armedAt = 0L
    private var sawOutput = false
    private var misses = 0

    /** Consecutive frames without a fresh render. */
    val consecutiveMisses: Int get() = misses

    /** An effect (re)started at [nowNanos]: the warm-up begins again. */
    fun arm(nowNanos: Long) {
        armedAt = nowNanos
        sawOutput = false
        misses = 0
    }

    fun onOutput() {
        sawOutput = true
        misses = 0
    }

    fun onMiss(nowNanos: Long): Verdict {
        misses++
        if (!sawOutput) {
            return if (nowNanos - armedAt >= warmupNanos) Verdict.GIVE_UP else Verdict.OK
        }
        return if (misses >= maxMisses) Verdict.GIVE_UP else Verdict.OK
    }

    /** Still warming up (no fresh render yet) at [nowNanos]. */
    fun warmingUp(nowNanos: Long) = !sawOutput && nowNanos - armedAt < warmupNanos
}

/**
 * DeepAR's input geometry, latched for the life of one DeepAR instance.
 *
 * DeepAR keys its pipeline to the geometry of the first frame it receives
 * (its own Flutter plugin froze for good when the rotation argument changed
 * on a live instance). WebRTC, though, scales the camera frames down and up
 * as CPU and bandwidth change, and D144 fed every new size straight in — and
 * rebuilt the render surface under DeepAR's feet each time. Now the size is
 * fixed at the first frame (long side at most [maxLongSide]); other sizes are
 * cropped and scaled to it on the GPU before the readback, and the output is
 * scaled back to what WebRTC asked for. A rotation change (the other camera)
 * needs a new instance.
 */
internal data class InputGeometry(val width: Int, val height: Int, val rotation: Int) {
    private val quarterTurn get() = rotation == 90 || rotation == 270

    /** The upright size DeepAR renders (its output surface). */
    val outWidth get() = if (quarterTurn) height else width
    val outHeight get() = if (quarterTurn) width else height

    /** A centre crop of a [srcWidth] × [srcHeight] frame to this aspect. */
    data class Crop(val x: Int, val y: Int, val width: Int, val height: Int)

    fun cropFor(srcWidth: Int, srcHeight: Int): Crop = centreCrop(srcWidth, srcHeight, width, height)

    companion object {
        fun latch(width: Int, height: Int, rotation: Int, maxLongSide: Int): InputGeometry {
            val long = max(width, height)
            if (long <= maxLongSide) return InputGeometry(even(width), even(height), rotation)
            val scale = maxLongSide.toDouble() / long
            return InputGeometry(
                even((width * scale).roundToInt()),
                even((height * scale).roundToInt()),
                rotation,
            )
        }

        /** The largest centred [targetW]:[targetH] rectangle inside [srcW] × [srcH]. */
        fun centreCrop(srcW: Int, srcH: Int, targetW: Int, targetH: Int): Crop {
            // Compare srcW/srcH with targetW/targetH without rounding.
            val srcWider = srcW.toLong() * targetH > targetW.toLong() * srcH
            return if (srcWider) {
                val w = (srcH.toLong() * targetW / targetH).toInt()
                Crop((srcW - w) / 2, 0, w, srcH)
            } else {
                val h = (srcW.toLong() * targetH / targetW).toInt()
                Crop(0, (srcH - h) / 2, srcW, h)
            }
        }

        private fun even(value: Int) = max(2, value and 1.inv())
    }
}

/** Once-a-second averages for the diagnostics overlay (capture thread). */
internal class RollingAverage(private val windowNanos: Long = 1_000_000_000L) {
    private var windowStart = 0L
    private var sum = 0L
    private var count = 0

    /** The last full window's average in ms (0 before one completed). */
    @Volatile var lastMs = 0.0
        private set

    fun add(valueNanos: Long, nowNanos: Long) {
        if (windowStart == 0L) windowStart = nowNanos
        sum += valueNanos
        count++
        if (nowNanos - windowStart >= windowNanos) {
            lastMs = sum / 1e6 / count
            windowStart = nowNanos
            sum = 0
            count = 0
        }
    }
}

// ---------------------------------------------------------------- D145e

/**
 * D145e: the mean brightness (luma, 0–255) of a Y plane, from a sparse grid
 * of [grid] × [grid] samples — cheap enough for every frame fed to DeepAR.
 *
 * The owner's device showed background blur as a black picture with DeepAR's
 * watermark while the counters said fresh renders were published; nothing on
 * the overlay could say whether DeepAR's *input* was black or its *output*.
 * The stage now measures both (the NV21 it hands to `receiveFrame`, and a
 * small read-back of the render it publishes).
 *
 * Absolute indices from 0, so any [ByteBuffer] (direct or heap, a slice or
 * not) works; -1 when the plane is empty or too small for [stride].
 */
internal object Luma {
    fun meanY(plane: java.nio.ByteBuffer, width: Int, height: Int, stride: Int, grid: Int = 32): Int {
        if (width <= 0 || height <= 0 || stride < width) return -1
        if (plane.capacity() < stride.toLong() * (height - 1) + width) return -1
        val cols = minOf(grid, width)
        val rows = minOf(grid, height)
        var sum = 0L
        for (r in 0 until rows) {
            // Centres of the grid cells, never the very edge.
            val y = ((2L * r + 1) * height / (2L * rows)).toInt()
            val base = y * stride
            for (c in 0 until cols) {
                val x = ((2L * c + 1) * width / (2L * cols)).toInt()
                sum += plane.get(base + x).toInt() and 0xFF
            }
        }
        return (sum / (rows * cols)).toInt()
    }
}

/**
 * D145e: a black picture never goes to the viewers.
 *
 * Fed with the luma of what went **into** DeepAR and of what came **out**
 * (sampled a few times a second). Output at or below [darkLuma] while the
 * input is at least [litLuma] — the camera sees something, DeepAR shows
 * nothing — for [windowNanos] (at least [minSamples] samples) → [Verdict.BLACK]:
 * the stage stops publishing DeepAR's output. A dark room (input dark too)
 * is not DeepAR's fault and never counts.
 */
internal class BlackOutputWatch(
    private val darkLuma: Int = DARK_LUMA,
    private val litLuma: Int = LIT_LUMA,
    private val windowNanos: Long = 2_000_000_000L,
    private val minSamples: Int = 3,
) {
    enum class Verdict { OK, BLACK }

    private var since = 0L
    private var samples = 0

    /** How long the output has been black against a lit input (0: not). */
    fun blackNanos(nowNanos: Long): Long = if (since == 0L) 0L else nowNanos - since

    fun reset() {
        since = 0L
        samples = 0
    }

    fun onSample(inputLuma: Int, outputLuma: Int, nowNanos: Long): Verdict {
        if (inputLuma < 0 || outputLuma < 0) return Verdict.OK
        if (outputLuma > darkLuma || inputLuma < litLuma) {
            reset()
            return Verdict.OK
        }
        if (since == 0L) since = nowNanos
        samples++
        return if (samples >= minSamples && nowNanos - since >= windowNanos) Verdict.BLACK else Verdict.OK
    }

    companion object {
        /** Video Y is 16 for black; a little noise and the watermark on top. */
        const val DARK_LUMA = 28

        /** A camera picture someone could see something in. */
        const val LIT_LUMA = 48
    }
}

/**
 * D145e: once [BlackOutputWatch] fired, DeepAR runs a moment longer **without
 * the effect** (its own pipeline only; raw frames are published meanwhile) to
 * tell which part is black: [Result.PASSTHROUGH_OK] — DeepAR draws the camera,
 * the effect's own render is black; [Result.PASSTHROUGH_BLACK] — DeepAR draws
 * nothing of the camera at all; [Result.NO_SAMPLES] — no render arrived.
 * Samples in the first [settleNanos] are ignored (the effect is still being
 * switched off).
 */
internal class PassthroughProbe(
    private val settleNanos: Long = 400_000_000L,
    private val durationNanos: Long = 1_600_000_000L,
    private val darkLuma: Int = BlackOutputWatch.DARK_LUMA,
) {
    enum class Result(val code: String) {
        PASSTHROUGH_OK("passthrough_ok"),
        PASSTHROUGH_BLACK("passthrough_black"),
        NO_SAMPLES("no_samples"),
    }

    private var startedAt = 0L
    private var counted = 0
    private var lit = 0

    val running: Boolean get() = startedAt != 0L

    fun start(nowNanos: Long) {
        startedAt = nowNanos
        counted = 0
        lit = 0
    }

    fun onSample(outputLuma: Int, nowNanos: Long) {
        if (!running || outputLuma < 0 || nowNanos - startedAt < settleNanos) return
        counted++
        if (outputLuma > darkLuma) lit++
    }

    fun done(nowNanos: Long) = running && nowNanos - startedAt >= durationNanos

    /** The verdict; the probe stops. */
    fun finish(): Result {
        startedAt = 0L
        return when {
            counted == 0 -> Result.NO_SAMPLES
            // Most of DeepAR's own renders show the camera.
            lit * 2 > counted -> Result.PASSTHROUGH_OK
            else -> Result.PASSTHROUGH_BLACK
        }
    }
}

/**
 * D144b: the start-up safety net, armed when an effect is **picked** — not on
 * the first camera frame.
 *
 * D144a armed [OutputHealth] inside the per-frame path, so its 10 s warm-up
 * only ran while camera frames reached the stage. The owner's device showed
 * the stage with no frames at all (`in 0 … init no`): nothing armed it,
 * nothing asked it, and Magic said «جارٍ تشغيل المؤثر…» for ever. This watch
 * is checked by a timer, so it decides with or without frames:
 * - [Verdict.NO_FRAMES]: no camera frame reached the stage since the pick
 *   (the processor is not on the camera's frame path);
 * - [Verdict.INIT_TIMEOUT]: frames came, DeepAR never said `initialized()`;
 * - [Verdict.NO_OUTPUT]: DeepAR started but published no fresh render.
 * Thread-safe (picked on the main thread, frames on the capture thread, the
 * check on a timer).
 */
internal class StartWatch(private val timeoutNanos: Long) {
    enum class Verdict { WAITING, OK, NO_FRAMES, INIT_TIMEOUT, NO_OUTPUT }

    private var armed = false
    private var armedAt = 0L
    private var framesAtArm = 0L
    private var sawOutput = false
    private var token = 0

    /** An effect was picked at [nowNanos]; [framesSoFar] is the stage's frame count. Returns the arm's token. */
    @Synchronized
    fun arm(nowNanos: Long, framesSoFar: Long): Int {
        armed = true
        armedAt = nowNanos
        framesAtArm = framesSoFar
        sawOutput = false
        return ++token
    }

    /** No effect any more (None, or the effect gave up for another reason). */
    @Synchronized
    fun disarm() {
        armed = false
    }

    /** A fresh render was published: the start succeeded. */
    @Synchronized
    fun onOutput() {
        sawOutput = true
    }

    /** Whether [token] is still the current, armed pick. */
    @Synchronized
    fun isCurrent(token: Int) = armed && token == this.token

    @Synchronized
    fun check(nowNanos: Long, framesNow: Long, initialized: Boolean): Verdict {
        if (!armed || sawOutput) return Verdict.OK
        if (nowNanos - armedAt < timeoutNanos) return Verdict.WAITING
        return when {
            framesNow == framesAtArm -> Verdict.NO_FRAMES
            !initialized -> Verdict.INIT_TIMEOUT
            else -> Verdict.NO_OUTPUT
        }
    }
}

/**
 * D144b: flutter_webrtc 1.6.2+hotfix.4 calls only **one** `LocalVideoTrack`
 * wrapper per camera: the one installed as its `VideoSource`'s
 * `VideoProcessor` (`GetUserMediaImpl.getUserVideo`, l.874–875). When the
 * same camera is asked for again while it is open, it hands out a *shared*
 * track (`buildSharedVideoTrack`, l.765–780 and 906–924) whose wrapper is
 * registered for `getLocalTrack` but never called; a processor added to it
 * sees no frame, while the picture (the source's sink feeds every track of
 * the source) looks normal. That is the owner's `in 0 … on track`.
 *
 * [bind] makes the wrapper we attach to the source's processor. [P] is the
 * processor type (a `VideoProcessor` on the device, a fake in the tests).
 */
internal object FramePath {
    enum class Result(val code: String) {
        /** The wrapper already was the source's processor. */
        ON_PATH("source"),

        /** It was not (a shared track): it is now. */
        REBOUND("rebound"),

        /** The source could not be found; left as it was. */
        UNKNOWN("unknown"),
    }

    fun <P : Any> bind(current: P?, wanted: P, install: (P) -> Unit): Result {
        if (current === wanted) return Result.ON_PATH
        install(wanted)
        return Result.REBOUND
    }
}

/**
 * D144b: the processor's two stages in order — DeepAR first, then the colour
 * transform (D143 filter with D157's fill light folded in) on DeepAR's
 * output — each a pass-through (`null`) when it has nothing to do. Both run
 * when both are on. A frame a stage made is ours: the intermediate one goes
 * back as soon as the colour stage has drawn it. Returns the frame for the
 * track and whether it is ours (release it on the next call).
 */
internal object FxChain {
    fun <F : Any> run(
        frame: F,
        effect: (F) -> F?,
        color: (F) -> F?,
        release: (F) -> Unit,
    ): Pair<F, Boolean> {
        val effected = effect(frame)
        val colored = color(effected ?: frame)
        if (colored != null) {
            effected?.let(release)
            return colored to true
        }
        if (effected != null) return effected to true
        return frame to false
    }
}

/**
 * D144c: DeepAR's native engine is one per process (`DeepAR::getInstance`,
 * one global "initialized" flag cleared only at the end of the native
 * `shutdown`). A new `DeepAR` whose `setRenderSurface` sees that flag still
 * set never initializes: it re-posts `setRenderSurface` to the main looper
 * every 150 ms (`DeepAR.setRenderSurface` bytecode, `DeepAR$1`) — the owner's
 * `init no … fed 0` and `error (init_timeout)`. So a stage starts a DeepAR
 * only once the previous one in the process has been released: this slot.
 */
internal class EngineSlot {
    private var owner: Any? = null

    /** True if [who] holds the slot now (it was free, or already [who]'s). */
    @Synchronized
    fun tryAcquire(who: Any): Boolean {
        if (owner != null && owner !== who) return false
        owner = who
        return true
    }

    /** [who]'s DeepAR was released (`release()` returned). */
    @Synchronized
    fun release(who: Any) {
        if (owner === who) owner = null
    }

    val busy: Boolean @Synchronized get() = owner != null
}

/**
 * D144c: what may go out while an effect starts or misbehaves. D145e
 * published every fresh render and gave up after 2 s of black output; the
 * owner's background blur was given up on after exactly 2.0 s (`black 2.0 s`,
 * and DeepAR without the effect drew the camera: `probe passthrough_ok`) —
 * plausibly DeepAR's segmentation still loading (`initializeSegmentationAsync`
 * in the native library), with the black frames meanwhile on the air.
 *
 * Now a render is only published once one has been **seen lit** (sampled
 * every render until then, then every [sampleEvery]th); a black render
 * (input lit, output dark) sends the raw camera instead and switches back to
 * checking every render; only [giveUpNanos] of black in a row gives up. A
 * read-back that fails (-1) or a dark camera cannot be judged: published.
 */
internal class OutputVerifier(
    private val giveUpNanos: Long = 8_000_000_000L,
    private val sampleEvery: Int = 8,
    private val darkLuma: Int = BlackOutputWatch.DARK_LUMA,
    private val litLuma: Int = BlackOutputWatch.LIT_LUMA,
) {
    enum class Decision { PUBLISH, RAW, GIVE_UP }

    private var armedAt = 0L
    private var verified = false
    private var blackSince = NONE
    private var count = 0
    private var firstLitAt = NONE

    /** The effect was (re)picked at [nowNanos]. */
    fun arm(nowNanos: Long) {
        armedAt = nowNanos
        verified = false
        blackSince = NONE
        count = 0
        firstLitAt = NONE
    }

    /** Whether this render must be read back before it may go out. */
    fun needsSample(): Boolean = !verified || ++count % sampleEvery == 0

    /** A render that is not sampled: out only once the output was seen lit. */
    fun unsampled(): Decision = if (verified) Decision.PUBLISH else Decision.RAW

    fun onSample(inputLuma: Int, outputLuma: Int, nowNanos: Long): Decision {
        val black = inputLuma >= litLuma && outputLuma in 0..darkLuma
        if (!black) {
            if (!verified && outputLuma > darkLuma && firstLitAt == NONE) firstLitAt = nowNanos
            verified = true
            blackSince = NONE
            return Decision.PUBLISH
        }
        verified = false
        count = 0
        if (blackSince == NONE) blackSince = nowNanos
        return if (nowNanos - blackSince >= giveUpNanos) Decision.GIVE_UP else Decision.RAW
    }

    /** How long the output has been black against a lit camera (0: not). */
    fun blackNanos(nowNanos: Long): Long = if (blackSince == NONE) 0L else nowNanos - blackSince

    /** From the pick to the first lit render (-1: none yet). */
    fun litAfterNanos(): Long = if (firstLitAt == NONE) -1L else firstLitAt - armedAt

    private companion object {
        const val NONE = Long.MIN_VALUE
    }
}
