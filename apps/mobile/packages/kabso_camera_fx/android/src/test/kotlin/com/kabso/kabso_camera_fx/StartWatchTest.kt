package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

/**
 * D144b: the owner's device (staging APK incl. D157) showed background blur
 * «جارٍ تشغيل المؤثر…» for ever with the overlay at
 * `DeepAR initializing … in 0 fed 0 out 0 … init no #1 on track`: the
 * processor was on a track, DeepAR was created, and not one camera frame
 * reached the stage — and D144a's 10 s safety net never fired, because it was
 * only armed and asked from the per-frame path.
 */
class StartWatchTest {
    private val ms = TimeUnit.MILLISECONDS.toNanos(1)
    private val timeout = DeepArStage.WARMUP_MS * ms

    // ------------------------------------------------------ the D144b watch

    @Test
    fun `no camera frame since the pick - no_frames at 10 s, waiting before`() {
        val watch = StartWatch(timeout)
        val frames = 0L // the owner's "in 0"
        watch.arm(0, frames)
        assertEquals(StartWatch.Verdict.WAITING, watch.check(9_999 * ms, frames, initialized = false))
        assertEquals(StartWatch.Verdict.NO_FRAMES, watch.check(10_000 * ms, frames, initialized = false))
    }

    @Test
    fun `frames before the pick do not count - only frames since it`() {
        val watch = StartWatch(timeout)
        watch.arm(5_000 * ms, framesSoFar = 700)
        assertEquals(StartWatch.Verdict.NO_FRAMES, watch.check(15_000 * ms, 700, initialized = false))
    }

    @Test
    fun `frames came but DeepAR never initialized - init_timeout`() {
        val watch = StartWatch(timeout)
        watch.arm(0, 0)
        assertEquals(StartWatch.Verdict.INIT_TIMEOUT, watch.check(10_000 * ms, 280, initialized = false))
    }

    @Test
    fun `DeepAR initialized but published nothing fresh - no_output`() {
        val watch = StartWatch(timeout)
        watch.arm(0, 0)
        assertEquals(StartWatch.Verdict.NO_OUTPUT, watch.check(10_000 * ms, 280, initialized = true))
    }

    @Test
    fun `a fresh render in time - ok, then and later`() {
        val watch = StartWatch(timeout)
        watch.arm(0, 0)
        watch.onOutput()
        assertEquals(StartWatch.Verdict.OK, watch.check(10_000 * ms, 280, initialized = true))
        assertEquals(StartWatch.Verdict.OK, watch.check(600_000 * ms, 280, initialized = true))
    }

    @Test
    fun `a new pick supersedes the old timer, None disarms`() {
        val watch = StartWatch(timeout)
        val first = watch.arm(0, 0)
        watch.onOutput()
        val second = watch.arm(20_000 * ms, 900)
        assertNotEquals(first, second)
        assertFalse(watch.isCurrent(first))
        assertTrue(watch.isCurrent(second))
        // The new pick starts over: no output yet.
        assertEquals(StartWatch.Verdict.NO_FRAMES, watch.check(30_000 * ms, 900, initialized = true))
        watch.disarm()
        assertFalse(watch.isCurrent(second))
        assertEquals(StartWatch.Verdict.OK, watch.check(40_000 * ms, 900, initialized = false))
    }

    @Test
    fun `threaded - frames and output on the capture thread, the check on a timer`() {
        val watch = StartWatch(50 * ms)
        val frames = AtomicLong()
        val start = System.nanoTime()
        watch.arm(start, 0)
        val capture = thread {
            repeat(20) {
                frames.incrementAndGet()
                Thread.sleep(1)
            }
            watch.onOutput()
        }
        capture.join()
        Thread.sleep(60)
        assertEquals(StartWatch.Verdict.OK, watch.check(System.nanoTime(), frames.get(), initialized = true))
    }

    // ------------------------------------------------- the camera's frame path

    /** flutter_webrtc's `VideoSource`: one processor; its sink feeds every track. */
    private class FakeSource {
        var processor: FakeWrapper? = null
        val preview = AtomicLong()

        fun setVideoProcessor(next: FakeWrapper) {
            processor?.sinkSet = false
            processor = next
            next.sinkSet = true
        }

        /** The capturer delivers a frame. */
        fun capture(frame: Int) {
            val p = processor ?: return
            val out = p.onFrameCaptured(frame) ?: return
            if (out >= 0) preview.incrementAndGet()
        }
    }

    /** flutter_webrtc's `LocalVideoTrack`: runs its processors, then the sink. */
    private class FakeWrapper {
        var sinkSet = false
        val processors = mutableListOf<(Int) -> Int>()
        fun onFrameCaptured(frame: Int): Int? {
            if (!sinkSet) return null
            var f = frame
            for (p in processors) f = p(f)
            return f
        }
    }

    @Test
    fun `a shared camera track - its processor sees no frame while the picture is normal (the owner's in 0)`() {
        val source = FakeSource()
        val primary = FakeWrapper() // the camera's first getUserMedia
        source.setVideoProcessor(primary)
        val shared = FakeWrapper() // the same camera asked for again: shared
        val seen = AtomicLong()
        shared.processors += { f -> seen.incrementAndGet(); f } // our attach
        repeat(159) { source.capture(it) }
        assertEquals(0, seen.get()) // in 0
        assertEquals(159, source.preview.get()) // the camera picture is fine
    }

    @Test
    fun `D144b bind - the shared track goes onto the frame path, the picture keeps flowing`() {
        val source = FakeSource()
        val primary = FakeWrapper()
        source.setVideoProcessor(primary)
        val shared = FakeWrapper()
        val seen = AtomicLong()
        shared.processors += { f -> seen.incrementAndGet(); f }

        val result = FramePath.bind(source.processor, shared) { source.setVideoProcessor(it) }
        assertEquals(FramePath.Result.REBOUND, result)
        assertSame(shared, source.processor)
        repeat(30) { source.capture(it) }
        assertEquals(30, seen.get())
        assertEquals(30, source.preview.get())
    }

    @Test
    fun `bind on the camera's own track changes nothing`() {
        val source = FakeSource()
        val primary = FakeWrapper()
        source.setVideoProcessor(primary)
        val installed = AtomicBoolean(false)
        assertEquals(FramePath.Result.ON_PATH, FramePath.bind(source.processor, primary) { installed.set(true) })
        assertFalse(installed.get())
    }

    // --------------------------------------------- DeepAR + colour (+ light)

    private class Frame(val name: String) {
        var released = 0
    }

    @Test
    fun `effect, colour filter and fill light together - both stages run, DeepAR first`() {
        val camera = Frame("camera")
        val deepAr = Frame("deepar")
        val stages = mutableListOf<String>()
        val (out, ours) = FxChain.run(
            camera,
            effect = { f -> stages += "deepar<-${f.name}"; deepAr },
            // D157: the light and the filter are one matrix in this stage.
            color = { f -> stages += "color<-${f.name}"; Frame("colored") },
            release = { it.released++ },
        )
        assertEquals(listOf("deepar<-camera", "color<-deepar"), stages)
        assertEquals("colored", out.name)
        assertTrue(ours)
        assertEquals(1, deepAr.released) // drawn by the colour stage: back
        assertEquals(0, camera.released) // the capturer's: not ours
    }

    @Test
    fun `the effect still starting - the colour stage gets the camera frame`() {
        val camera = Frame("camera")
        val (out, ours) = FxChain.run(camera, { null }, { f -> Frame("colored<-${f.name}") }, { it.released++ })
        assertEquals("colored<-camera", out.name)
        assertTrue(ours)
    }

    @Test
    fun `only the effect, or nothing at all`() {
        val camera = Frame("camera")
        val deepAr = Frame("deepar")
        val (effectOnly, ours) = FxChain.run(camera, { deepAr }, { null }, { it.released++ })
        assertSame(deepAr, effectOnly)
        assertTrue(ours)
        assertEquals(0, deepAr.released)
        val (plain, mine) = FxChain.run(camera, { null }, { null }, { it.released++ })
        assertSame(camera, plain)
        assertFalse(mine)
    }
}
