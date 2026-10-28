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
