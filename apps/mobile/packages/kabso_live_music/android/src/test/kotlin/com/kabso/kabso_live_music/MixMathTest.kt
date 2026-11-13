package com.kabso.kabso_live_music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

class MixMathTest {
    @Test
    fun rmsOfFullScaleSineIsAbout0707() {
        val n = 480
        val frame = FloatArray(n) { (sin(2 * PI * 1000 * it / 48000) * 32767).toFloat() }
        assertEquals(0.707f, MixMath.rms(frame, n), 0.01f)
        assertEquals(0f, MixMath.rms(FloatArray(10), 10), 0f)
    }

    @Test
    fun musicIsAddedUnderTheVoiceAndClipped() {
        val voice = floatArrayOf(1000f, -1000f, 32000f, -32000f)
        val music = floatArrayOf(0.5f, 0.5f, 1f, -1f)
        MixMath.mixInto(voice, music, 4, 0.2f, 0.2f)
        assertEquals(1000f + 0.5f * 0.2f * 32767f, voice[0], 0.5f)
        assertEquals(-1000f + 0.5f * 0.2f * 32767f, voice[1], 0.5f)
        assertEquals(32767f, voice[2], 0f) // clipped high
        assertEquals(-32768f, voice[3], 0f) // clipped low
    }

    @Test
    fun theGainRampsAcrossTheFrame() {
        val voice = FloatArray(4)
        val music = FloatArray(4) { 1f }
        MixMath.mixInto(voice, music, 4, 0f, 1f)
        assertTrue(voice[0] < voice[1] && voice[1] < voice[2] && voice[2] < voice[3])
        assertEquals(32767f, voice[3], 1f)
    }

    @Test
    fun duckingLowersTheMusicWhileTheVoiceIsOnThenRestoresIt() {
        val d = Ducker()
        repeat(50) { d.next(0.2f, true, 10f) } // 0.5 s of speech
        assertEquals(0.35f, d.factor, 0.02f)
        repeat(300) { d.next(0f, true, 10f) } // 3 s of silence
        assertEquals(1f, d.factor, 0.02f)
        val off = Ducker()
        repeat(50) { off.next(0.2f, false, 10f) }
        assertEquals(1f, off.factor, 0f)
    }

    @Test
    fun theAttackIsFasterThanTheRelease() {
        val d = Ducker()
        repeat(10) { d.next(0.2f, true, 10f) } // 100 ms of speech
        val down = 1f - d.factor
        val r = Ducker()
        repeat(100) { r.next(0.2f, true, 10f) }
        val start = r.factor
        repeat(10) { r.next(0f, true, 10f) } // 100 ms of silence
        val up = r.factor - start
        assertTrue("attack $down > release $up", down > up)
    }

    @Test
    fun downmixAveragesTheChannels() {
        val out = FloatArray(2)
        MixMath.downmix(floatArrayOf(1f, 0f, 0.5f, 0.5f), 2, 2, out)
        assertEquals(0.5f, out[0], 0f)
        assertEquals(0.5f, out[1], 0f)
    }

    @Test
    fun resamplingKeepsTheLengthAndTheShape() {
        val from = 44100
        val to = 48000
        val r = LinearResampler(from, to)
        val out = mutableListOf<Float>()
        // Ten chunks of 441 samples (0.1 s) of a 440 Hz sine.
        var t = 0
        repeat(10) {
            val chunk = FloatArray(441) { sin(2 * PI * 440 * (t + it) / from).toFloat() }
            t += 441
            r.process(chunk, chunk.size) { out.add(it) }
        }
        assertTrue("length ${out.size}", abs(out.size - 4800) <= 2)
        // Sample k of the output is the sine at time k / 48000 (one sample of delay from the priming).
        var maxErr = 0f
        for (k in 100 until out.size - 100) {
            val expected = sin(2 * PI * 440 * (k - to.toDouble() / from) / to).toFloat()
            maxErr = maxOf(maxErr, abs(out[k] - expected))
        }
        assertTrue("max error $maxErr", maxErr < 0.03f)
    }

    @Test
    fun theSameRatePassesThrough() {
        val r = LinearResampler(48000, 48000)
        val out = mutableListOf<Float>()
        r.process(floatArrayOf(0.1f, 0.2f, 0.3f), 3) { out.add(it) }
        assertEquals(listOf(0.1f, 0.2f, 0.3f), out)
    }

    @Test
    fun theRingReadsWhatWasWrittenAndPadsWithSilence() {
        val ring = FloatRing(4)
        assertTrue(ring.offer(1f) && ring.offer(2f) && ring.offer(3f) && ring.offer(4f))
        assertTrue(!ring.offer(5f))
        val out = FloatArray(6) { 9f }
        assertEquals(4, ring.poll(out, 6))
        assertEquals(listOf(1f, 2f, 3f, 4f, 0f, 0f), out.toList())
        assertTrue(ring.offer(7f))
        assertEquals(1, ring.available)
        ring.clear()
        assertEquals(0, ring.available)
    }
}
