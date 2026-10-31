package com.kabso.kabso_live_music

import kotlin.math.exp
import kotlin.math.sqrt

/**
 * D201: the plain-Kotlin rules of the music mix (JVM-tested, no Android types).
 *
 * WebRTC's capture post-processing hands the microphone frame as floats in the
 * 16-bit range (−32768 … 32767), after echo cancelling and noise suppression.
 * Music samples are floats in −1 … 1.
 */
object MixMath {
    const val S16 = 32768f

    /** The voice's RMS level in 0 … 1 of [n] floats in the 16-bit range. */
    fun rms(frame: FloatArray, n: Int): Float {
        if (n <= 0) return 0f
        var sum = 0.0
        for (i in 0 until n) {
            val v = frame[i] / S16
            sum += (v * v).toDouble()
        }
        return sqrt(sum / n).toFloat()
    }

    /**
     * Adds [music] (−1 … 1) to [voice] (16-bit range) for [n] samples with the
     * gain ramping linearly from [fromGain] to [toGain] across the frame (no
     * zipper noise when the level changes); the sum is clipped to the 16-bit
     * range.
     */
    fun mixInto(voice: FloatArray, music: FloatArray, n: Int, fromGain: Float, toGain: Float) {
        if (n <= 0) return
        val step = (toGain - fromGain) / n
        var g = fromGain
        for (i in 0 until n) {
            g += step
            val v = voice[i] + music[i] * g * (S16 - 1f)
            voice[i] = if (v > S16 - 1f) S16 - 1f else if (v < -S16) -S16 else v
        }
    }

    /** Interleaved [channels] floats → mono (their mean), in place into [out]. */
    fun downmix(interleaved: FloatArray, frames: Int, channels: Int, out: FloatArray) {
        if (channels <= 1) {
            System.arraycopy(interleaved, 0, out, 0, frames)
            return
        }
        for (f in 0 until frames) {
            var s = 0f
            for (c in 0 until channels) s += interleaved[f * channels + c]
            out[f] = s / channels
        }
    }
}

/**
 * The music's level while the host speaks: down to [duckTo] of the volume
 * within ~[attackMs] when the voice is above [threshold], back up within
 * ~[releaseMs] after it stops. Off: the volume as set.
 */
class Ducker(
    private val threshold: Float = 0.03f,
    private val duckTo: Float = 0.35f,
    private val attackMs: Float = 60f,
    private val releaseMs: Float = 600f,
) {
    /** The factor applied to the volume now (1 = not ducked). */
    var factor = 1f
        private set

    fun next(voiceRms: Float, enabled: Boolean, frameMs: Float): Float {
        val target = if (enabled && voiceRms > threshold) duckTo else 1f
        val tau = if (target < factor) attackMs else releaseMs
        val a = 1f - exp(-frameMs / tau)
        factor += (target - factor) * a
        return factor
    }

    fun reset() {
        factor = 1f
    }
}

/**
 * Linear-interpolation resampler from [fromRate] to [toRate], mono, keeping
 * its phase across calls (decoded chunks of any size).
 */
class LinearResampler(private val fromRate: Int, private val toRate: Int) {
    private val step = fromRate.toDouble() / toRate
    private var pos = 0.0
    private var last = 0f
    private var primed = false

    /** Resamples [n] input samples; appends to [out] through [emit]. */
    fun process(input: FloatArray, n: Int, emit: (Float) -> Unit) {
        if (n <= 0) return
        if (fromRate == toRate) {
            for (i in 0 until n) emit(input[i])
            return
        }
        // Positions index the sequence y = [last, input[0], …, input[n − 1]]:
        // y[i] = last for i = 0, else input[i − 1].
        if (!primed) {
            last = input[0]
            primed = true
        }
        while (pos < n) {
            val i = pos.toInt()
            val frac = (pos - i).toFloat()
            val a = if (i == 0) last else input[i - 1]
            val b = input[i]
            emit(a + (b - a) * frac)
            pos += step
        }
        last = input[n - 1]
        pos -= n
    }
}

/** Single-producer / single-consumer float ring (the decoder fills, the audio thread reads). */
class FloatRing(capacity: Int) {
    private val buf = FloatArray(capacity)

    @Volatile private var write = 0L

    @Volatile private var read = 0L

    val capacity: Int get() = buf.size
    val available: Int get() = (write - read).toInt()
    val free: Int get() = buf.size - available

    /** Writes one sample; false when full. */
    fun offer(v: Float): Boolean {
        if (free <= 0) return false
        buf[(write % buf.size).toInt()] = v
        write += 1
        return true
    }

    /** Reads up to [n] samples into [out]; the rest of [out] up to [n] is silence. Returns the count read. */
    fun poll(out: FloatArray, n: Int): Int {
        val k = minOf(n, available)
        for (i in 0 until k) out[i] = buf[((read + i) % buf.size).toInt()]
        for (i in k until n) out[i] = 0f
        read += k
        return k
    }

    fun clear() {
        read = write
    }
}
