package com.kabso.kabso_streamer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** D213: the streamer's plain-Kotlin rules (the JVM, no device). */
class StreamerRulesTest {
    @Test
    fun gameIsAddedUnderTheVoice() {
        val voice = floatArrayOf(1000f, -2000f, 0f)
        val game = floatArrayOf(500f, 500f, 100f)
        StreamerRules.mix(voice, 3, micMuted = false, game = game, gameFrames = 3, gameMuted = false)
        assertEquals(1000f + 400f, voice[0], 0.01f)
        assertEquals(-2000f + 400f, voice[1], 0.01f)
        assertEquals(80f, voice[2], 0.01f)
    }

    @Test
    fun micAndGameMuteSeparately() {
        val voice = floatArrayOf(1000f, 1000f)
        val game = floatArrayOf(500f, 500f)
        StreamerRules.mix(voice, 2, micMuted = true, game = game, gameFrames = 2, gameMuted = false)
        assertEquals(400f, voice[0], 0.01f) // the game alone
        val voice2 = floatArrayOf(1000f, 1000f)
        StreamerRules.mix(voice2, 2, micMuted = false, game = game, gameFrames = 2, gameMuted = true)
        assertEquals(1000f, voice2[0], 0.01f) // the voice alone
        val voice3 = floatArrayOf(1000f, 1000f)
        StreamerRules.mix(voice3, 2, micMuted = true, game = game, gameFrames = 2, gameMuted = true)
        assertEquals(0f, voice3[1], 0f) // silence
    }

    @Test
    fun missingGameSamplesAreSilence() {
        val voice = floatArrayOf(10f, 10f, 10f)
        val game = floatArrayOf(1000f, 9999f, 9999f) // stale tail must not be used
        StreamerRules.mix(voice, 3, micMuted = false, game = game, gameFrames = 1, gameMuted = false)
        assertEquals(10f + 800f, voice[0], 0.01f)
        assertEquals(10f, voice[1], 0f)
        assertEquals(10f, voice[2], 0f)
    }

    @Test
    fun loudMixesAreLimitedNeverWrapped() {
        val voice = floatArrayOf(30000f, -30000f)
        val game = floatArrayOf(30000f, -30000f)
        val peak = StreamerRules.mix(voice, 2, false, game, 2, false)
        assertTrue(voice[0] <= StreamerRules.FULL_SCALE)
        assertTrue(voice[0] > 26000f)
        assertTrue(voice[1] >= -StreamerRules.FULL_SCALE)
        assertTrue(peak <= StreamerRules.FULL_SCALE)
        assertEquals(1000f, StreamerRules.limit(1000f), 0f)
    }

    @Test
    fun phoneCallModesAndRotation() {
        assertTrue(StreamerRules.isPhoneCall(1)) // ringing
        assertTrue(StreamerRules.isPhoneCall(2)) // in call
        assertTrue(StreamerRules.isPhoneCall(4)) // call screening
        assertFalse(StreamerRules.isPhoneCall(0)) // normal
        assertFalse(StreamerRules.isPhoneCall(3)) // our own VoIP live
        assertFalse(StreamerRules.isLandscape(0))
        assertTrue(StreamerRules.isLandscape(1))
        assertFalse(StreamerRules.isLandscape(2))
        assertTrue(StreamerRules.isLandscape(3))
    }

    @Test
    fun ringDropsTheOldestWhenFull() {
        val ring = FloatRing(4)
        ring.write(floatArrayOf(1f, 2f, 3f), 3)
        assertEquals(3, ring.available())
        ring.write(floatArrayOf(4f, 5f), 2)
        val out = FloatArray(4)
        val n = ring.poll(out, 4)
        assertEquals(3, n)
        assertEquals(listOf(3f, 4f, 5f), out.take(n))
        assertEquals(0, ring.poll(out, 4))
    }

    // flutter_webrtc's shapes, private fields with the same names.
    class Projection

    class Capturer(private val mediaProjection: Projection?) {
        override fun toString() = "$mediaProjection"
    }

    class Camera

    open class Info(@JvmField val capturer: Any?)

    class InfoEx(capturer: Any?) : Info(capturer)

    class GetUserMedia(private val mVideoCapturers: Map<String, Info>) {
        override fun toString() = "$mVideoCapturers"
    }

    class Handler(private val getUserMediaImpl: GetUserMedia?) {
        override fun toString() = "$getUserMediaImpl"
    }

    class Plugin(private val methodCallHandler: Handler?) {
        override fun toString() = "$methodCallHandler"
    }

    @Test
    fun findsTheScreenCapturersProjection() {
        val p = Projection()
        val plugin =
            Plugin(Handler(GetUserMedia(linkedMapOf("cam" to InfoEx(Camera()), "screen" to InfoEx(Capturer(p))))))
        assertSame(p, StreamerRules.findProjection(plugin, Projection::class.java))
    }

    @Test
    fun noProjectionWhenAStepIsMissing() {
        assertNull(StreamerRules.findProjection(Plugin(null), Projection::class.java))
        assertNull(StreamerRules.findProjection(Plugin(Handler(null)), Projection::class.java))
        val stopped = Plugin(Handler(GetUserMedia(mapOf("screen" to InfoEx(Capturer(null))))))
        assertNull(StreamerRules.findProjection(stopped, Projection::class.java))
        assertNull(StreamerRules.findProjection(Any(), Projection::class.java))
        assertNull(StreamerRules.findProjection(null, Projection::class.java))
    }
}
