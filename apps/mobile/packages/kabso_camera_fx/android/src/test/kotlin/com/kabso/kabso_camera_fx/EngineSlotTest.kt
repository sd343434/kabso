package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit

/**
 * D144c: the owner's phone (staging 739fa7c, incl. D144b) showed
 * (A) `in 301 fed 0 out 0 raw 301 … init no #1` → `error (init_timeout)`, and
 * (B) `disabled (black_output) … black 2.0 s probe passthrough_ok` with
 * DeepAR's «Switch effect called but DeepAR rendering is paused!».
 */
class EngineSlotTest {
    private val ms = TimeUnit.MILLISECONDS.toNanos(1)

    // ------------------------------------------- DeepAR's native singleton

    /**
     * DeepAR 5.6.22 as its bytecode and native library behave: one native
     * engine per process (a global "initialized" flag, cleared at the end of
     * the native `shutdown`); `setRenderSurface` on a new instance whose
     * engine state is 0 starts the engine — unless the flag is still set,
     * then it re-posts itself every 150 ms and does nothing else.
     */
    private class NativeDeepAr {
        var initializedFlag = false
        var owner: FakeDeepAr? = null
    }

    private class FakeDeepAr(private val native: NativeDeepAr) {
        var engineState = 0
        var retries = 0

        /** One call (or one 150 ms re-post) of setRenderSurface. */
        fun setRenderSurface() {
            if (engineState != 0) return
            if (native.initializedFlag) {
                retries++ // DeepAR$1, posted to the main looper
                return
            }
            native.initializedFlag = true
            native.owner = this
            engineState = 2 // initializationFinished → initialized()
        }

        fun release() {
            if (native.owner === this) {
                native.initializedFlag = false
                native.owner = null
            }
            engineState = 0
        }
    }

    @Test
    fun `a second DeepAR while the first is not released never initializes (the owner's init no, fed 0)`() {
        val native = NativeDeepAr()
        val first = FakeDeepAr(native)
        first.setRenderSurface()
        assertEquals(2, first.engineState)
        // The go-live closed and opened again; the first was not released.
        val second = FakeDeepAr(native)
        repeat(66) { second.setRenderSurface() } // 10 s of 150 ms re-posts
        assertEquals(0, second.engineState)
        assertEquals(66, second.retries)
    }

    @Test
    fun `D144c - with the engine slot the second waits, then starts once the first is released`() {
        val native = NativeDeepAr()
        val slot = EngineSlot()
        val stageA = Any()
        val stageB = Any()
        assertTrue(slot.tryAcquire(stageA))
        val first = FakeDeepAr(native).also { it.setRenderSurface() }

        // Stage B is picked meanwhile: it does not create a DeepAR yet.
        assertFalse(slot.tryAcquire(stageB))
        assertTrue(slot.busy)

        first.release()
        slot.release(stageA)
        assertTrue(slot.tryAcquire(stageB))
        val second = FakeDeepAr(native).also { it.setRenderSurface() }
        assertEquals(2, second.engineState)
        assertEquals(0, second.retries)
    }

    @Test
    fun `the slot - re-acquire by its owner, release by others ignored`() {
        val slot = EngineSlot()
        val a = Any()
        val b = Any()
        assertTrue(slot.tryAcquire(a))
        assertTrue(slot.tryAcquire(a))
        slot.release(b)
        assertTrue(slot.busy)
        assertFalse(slot.tryAcquire(b))
        slot.release(a)
        assertFalse(slot.busy)
        assertTrue(slot.tryAcquire(b))
    }

    // ------------------------------------------------- nothing black on air

    /** A render every ~33 ms; DeepAR black for [blackFor], then lit. */
    private fun run(
        blackFor: Long,
        totalMs: Long,
        onFrame: (nowNanos: Long, outputLuma: Int) -> Unit,
    ) {
        var t = 0L
        while (t <= totalMs) {
            onFrame(t * ms, if (t < blackFor) 17 else 130)
            t += 33
        }
    }

    @Test
    fun `D145e watch - segmentation still loading for 2,5 s - black on the air, then given up at 2 s`() {
        val watch = BlackOutputWatch()
        var published = 0
        var publishedBlack = 0
        var gaveUpAt = -1L
        var sinceSample = 0
        run(blackFor = 2_500, totalMs = 6_000) { now, out ->
            if (gaveUpAt >= 0) return@run
            if (++sinceSample >= DeepArStage.OUTPUT_SAMPLE_EVERY) {
                sinceSample = 0
                if (watch.onSample(138, out, now) == BlackOutputWatch.Verdict.BLACK) {
                    gaveUpAt = now / ms
                    return@run
                }
            }
            published++
            if (out <= BlackOutputWatch.DARK_LUMA) publishedBlack++
        }
        assertTrue("gave up at $gaveUpAt", gaveUpAt in 2_000..2_500)
        assertTrue(publishedBlack > 50) // viewers saw ~2 s of black
    }

    @Test
    fun `D144c verifier - the same 2,5 s of black - nothing black goes out, the effect from the first lit render`() {
        val verifier = OutputVerifier(sampleEvery = DeepArStage.OUTPUT_SAMPLE_EVERY)
        verifier.arm(0)
        var publishedBlack = 0
        var published = 0
        var gaveUp = false
        run(blackFor = 2_500, totalMs = 6_000) { now, out ->
            val decision = if (verifier.needsSample()) verifier.onSample(138, out, now) else verifier.unsampled()
            when (decision) {
                OutputVerifier.Decision.PUBLISH -> {
                    published++
                    if (out <= BlackOutputWatch.DARK_LUMA) publishedBlack++
                }
                OutputVerifier.Decision.RAW -> Unit
                OutputVerifier.Decision.GIVE_UP -> gaveUp = true
            }
        }
        assertFalse(gaveUp)
        assertEquals(0, publishedBlack)
        assertTrue(published > 90)
        val lit = verifier.litAfterNanos() / ms
        assertTrue("lit after $lit ms", lit in 2_500..2_540)
    }

    @Test
    fun `verifier - black for good - the camera goes out, given up after 8 s, never a black frame`() {
        val verifier = OutputVerifier()
        verifier.arm(0)
        var gaveUpAt = -1L
        var publishedBlack = 0
        run(blackFor = Long.MAX_VALUE, totalMs = 10_000) { now, out ->
            if (gaveUpAt >= 0) return@run
            when (if (verifier.needsSample()) verifier.onSample(138, out, now) else verifier.unsampled()) {
                OutputVerifier.Decision.PUBLISH -> publishedBlack++
                OutputVerifier.Decision.RAW -> Unit
                OutputVerifier.Decision.GIVE_UP -> gaveUpAt = now / ms
            }
        }
        assertEquals(0, publishedBlack)
        assertTrue("gave up at $gaveUpAt", gaveUpAt in 8_000..8_040)
        assertEquals(-1L, verifier.litAfterNanos())
    }

    @Test
    fun `verifier - once lit, every 8th render is checked, a black one goes back to checking each`() {
        val verifier = OutputVerifier(sampleEvery = 8)
        verifier.arm(0)
        assertTrue(verifier.needsSample())
        assertEquals(OutputVerifier.Decision.PUBLISH, verifier.onSample(138, 130, 1))
        val checks = (1..16).count { verifier.needsSample() }
        assertEquals(2, checks)
        // A black sample: raw, and every render is checked again.
        assertEquals(OutputVerifier.Decision.RAW, verifier.onSample(138, 17, 2))
        assertTrue(verifier.needsSample())
        assertEquals(OutputVerifier.Decision.RAW, verifier.unsampled())
    }

    @Test
    fun `verifier - an unreadable sample or a dark camera cannot be judged - published`() {
        val verifier = OutputVerifier()
        verifier.arm(0)
        assertEquals(OutputVerifier.Decision.PUBLISH, verifier.onSample(138, -1, 1))
        verifier.arm(0)
        assertEquals(OutputVerifier.Decision.PUBLISH, verifier.onSample(20, 17, 1))
        assertEquals(-1L, verifier.litAfterNanos())
    }
}
