package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

/**
 * D145e: the owner's device showed DeepAR's background blur as a black
 * picture with only the watermark, while the D144a counters said fresh
 * renders were published (in 159, out 127). Nothing measured the picture
 * itself, so a black output passed every D144a rule. These tests model that
 * path with a fake DeepAR and check the picture's brightness.
 */
class BlackOutputTest {
    private val ms = TimeUnit.MILLISECONDS.toNanos(1)

    /** A packed Y plane (stride [stride]) filled with [value]; padding 0. */
    private fun plane(width: Int, height: Int, stride: Int, value: Int, direct: Boolean = false): ByteBuffer {
        val buffer = if (direct) ByteBuffer.allocateDirect(stride * height) else ByteBuffer.allocate(stride * height)
        for (y in 0 until height) {
            for (x in 0 until stride) buffer.put(y * stride + x, (if (x < width) value else 0).toByte())
        }
        return buffer
    }

    // ------------------------------------------------------------- luma

    @Test
    fun `luma - flat planes, unsigned bytes, stride padding ignored`() {
        assertEquals(16, Luma.meanY(plane(1280, 720, 1280, 16), 1280, 720, 1280))
        assertEquals(200, Luma.meanY(plane(1280, 720, 1280, 200, direct = true), 1280, 720, 1280))
        // Padding bytes (0) past the width are never sampled.
        assertEquals(120, Luma.meanY(plane(36, 64, 64, 120), 36, 64, 64, grid = 16))
    }

    @Test
    fun `luma - half black, half white is about the middle`() {
        val w = 64
        val h = 64
        val buffer = ByteBuffer.allocate(w * h)
        for (y in 0 until h) for (x in 0 until w) buffer.put(y * w + x, (if (y < h / 2) 0 else 255).toByte())
        val mean = Luma.meanY(buffer, w, h, w)
        assertTrue("$mean", mean in 120..135)
    }

    @Test
    fun `luma - an empty or short plane says -1, not black`() {
        assertEquals(-1, Luma.meanY(ByteBuffer.allocate(0), 0, 0, 0))
        assertEquals(-1, Luma.meanY(ByteBuffer.allocate(10), 64, 64, 64))
        assertEquals(-1, Luma.meanY(ByteBuffer.allocate(64 * 64), 64, 64, 32))
    }

    // ------------------------------------------------------------ watch

    @Test
    fun `watch - black output against a lit camera for 2 s is BLACK`() {
        val watch = BlackOutputWatch()
        var verdict = BlackOutputWatch.Verdict.OK
        var firedAt = -1L
        // ~4 samples a second, input 120 (a lit room), output 17 (black).
        for (i in 0..20) {
            val now = (1_000 + i * 250L) * ms
            verdict = watch.onSample(120, 17, now)
            if (verdict == BlackOutputWatch.Verdict.BLACK) {
                firedAt = now - 1_000 * ms
                break
            }
        }
        assertEquals(BlackOutputWatch.Verdict.BLACK, verdict)
        assertEquals(2_000 * ms, firedAt)
    }

    @Test
    fun `watch - a dark room, a picture, or no sample never fire`() {
        val watch = BlackOutputWatch()
        for (i in 0..40) {
            val now = i * 250L * ms
            // Camera covered: input dark as well.
            assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(20, 17, now))
        }
        for (i in 0..40) {
            val now = (20_000 + i * 250L) * ms
            assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(120, 95, now))
            assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(-1, 17, now))
            assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(120, -1, now))
        }
        assertEquals(0L, watch.blackNanos(40_000 * ms))
    }

    @Test
    fun `watch - one picture in between starts the 2 s again`() {
        val watch = BlackOutputWatch()
        watch.onSample(120, 17, 0)
        watch.onSample(120, 17, 1_000 * ms)
        watch.onSample(120, 17, 1_900 * ms)
        watch.onSample(120, 90, 1_950 * ms) // a real picture
        assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(120, 17, 2_100 * ms))
        assertEquals(BlackOutputWatch.Verdict.OK, watch.onSample(120, 17, 3_900 * ms))
        assertEquals(BlackOutputWatch.Verdict.BLACK, watch.onSample(120, 17, 4_100 * ms))
    }

    // ------------------------------------------------------------ probe

    @Test
    fun `probe - DeepAR draws the camera without the effect`() {
        val probe = PassthroughProbe()
        probe.start(1)
        // Still black while the effect is being switched off: ignored.
        probe.onSample(17, 100 * ms)
        for (t in 500..1_500 step 100) probe.onSample(110, t * ms)
        assertTrue(probe.done(1_601 * ms))
        assertEquals(PassthroughProbe.Result.PASSTHROUGH_OK, probe.finish())
        assertTrue(!probe.running)
    }

    @Test
    fun `probe - black without the effect too, or no renders`() {
        val probe = PassthroughProbe()
        probe.start(1)
        for (t in 500..1_500 step 100) probe.onSample(17, t * ms)
        assertEquals(PassthroughProbe.Result.PASSTHROUGH_BLACK, probe.finish())
        probe.start(1)
        assertEquals(PassthroughProbe.Result.NO_SAMPLES, probe.finish())
    }

    // ----------------------------------------------------- the D144a path

    /**
     * The D144a hand-off with a fake DeepAR that renders black (Y = 16) with
     * the effect on — what the owner saw — and the camera without it. D144a's
     * rules (fresh render, feed done, health) publish every one of those
     * black renders: the bug went out to viewers. With the D145e watch on the
     * same path, raw frames go out after ~2 s and the probe names the part.
     */
    @Test
    fun `fake DeepAR rendering black - D144a publishes it, D145e stops it and names it`() {
        val gate = FreshGate<Int> { }
        val health = OutputHealth(maxMisses = 30, warmupNanos = 10_000 * ms)
        val watch = BlackOutputWatch()
        val probe = PassthroughProbe()
        health.arm(0)
        val cameraLuma = 118
        var effectOn = true
        var published = 0
        var publishedBlackD144a = 0
        var rawAfterBlack = 0
        var result: PassthroughProbe.Result? = null
        var sinceSample = 0
        for (frame in 1..150) {
            val now = frame * 33L * ms
            // DeepAR takes the frame and renders it (black while the effect is on).
            gate.feedStarted(frame.toLong())
            gate.feedDone(frame.toLong())
            gate.offer(if (effectOn) 16 else cameraLuma)
            val rendered = gate.take(0)
            if (rendered == null) {
                health.onMiss(now)
                continue
            }
            if (probe.running) {
                probe.onSample(rendered, now)
                rawAfterBlack++
                if (probe.done(now)) {
                    result = probe.finish()
                    break
                }
                continue
            }
            health.onOutput()
            if (rendered <= BlackOutputWatch.DARK_LUMA) publishedBlackD144a++
            if (++sinceSample >= DeepArStage.OUTPUT_SAMPLE_EVERY) {
                sinceSample = 0
                if (watch.onSample(cameraLuma, rendered, now) == BlackOutputWatch.Verdict.BLACK) {
                    probe.start(now)
                    effectOn = false // the stage switches the effect off for the probe
                    continue
                }
            }
            published++
        }
        // D144a's own rules let every black render through (health stayed OK).
        assertEquals(0, health.consecutiveMisses)
        assertTrue(publishedBlackD144a > 0)
        // D145e: at most ~2.3 s of it, then raw frames and a verdict.
        assertTrue("published $published", published * 33 <= 2_400)
        assertTrue(rawAfterBlack > 0)
        assertEquals(PassthroughProbe.Result.PASSTHROUGH_OK, result)
    }
}
