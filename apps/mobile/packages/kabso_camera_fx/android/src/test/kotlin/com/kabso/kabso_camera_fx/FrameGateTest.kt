package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.thread
import kotlin.concurrent.withLock

/**
 * D144a: the owner's freeze (background blur showed DeepAR's watermark, then a
 * still picture) reproduced with a fake DeepAR, and the rules that stop it.
 *
 * The fake follows what DeepAR does in live mode with a render surface: it
 * keeps re-drawing the last camera image it took, also when it takes no new
 * one. A frame is an image number; "released" counts what went back to the
 * render helper (its single texture).
 */
class FrameGateTest {
    private class Frame(val image: Int) {
        val released = AtomicBoolean(false)
    }

    private val releasedCount = AtomicInteger()
    private fun release(frame: Frame) {
        assertFalse("released twice", frame.released.getAndSet(true))
        releasedCount.incrementAndGet()
    }

    private val ms = TimeUnit.MILLISECONDS.toNanos(1)

    // ---------------------------------------------------------- the old slot

    /** D144's hand-off: whatever render is waiting goes out. */
    private class OldSlot {
        private val lock = ReentrantLock()
        private var frame: Frame? = null
        fun offer(next: Frame) = lock.withLock { frame = next }
        fun take(): Frame? = lock.withLock { frame.also { frame = null } }
    }

    @Test
    fun `D144 slot - a DeepAR that stops taking frames freezes the picture`() {
        val slot = OldSlot()
        var deepArImage = 0
        val published = mutableListOf<Int?>()
        for (camera in 1..10) {
            // DeepAR takes camera frames 1..3, then no more (stuck/wedged)…
            if (camera <= 3) deepArImage = camera
            // …but keeps re-drawing its last image into the surface.
            slot.offer(Frame(deepArImage))
            published += slot.take()?.image
        }
        // Image 3 published 8 times: the still picture the owner saw.
        assertEquals(listOf(1, 2, 3, 3, 3, 3, 3, 3, 3, 3), published)
    }

    // --------------------------------------------------------- the new gate

    @Test
    fun `a stopped DeepAR never repeats a picture - raw frames pass instead`() {
        val gate = FreshGate<Frame>(::release)
        var deepArImage = 0
        val published = mutableListOf<Int?>()
        for (camera in 1..10) {
            // DeepAR's thread takes frames 1..3; on frame 4 it hangs inside
            // receiveFrame (started, never done) and takes nothing more.
            if (camera <= 4) gate.feedStarted(camera.toLong())
            if (camera <= 3) {
                deepArImage = camera
                gate.feedDone(camera.toLong())
            }
            gate.offer(Frame(deepArImage)) // the re-draw
            gate.offer(Frame(deepArImage)) // and another
            published += gate.take(0)?.image
        }
        assertEquals(listOf(1, 2, 3, null, null, null, null, null, null, null), published)
        // Every other render went back to the helper at once (its one
        // texture), but the last one, still waiting.
        assertEquals(20L, gate.counts().first)
        assertEquals(20 - 3 - 1, releasedCount.get())
        gate.clear()
        assertEquals(20 - 3, releasedCount.get())
    }

    @Test
    fun `a healthy DeepAR - every camera frame gets a new picture, in order`() {
        val gate = FreshGate<Frame>(::release)
        val published = mutableListOf<Int?>()
        for (camera in 1..50) {
            gate.feedStarted(camera.toLong())
            gate.offer(Frame(camera)) // rendered while receiveFrame runs
            gate.feedDone(camera.toLong())
            published += gate.take(0)?.image
        }
        assertEquals((1..50).toList(), published)
        assertEquals(0, releasedCount.get())
    }

    @Test
    fun `a render waits for its feed to finish, and is used once`() {
        val gate = FreshGate<Frame>(::release)
        gate.feedStarted(1)
        gate.feedDone(1)
        assertNull("render not there yet: raw", gate.take(0))
        gate.offer(Frame(1)) // arrives after the deadline
        gate.feedStarted(2)
        assertEquals(1, gate.take(0)?.image) // newer than anything published
        gate.offer(Frame(1)) // a re-draw of image 1 while feed 2 runs…
        assertNull("feed 2 not done: not published", gate.take(0))
        gate.offer(Frame(2)) // …replaced by the real one
        gate.feedDone(2)
        assertEquals(2, gate.take(0)?.image)
        gate.offer(Frame(2)) // re-draw, already published
        assertNull(gate.take(0))
        assertEquals(2, releasedCount.get())
    }

    @Test
    fun `take waits up to the timeout and wakes on a fresh render`() {
        val gate = FreshGate<Frame>(::release)
        gate.feedStarted(1)
        gate.feedDone(1)
        val renderer = thread {
            Thread.sleep(10)
            gate.offer(Frame(7))
        }
        val start = System.nanoTime()
        val taken = gate.take(2_000 * ms)
        renderer.join()
        assertEquals(7, taken?.image)
        assertTrue(System.nanoTime() - start < 1_000 * ms)

        val waitStart = System.nanoTime()
        assertNull(gate.take(30 * ms))
        assertTrue(System.nanoTime() - waitStart >= 25 * ms)
    }

    @Test
    fun `take wakes when the feed finishes`() {
        val gate = FreshGate<Frame>(::release)
        gate.feedStarted(1)
        gate.offer(Frame(1))
        val deepAr = thread {
            Thread.sleep(10)
            gate.feedDone(1)
        }
        assertEquals(1, gate.take(2_000 * ms)?.image)
        deepAr.join()
    }

    @Test
    fun `clear releases the waiting render`() {
        val gate = FreshGate<Frame>(::release)
        gate.feedStarted(1)
        gate.offer(Frame(1))
        gate.clear()
        gate.feedDone(1)
        assertNull(gate.take(0))
        assertEquals(1, releasedCount.get())
    }

    /**
     * Threads as on the device: a capture thread at ~100 fps, DeepAR's thread
     * taking one frame at a time (in flight), and a render thread re-drawing
     * continuously. DeepAR's thread blocks for good at camera frame 40.
     */
    @Test
    fun `threads - a stuck DeepAR thread gives raw frames, not a still`() {
        val gate = FreshGate<Frame>(::release)
        val image = AtomicInteger(0)
        val stop = AtomicBoolean(false)
        val stuck = java.util.concurrent.CountDownLatch(1)
        val inFlight = AtomicBoolean(false)
        val deepArQueue = java.util.concurrent.LinkedBlockingQueue<Int>()

        val deepArThread = thread(isDaemon = true) {
            while (!stop.get()) {
                val seq = deepArQueue.poll(5, TimeUnit.MILLISECONDS) ?: continue
                gate.feedStarted(seq.toLong())
                if (seq >= 40) {
                    // Hangs inside receiveFrame for good.
                    try {
                        stuck.await()
                    } catch (_: InterruptedException) {
                        return@thread
                    }
                }
                image.set(seq)
                gate.feedDone(seq.toLong())
                inFlight.set(false)
            }
        }
        val renderThread = thread(isDaemon = true) {
            while (!stop.get()) {
                gate.offer(Frame(image.get()))
                Thread.sleep(2)
            }
        }

        val published = mutableListOf<Int?>()
        val health = OutputHealth(maxMisses = 30, warmupNanos = 5_000 * ms)
        health.arm(System.nanoTime())
        var gaveUp = -1
        for (camera in 1..120) {
            if (inFlight.compareAndSet(false, true)) deepArQueue.add(camera)
            val out = gate.take(40 * ms)
            published += out?.image
            if (out == null) {
                if (health.onMiss(System.nanoTime()) == OutputHealth.Verdict.GIVE_UP && gaveUp < 0) gaveUp = camera
            } else {
                health.onOutput()
                release(out)
            }
            Thread.sleep(10)
        }
        stop.set(true)
        renderThread.join()

        val pictures = published.filterNotNull()
        // Before the stall: pictures advance, never back, and a re-draw can
        // at most stand in once for a frame (a dropped frame, not a still).
        assertTrue(pictures.size > 5)
        assertEquals(pictures.sorted(), pictures)
        assertTrue("$pictures", pictures.groupingBy { it }.eachCount().values.all { it <= 2 })
        assertTrue(pictures.all { it < 40 })
        // After it: raw frames (null), and the effect is given up on.
        assertTrue(published.takeLast(60).all { it == null })
        assertTrue("gave up at $gaveUp", gaveUp in 40..110)
        deepArThread.interrupt()
    }

    // ----------------------------------------------------------- health

    @Test
    fun `health - warm-up allows a slow start, then 30 misses give up`() {
        val health = OutputHealth(maxMisses = 30, warmupNanos = 10_000 * ms)
        health.arm(0)
        // 9 s of nothing: still warming up.
        for (i in 1..270) assertEquals(OutputHealth.Verdict.OK, health.onMiss(i * 33 * ms))
        assertTrue(health.warmingUp(9_000 * ms))
        health.onOutput()
        for (i in 1..29) assertEquals(OutputHealth.Verdict.OK, health.onMiss(10_000 * ms))
        assertEquals(OutputHealth.Verdict.GIVE_UP, health.onMiss(10_000 * ms))
    }

    @Test
    fun `health - no first render within the warm-up gives up`() {
        val health = OutputHealth(maxMisses = 30, warmupNanos = 10_000 * ms)
        health.arm(1_000 * ms)
        assertEquals(OutputHealth.Verdict.OK, health.onMiss(10_999 * ms))
        assertEquals(OutputHealth.Verdict.GIVE_UP, health.onMiss(11_000 * ms))
    }

    @Test
    fun `health - an output resets the run of misses`() {
        val health = OutputHealth(maxMisses = 3, warmupNanos = 0)
        health.arm(0)
        health.onOutput()
        health.onMiss(0)
        health.onMiss(0)
        health.onOutput()
        assertEquals(OutputHealth.Verdict.OK, health.onMiss(0))
        assertEquals(1, health.consecutiveMisses)
    }

    // --------------------------------------------------------- geometry

    @Test
    fun `geometry - latched at the first frame, capped, even`() {
        assertEquals(InputGeometry(1280, 720, 270), InputGeometry.latch(1280, 720, 270, 1280))
        assertEquals(InputGeometry(1280, 720, 90), InputGeometry.latch(1920, 1080, 90, 1280))
        assertEquals(InputGeometry(640, 360, 0), InputGeometry.latch(641, 361, 0, 1280))
        val portrait = InputGeometry(1280, 720, 270)
        assertEquals(720, portrait.outWidth)
        assertEquals(1280, portrait.outHeight)
        val flat = InputGeometry(1280, 720, 0)
        assertEquals(1280, flat.outWidth)
    }

    @Test
    fun `geometry - another size is centre-cropped to the latched aspect`() {
        val geo = InputGeometry(1280, 720, 270)
        // Same aspect (WebRTC scaled down): whole frame.
        assertEquals(InputGeometry.Crop(0, 0, 960, 540), geo.cropFor(960, 540))
        // 4:3 into 16:9: top and bottom go.
        assertEquals(InputGeometry.Crop(0, 60, 640, 360), geo.cropFor(640, 480))
        // Narrower than 16:9 the other way: the sides go.
        assertEquals(InputGeometry.Crop(160, 0, 960, 720), InputGeometry.centreCrop(1280, 720, 4, 3))
    }
}
