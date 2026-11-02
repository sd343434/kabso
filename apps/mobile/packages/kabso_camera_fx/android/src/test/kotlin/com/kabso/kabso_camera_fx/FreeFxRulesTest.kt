package com.kabso.kabso_camera_fx

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * D228: the free engine's rules (FreeFxRules.kt) — the stage's state
 * machine, the slow-frame fallback, GL failure turning the stage off, the
 * mask and landmark smoothing, the face geometry and the warp maths, and the
 * face model's download check. FreeFxStage.kt runs exactly these on the
 * device; its GL and the SDKs themselves need a phone.
 */
class FreeFxRulesTest {
    @get:Rule val temp = TemporaryFolder()

    private val ms = 1_000_000L
    private val blur = FreeFxParams(blur = true)
    private val beauty = FreeFxParams(smooth = 0.4f, brighten = 0.4f, slim = 0.4f, eyes = 0.4f)

    // ------------------------------------------------------------ the state machine

    private class Recorder {
        val events = ArrayList<Pair<String, String?>>()
        fun on(state: String, reason: String?) { events += state to reason }
    }

    @Test
    fun `a pick starts, the first output makes it ready, None turns it off`() {
        val r = Recorder()
        val m = FreeFxMachine(r::on)
        assertEquals(FreeFxMachine.STATE_OFF, m.state)
        assertFalse(m.active)

        assertTrue("a first pick starts the stage", m.pick(blur))
        assertEquals(FreeFxMachine.STATE_INITIALIZING, m.state)
        assertTrue(m.active)
        m.onOutput()
        assertEquals(FreeFxMachine.STATE_READY, m.state)
        assertNull(m.reason)

        // Strength changes while running restart nothing.
        assertFalse(m.pick(blur.copy(smooth = 0.5f)))
        assertEquals(FreeFxMachine.STATE_READY, m.state)

        assertFalse(m.pick(FreeFxParams.NONE))
        assertEquals(FreeFxMachine.STATE_OFF, m.state)
        assertFalse(m.active)
        assertEquals(
            listOf(
                FreeFxMachine.STATE_INITIALIZING to null,
                FreeFxMachine.STATE_READY to null,
                FreeFxMachine.STATE_OFF to null,
            ),
            r.events,
        )
    }

    @Test
    fun `a failure stays visible after None and a new pick starts again`() {
        val m = FreeFxMachine()
        m.pick(blur)
        m.onInitFailed()
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals(FreeFxMachine.REASON_INIT, m.reason)
        assertFalse(m.active)

        m.pick(FreeFxParams.NONE)
        assertEquals("Magic still says why", FreeFxMachine.STATE_ERROR, m.state)

        assertTrue(m.pick(blur))
        assertEquals(FreeFxMachine.STATE_INITIALIZING, m.state)
    }

    @Test
    fun `a GL failure turns the stage off for good`() {
        val m = FreeFxMachine()
        m.pick(beauty)
        m.onOutput()
        m.onGlFailed()
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals(FreeFxMachine.REASON_GL, m.reason)
        assertTrue(m.glBroken)
        assertFalse(m.active)
        // A new pick does not retry on this processor.
        assertFalse(m.pick(blur))
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals(FreeFxMachine.REASON_GL, m.reason)
        assertFalse(m.active)
    }

    @Test
    fun `no face model with blur keeps blur and says beauty is unavailable`() {
        val m = FreeFxMachine()
        m.pick(blur.copy(smooth = 0.4f))
        m.onFaceModelFailed()
        assertEquals("still starting: the blur's mask decides", FreeFxMachine.STATE_INITIALIZING, m.state)
        m.onOutput()
        assertEquals(FreeFxMachine.STATE_READY, m.state)
        assertEquals(FreeFxMachine.REASON_BEAUTY_UNAVAILABLE, m.reason)
        // Beauty sliders back to 0: nothing unavailable any more.
        m.pick(blur)
        assertNull(m.reason)
        // Beauty again: unavailable again (no new download per slider move).
        m.pick(blur.copy(eyes = 0.3f))
        assertEquals(FreeFxMachine.REASON_BEAUTY_UNAVAILABLE, m.reason)
        // The model arrives later (a retry).
        m.onFaceModelReady()
        assertNull(m.reason)
    }

    @Test
    fun `no face model with beauty alone is an error`() {
        val m = FreeFxMachine()
        m.pick(beauty)
        m.onFaceModelFailed()
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals(FreeFxMachine.REASON_MODEL, m.reason)
        assertFalse(m.active)
    }

    @Test
    fun `the start watch's verdict applies only to the current pick`() {
        val m = FreeFxMachine()
        m.pick(blur)
        val first = m.token()
        m.pick(FreeFxParams.NONE)
        m.pick(blur)
        m.onStartVerdict(first, StartWatch.Verdict.NO_FRAMES)
        assertEquals("a stale timer is ignored", FreeFxMachine.STATE_INITIALIZING, m.state)
        m.onStartVerdict(m.token(), StartWatch.Verdict.INIT_TIMEOUT)
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals("init_timeout", m.reason)

        m.pick(blur)
        m.onOutput()
        m.onStartVerdict(m.token(), StartWatch.Verdict.NO_OUTPUT)
        assertEquals("ready is never undone by the timer", FreeFxMachine.STATE_READY, m.state)
    }

    @Test
    fun `a status listener that throws never breaks the stage`() {
        val m = FreeFxMachine { _, _ -> throw IllegalStateException("channel gone") }
        m.pick(blur)
        m.onOutput()
        assertEquals(FreeFxMachine.STATE_READY, m.state)
    }

    // ------------------------------------------------------------ the frame budget

    @Test
    fun `frames under the budget are fine, three slow ones in a row back off`() {
        val b = FrameBudget(budgetNanos = 40 * ms, slowInARow = 3, backoffFrames = 30, maxBackoffs = 3)
        repeat(100) {
            assertTrue(b.shouldTry())
            assertEquals(FrameBudget.Verdict.OK, b.record(12 * ms, timedOut = false))
        }
        assertEquals(FrameBudget.Verdict.OK, b.record(45 * ms, false))
        assertEquals(FrameBudget.Verdict.OK, b.record(10 * ms, false))
        assertEquals(FrameBudget.Verdict.OK, b.record(45 * ms, false))
        assertEquals(FrameBudget.Verdict.OK, b.record(0, timedOut = true))
        assertEquals(FrameBudget.Verdict.BACKOFF, b.record(41 * ms, false))
        var skipped = 0
        while (!b.shouldTry()) skipped++
        assertEquals("the next 30 frames pass raw without trying", 30, skipped)
        assertEquals(30L, b.skippedTotal)
        assertEquals(4L, b.slowTotal)
    }

    @Test
    fun `backing off three times without recovering gives up`() {
        val b = FrameBudget(budgetNanos = 40 * ms, slowInARow = 3, backoffFrames = 5, maxBackoffs = 3, recoverFrames = 90)
        var verdict = FrameBudget.Verdict.OK
        var tried = 0
        while (verdict != FrameBudget.Verdict.GIVE_UP && tried < 1000) {
            if (!b.shouldTry()) continue
            tried++
            verdict = b.record(60 * ms, false)
        }
        assertEquals(FrameBudget.Verdict.GIVE_UP, verdict)
        assertEquals("3 backoffs of 3 slow frames", 9, tried)
    }

    @Test
    fun `enough good frames between slow spells forgive the earlier backoffs`() {
        val b = FrameBudget(budgetNanos = 40 * ms, slowInARow = 3, backoffFrames = 0, maxBackoffs = 3, recoverFrames = 90)
        repeat(10) {
            repeat(3) { assertTrue(b.record(60 * ms, false) != FrameBudget.Verdict.GIVE_UP) }
            repeat(90) { b.record(10 * ms, false) }
        }
        assertEquals(0, b.backoffCount)
    }

    // ---------------------------------------------- the frame path (fallback, GL off)

    private class Frame(val id: Int)

    private class FakeClock {
        var now = 1_000_000_000L
        fun read() = now
    }

    @Test
    fun `a slow frame passes raw, slow frames back off and finally switch the effect off`() {
        val clock = FakeClock()
        val m = FreeFxMachine()
        val path = FreeFxFramePath<Frame>(m, FrameBudget(40 * ms, 3, 30, 3), clock::read)
        m.pick(blur)
        var renders = 0
        val slowRender: (Frame, FreeFxParams) -> FreeFxFramePath.Outcome<Frame> = { f, _ ->
            renders++
            clock.now += 41 * ms
            FreeFxFramePath.Outcome.TimedOut
        }
        // The first slow frame: raw (null), the stage keeps trying.
        assertNull(path.process(Frame(1), slowRender))
        assertEquals(FreeFxMachine.STATE_INITIALIZING, m.state)
        var frames = 1
        while (m.active && frames < 1000) {
            assertNull("never an effect frame while slow", path.process(Frame(frames), slowRender))
            frames++
        }
        assertEquals(FreeFxMachine.STATE_DISABLED, m.state)
        assertEquals(FreeFxMachine.REASON_SLOW, m.reason)
        assertEquals("3 backoffs × 3 slow frames tried", 9, renders)
        assertEquals(frames.toLong(), path.raw)
        // Off: frames pass untouched, nothing is tried.
        assertNull(path.process(Frame(9999), slowRender))
        assertEquals(9, renders)
    }

    @Test
    fun `a GL failure turns the stage off and later frames are not touched`() {
        val m = FreeFxMachine()
        val path = FreeFxFramePath<Frame>(m, FrameBudget())
        m.pick(beauty)
        var calls = 0
        val ok = Frame(1)
        assertSame(ok, path.process(ok) { f, _ -> calls++; FreeFxFramePath.Outcome.Drawn(f) })
        assertEquals(FreeFxMachine.STATE_READY, m.state)
        assertNull(path.process(Frame(2)) { _, _ -> calls++; throw FreeFxFramePath.GlFailure("glDrawArrays: 0x505") })
        assertEquals(FreeFxMachine.STATE_ERROR, m.state)
        assertEquals(FreeFxMachine.REASON_GL, m.reason)
        repeat(10) { i -> assertNull(path.process(Frame(3 + i)) { f, _ -> calls++; FreeFxFramePath.Outcome.Drawn(f) }) }
        assertEquals("nothing tried after the failure", 2, calls)
    }

    @Test
    fun `warming frames pass raw without counting against the budget`() {
        val clock = FakeClock()
        val m = FreeFxMachine()
        val path = FreeFxFramePath<Frame>(m, FrameBudget(40 * ms, 3, 30, 3), clock::read)
        m.pick(blur)
        repeat(500) { i ->
            assertNull(path.process(Frame(i)) { _, _ -> clock.now += 80 * ms; FreeFxFramePath.Outcome.Warming })
        }
        assertEquals("still starting, not too_slow", FreeFxMachine.STATE_INITIALIZING, m.state)
        val first = Frame(501)
        assertSame(first, path.process(first) { f, _ -> clock.now += 9 * ms; FreeFxFramePath.Outcome.Drawn(f) })
        assertEquals(FreeFxMachine.STATE_READY, m.state)
        assertEquals(1L, path.framesOut)
        assertEquals(9.0, path.lastMs, 1e-9)
    }

    @Test
    fun `with nothing picked the path does nothing at all`() {
        val m = FreeFxMachine()
        val path = FreeFxFramePath<Frame>(m, FrameBudget())
        assertNull(path.process(Frame(1)) { _, _ -> fail("rendered with nothing picked"); FreeFxFramePath.Outcome.TimedOut })
        assertEquals(0L, path.framesIn)
    }

    // ------------------------------------------------------------- the timed GPU job

    @Test
    fun `a GPU job past the deadline goes raw and its late output is given back`() {
        val gl = Executors.newSingleThreadExecutor()
        try {
            val discarded = CountDownLatch(1)
            val released = AtomicInteger()
            val start = System.nanoTime()
            val result = TimedJob.run(
                TimeUnit.MILLISECONDS.toNanos(40),
                post = { gl.execute(it); true },
                discard = { _: String -> released.incrementAndGet(); discarded.countDown() },
            ) {
                Thread.sleep(120)
                "texture"
            }
            val waited = (System.nanoTime() - start) / 1_000_000
            assertEquals(TimedJob.Result.Late, result)
            assertTrue("the capture thread waited ${waited} ms, not the job's 120", waited < 110)
            assertTrue(discarded.await(2, TimeUnit.SECONDS))
            assertEquals(1, released.get())
        } finally {
            gl.shutdownNow()
        }
    }

    @Test
    fun `a GPU job within the deadline is taken, a failing one is rethrown, a refused post is reported`() {
        val gl = Executors.newSingleThreadExecutor()
        try {
            val done = TimedJob.run(TimeUnit.MILLISECONDS.toNanos(200), { gl.execute(it); true }, { _: String -> fail("discarded") }) { "frame" }
            assertEquals(TimedJob.Result.Done("frame"), done)
            try {
                TimedJob.run(TimeUnit.MILLISECONDS.toNanos(200), { gl.execute(it); true }, { _: String -> }) {
                    throw FreeFxFramePath.GlFailure("GL_OUT_OF_MEMORY")
                }
                fail("expected the GL failure")
            } catch (expected: FreeFxFramePath.GlFailure) {
                assertEquals("GL_OUT_OF_MEMORY", expected.message)
            }
            assertEquals(TimedJob.Result.NotPosted, TimedJob.run(1, { false }, { _: String -> }) { "x" })
        } finally {
            gl.shutdownNow()
        }
    }

    // ------------------------------------------------------------------ smoothing

    @Test
    fun `the mask is an exponential moving average and a new size starts over`() {
        val s = MaskSmoother(alpha = 0.5f)
        assertArrayEquals(floatArrayOf(0f, 1f, 0.5f, 1f), s.push(floatArrayOf(0f, 1f, 0.5f, 7f), 2, 2), 1e-6f)
        assertArrayEquals(floatArrayOf(0.5f, 0.5f, 0.5f, 1f), s.push(floatArrayOf(1f, 0f, 0.5f, 1f), 2, 2), 1e-6f)
        assertArrayEquals(floatArrayOf(0.75f, 0.25f, 0.5f, 1f), s.push(floatArrayOf(1f, 0f, 0.5f, 1f), 2, 2), 1e-6f)
        assertArrayEquals(byteArrayOf(191.toByte(), 64, 128.toByte(), 255.toByte()), s.toBytes())
        // Another size: no blending with the old cells.
        assertArrayEquals(floatArrayOf(1f, 0f), s.push(floatArrayOf(1f, -3f), 2, 1), 1e-6f)
        assertEquals(2, s.width)
        assertEquals(1, s.height)
    }

    @Test
    fun `the mask converges and a flickering cell is damped`() {
        val s = MaskSmoother(alpha = 0.6f)
        val values = (0 until 40).map { i -> s.push(floatArrayOf(if (i % 2 == 0) 1f else 0f), 1, 1)[0] }
        // Steady state: 0.6 / (1 − 0.16) ≈ 0.714 and 0.4 × that ≈ 0.286 —
        // a full 0/1 flicker becomes a swing of ~0.43 around the middle.
        val swing = values.takeLast(2).let { abs(it[0] - it[1]) }
        assertEquals(0.4286f, swing, 1e-3f)
        assertEquals(0.5f, values.takeLast(2).average().toFloat(), 1e-3f)
    }

    @Test
    fun `landmarks are smoothed, a jump is taken at once, presence fades`() {
        val s = LandmarkSmoother(alpha = 0.5f, jump = 0.12f, lostAfter = 2, fade = 0.5f)
        assertNull(s.push(null))
        assertEquals(0f, s.presence)
        assertArrayEquals(floatArrayOf(0.5f, 0.5f), s.push(floatArrayOf(0.5f, 0.5f)), 1e-6f)
        assertEquals(0.5f, s.presence)
        assertArrayEquals(floatArrayOf(0.55f, 0.5f), s.push(floatArrayOf(0.6f, 0.5f)), 1e-6f)
        assertEquals(1f, s.presence)
        // A jump of 0.3: no sliding across the picture.
        assertArrayEquals(floatArrayOf(0.85f, 0.5f), s.push(floatArrayOf(0.85f, 0.5f)), 1e-6f)
        // Lost: kept for one analysis, then fades out and is forgotten.
        assertNotNull(s.push(null))
        assertEquals(1f, s.presence)
        assertNotNull(s.push(null))
        assertEquals(0.5f, s.presence)
        assertNull(s.push(null))
        assertEquals(0f, s.presence)
    }

    // -------------------------------------------------------------- face geometry

    /**
     * A synthetic upright face: centre (0.5, 0.45) in the image (top-down),
     * half-width [hw] and half-height [hh] (image units), eyes 0.3 above the
     * centre, the mouth below; [roll] rotates the whole face.
     */
    private fun face(hw: Float = 0.2f, hh: Float = 0.16f, roll: Float = 0f, aspect: Float = 9f / 16f): FloatArray {
        val pts = FloatArray(478 * 2)
        val cx = 0.5f
        val cy = 0.45f
        fun put(i: Int, x: Float, y: Float) {
            // Rotate around the centre in an aspect-correct frame (x scaled).
            val dx = (x - cx) * aspect
            val dy = y - cy
            val rx = dx * cos(roll) - dy * sin(roll)
            val ry = dx * sin(roll) + dy * cos(roll)
            pts[2 * i] = cx + rx / aspect
            pts[2 * i + 1] = cy + ry
        }
        for (i in 0 until 478) put(i, cx, cy)
        FaceShape.FACE_OVAL.forEachIndexed { k, i ->
            val a = 2 * PI * k / FaceShape.FACE_OVAL.size - PI / 2
            put(i, cx + hw * cos(a).toFloat(), cy + hh * sin(a).toFloat())
        }
        put(FaceShape.RIGHT_EYE_OUTER, cx - hw * 0.6f, cy - hh * 0.3f)
        put(FaceShape.RIGHT_EYE_INNER, cx - hw * 0.2f, cy - hh * 0.3f)
        put(FaceShape.LEFT_EYE_INNER, cx + hw * 0.2f, cy - hh * 0.3f)
        put(FaceShape.LEFT_EYE_OUTER, cx + hw * 0.6f, cy - hh * 0.3f)
        put(FaceShape.MOUTH_LEFT, cx - hw * 0.3f, cy + hh * 0.55f)
        put(FaceShape.MOUTH_RIGHT, cx + hw * 0.3f, cy + hh * 0.55f)
        put(FaceShape.LIP_TOP, cx, cy + hh * 0.5f)
        put(FaceShape.LIP_BOTTOM, cx, cy + hh * 0.6f)
        put(FaceShape.NOSE_TIP, cx, cy + hh * 0.1f)
        return pts
    }

    private val aspect = 9f / 16f

    @Test
    fun `the face shape is in texture space with v flipped and u scaled by the aspect`() {
        val shape = FaceShape.from(face(), aspect, slim = 0f)!!
        assertEquals(0.5f * aspect, shape.cx, 1e-3f)
        assertEquals("v = 1 − y", 1f - 0.45f, shape.cy, 2e-3f)
        assertEquals(0.2f * aspect, shape.ax, 2e-3f)
        assertEquals(0.16f, shape.ay, 2e-3f)
        assertEquals(0f, shape.angle, 1e-4f)
        assertEquals(0.4f * aspect, shape.faceWidth, 4e-3f)
        val (right, left) = shape.eyes
        assertTrue("the image's left eye is on the left", right.x < left.x)
        assertTrue("eyes are above the centre (v up)", right.y > shape.cy)
        assertEquals(0.4f * 0.2f * aspect * 0.9f, right.r, 1e-4f)
        assertTrue("the mouth is below the centre", shape.mouth.y < shape.cy)
        // No slimming: every pull is a no-op.
        for (p in shape.pulls) {
            assertEquals(p.cx, p.tx, 1e-7f)
            assertEquals(p.cy, p.ty, 1e-7f)
        }
    }

    @Test
    fun `a rolled face is measured in its own frame`() {
        val roll = 0.3f
        val shape = FaceShape.from(face(roll = roll), aspect, slim = 0f)!!
        // The image is top-down: a roll by +r in the image reads as −r with v up.
        assertEquals(-roll, shape.angle, 1e-3f)
        assertEquals(0.2f * aspect, shape.ax, 3e-3f)
        assertEquals(0.16f, shape.ay, 3e-3f)
    }

    @Test
    fun `too few or degenerate landmarks give no face`() {
        assertNull(FaceShape.from(FloatArray(100), aspect, 0f))
        assertNull("all points in one place", FaceShape.from(FloatArray(478 * 2) { 0.5f }, aspect, 0f))
        assertNull(FaceShape.from(face(), 0f, 0f))
    }

    @Test
    fun `slimming moves each jaw point inwards by at most 3,5 % of the face width`() {
        val shape = FaceShape.from(face(), aspect, slim = 1f)!!
        for (p in shape.pulls) {
            val shift = hypot(p.tx - p.cx, p.ty - p.cy)
            assertEquals(FaceShape.MAX_SLIM * shape.faceWidth, shift, 1e-5f)
            assertTrue("towards the face's centre line", abs(p.tx - shape.cx) < abs(p.cx - shape.cx))
            assertTrue("the shift can never fold the picture", WarpMath.pullIsFoldFree(p))
        }
    }

    // ------------------------------------------------------------------ the warp

    @Test
    fun `the falloff is 1 at the centre, 0 with a flat slope at the edge`() {
        assertEquals(1f, WarpMath.falloff(0f), 0f)
        assertEquals(0f, WarpMath.falloff(1f), 0f)
        assertEquals(0f, WarpMath.falloff(3f), 0f)
        val h = 1e-3f
        assertEquals(0f, (WarpMath.falloff(1f) - WarpMath.falloff(1f - h)) / h, 2e-2f)
        var maxSlope = 0f
        var t = 0f
        while (t < 1f) {
            maxSlope = maxOf(maxSlope, abs(WarpMath.falloff(t + 1e-4f) - WarpMath.falloff(t)) / 1e-4f)
            t += 1e-3f
        }
        assertEquals(WarpMath.FALLOFF_MAX_SLOPE, maxSlope, 1e-2f)
    }

    @Test
    fun `strength 0 is the identity everywhere`() {
        val shape = FaceShape.from(face(), aspect, slim = 0f)!!
        var x = 0f
        while (x <= aspect) {
            var y = 0f
            while (y <= 1f) {
                val (sx, sy) = WarpMath.warp(x, y, shape, eyes = 0f)
                assertEquals(x, sx, 1e-6f)
                assertEquals(y, sy, 1e-6f)
                y += 0.02f
            }
            x += 0.02f
        }
    }

    @Test
    fun `a pull samples the source point at its target and nothing outside its radius`() {
        val p = FaceShape.Pull(cx = 0.3f, cy = 0.5f, tx = 0.31f, ty = 0.5f, r = 0.1f)
        val (sx, sy) = WarpMath.pull(p.tx, p.ty, p)
        assertEquals("the target shows what was at the source", p.cx, sx, 1e-6f)
        assertEquals(p.cy, sy, 1e-6f)
        assertEquals(0.5f to 0.5f, WarpMath.pull(0.5f, 0.5f, p))
        // Continuous at the edge of the radius.
        val (ex, _) = WarpMath.pull(p.tx + p.r * 0.999f, p.ty, p)
        assertEquals(p.tx + p.r * 0.999f, ex, 1e-5f)
    }

    @Test
    fun `the strongest slimming and eye warp never fold the picture`() {
        val shape = FaceShape.from(face(), aspect, slim = 1f)!!
        // Along horizontal and vertical lines through the face the inverse
        // map must keep increasing (no fold, no tear).
        for (row in 0..40) {
            val y = shape.cy - shape.ay * 1.3f + row * shape.ay * 2.6f / 40
            var prev = -Float.MAX_VALUE
            var x = shape.cx - shape.ax * 1.6f
            while (x < shape.cx + shape.ax * 1.6f) {
                val (sx, _) = WarpMath.warp(x, y, shape, eyes = 1f)
                assertTrue("fold at ($x, $y): $sx after $prev", sx > prev)
                prev = sx
                x += 0.0005f
            }
        }
        for (col in 0..40) {
            val x = shape.cx - shape.ax * 1.3f + col * shape.ax * 2.6f / 40
            var prev = -Float.MAX_VALUE
            var y = shape.cy - shape.ay * 1.6f
            while (y < shape.cy + shape.ay * 1.6f) {
                val (_, sy) = WarpMath.warp(x, y, shape, eyes = 1f)
                assertTrue("fold at ($x, $y): $sy after $prev", sy > prev)
                prev = sy
                y += 0.0005f
            }
        }
    }

    @Test
    fun `eyes are enlarged by at most 1 over 1 minus 16 % and only inside their circle`() {
        val e = FaceShape.Circle(0.3f, 0.6f, 0.04f)
        val s = FaceShape.MAX_EYES
        // Near the centre, a point at d samples d·(1 − s): enlarged by 1/(1 − s).
        val (sx, _) = WarpMath.magnify(e.x + 0.001f, e.y, e, s)
        assertEquals(0.001f * (1 - s), sx - e.x, 1e-6f)
        assertEquals(1.19f, 1 / (1 - s), 0.01f)
        assertEquals(e.x + e.r to e.y, WarpMath.magnify(e.x + e.r, e.y, e, s))
        assertEquals(0.9f to 0.9f, WarpMath.magnify(0.9f, 0.9f, e, s))
    }

    @Test
    fun `the skin weight covers the cheeks, not the eyes, the mouth or the background`() {
        val shape = FaceShape.from(face(), aspect, slim = 0f)!!
        val cheekX = shape.cx - shape.ax * 0.5f
        val cheekY = shape.cy - shape.ay * 0.1f
        assertEquals(1f, WarpMath.skin(cheekX, cheekY, shape), 1e-3f)
        assertEquals(0f, WarpMath.skin(shape.eyes[0].x, shape.eyes[0].y, shape), 1e-6f)
        assertEquals(0f, WarpMath.skin(shape.mouth.x, shape.mouth.y, shape), 1e-6f)
        assertEquals(0f, WarpMath.skin(shape.cx + shape.ax * 1.2f, shape.cy, shape), 1e-6f)
    }

    @Test
    fun `brighten lifts the mid-tones and keeps black, white and order`() {
        assertEquals(0f, WarpMath.brighten(0f, 1f), 0f)
        assertEquals(1f, WarpMath.brighten(1f, 1f), 0f)
        assertEquals(0.5f, WarpMath.brighten(0.5f, 0f), 0f)
        assertEquals(0.5f + 0.45f * 0.25f * 1.6f, WarpMath.brighten(0.5f, 1f), 1e-6f)
        var prev = -1f
        var v = 0f
        while (v <= 1f) {
            val out = WarpMath.brighten(v, 1f)
            assertTrue(out >= v - 1e-6f && out <= 1f)
            assertTrue("monotonic", out > prev)
            prev = out
            v += 0.01f
        }
    }

    // ------------------------------------------------------------- params, sizes

    @Test
    fun `params from the channel are clamped and missing values are 0`() {
        val p = FreeFxParams.fromMap(mapOf("blur" to true, "smooth" to 1.7, "brighten" to -2, "eyes" to 0.25, "slim" to Double.NaN))
        assertEquals(FreeFxParams(blur = true, smooth = 1f, brighten = 0f, slim = 0f, eyes = 0.25f), p)
        assertTrue(FreeFxParams.fromMap(null).none)
        assertTrue(FreeFxParams.fromMap(mapOf("blur" to "yes")).none)
        assertFalse(FreeFxParams(brighten = 0.01f).none)
        assertTrue(FreeFxParams(brighten = 0.01f).beauty)
        assertFalse(FreeFxParams(blur = true).beauty)
    }

    @Test
    fun `the analysis image is 256 px on the long side with the frame's aspect`() {
        assertEquals(144 to 256, AnalysisSize.of(720, 1280))
        assertEquals(256 to 144, AnalysisSize.of(1280, 720))
        assertEquals(256 to 192, AnalysisSize.of(640, 480))
        assertEquals("never upscaled", 200 to 100, AnalysisSize.of(200, 100))
        assertEquals(0 to 0, AnalysisSize.of(0, 720))
    }

    @Test
    fun `analysis takes every other frame and only when idle`() {
        val pacer = AnalysisPacer(every = 2)
        val taken = (1..10).map { pacer.shouldAnalyze(analyzerIdle = true) }
        assertEquals(listOf(false, true, false, true, false, true, false, true, false, true), taken)
        assertFalse(pacer.shouldAnalyze(analyzerIdle = false))
        assertTrue("taken as soon as idle again", pacer.shouldAnalyze(analyzerIdle = true))
    }

    // ------------------------------------------------------------- the face model

    private fun sha256(bytes: ByteArray) =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    @Test
    fun `the model is downloaded once, checked and installed atomically`() {
        val content = ByteArray(200_000) { (it * 31).toByte() }
        val source = temp.newFile("remote.task").apply { writeBytes(content) }
        val dir = File(temp.root, "files/kabso_camera_fx")
        val model = ModelFile(dir, "face_landmarker.task", source.toURI().toString(), sha256(content))
        val installed = model.ensure()
        assertArrayEquals(content, installed.readBytes())
        assertFalse(File(dir, "face_landmarker.task.part").exists())
        // Already there and valid: no download (the source is gone).
        source.delete()
        assertEquals(installed, model.ensure())
    }

    @Test
    fun `a model with the wrong checksum is refused and nothing is installed`() {
        val source = temp.newFile("remote.task").apply { writeBytes(ByteArray(1000) { 7 }) }
        val dir = File(temp.root, "files")
        val model = ModelFile(dir, "m.task", source.toURI().toString(), sha256(ByteArray(1000) { 8 }))
        try {
            model.ensure()
            fail("expected a checksum error")
        } catch (expected: IOException) {
            assertEquals("checksum mismatch", expected.message)
        }
        assertFalse(model.file.exists())
        assertFalse(File(dir, "m.task.part").exists())
    }

    @Test
    fun `a corrupted installed model is replaced, an oversized one is refused`() {
        val content = ByteArray(5000) { 3 }
        val source = temp.newFile("remote.task").apply { writeBytes(content) }
        val dir = temp.newFolder("files")
        File(dir, "m.task").writeBytes(ByteArray(10) { 9 })
        val model = ModelFile(dir, "m.task", source.toURI().toString(), sha256(content))
        assertArrayEquals(content, model.ensure().readBytes())

        val small = ModelFile(temp.newFolder("other"), "m.task", source.toURI().toString(), sha256(content), maxBytes = 1000)
        try {
            small.ensure()
            fail("expected the size limit")
        } catch (expected: IOException) {
            assertTrue(expected.message!!.contains("larger"))
        }
        assertFalse(small.file.exists())
    }

    @Test
    fun `the pinned face model is Google's float16 version 1`() {
        assertTrue(ModelFile.FACE_LANDMARKER_URL.startsWith("https://storage.googleapis.com/mediapipe-models/face_landmarker/"))
        assertTrue(ModelFile.FACE_LANDMARKER_URL.contains("/float16/1/"))
        assertEquals(64, ModelFile.FACE_LANDMARKER_SHA256.length)
    }
}
