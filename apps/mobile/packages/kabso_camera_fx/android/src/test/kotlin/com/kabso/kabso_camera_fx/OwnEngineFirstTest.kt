package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

/**
 * D228 (the D232 finding): the live's foreground service starts a second
 * FlutterEngine whose flutter_webrtc overwrites `sharedSingleton` with an
 * instance that has no tracks. The camera track must be looked up in the
 * plugin's own engine first.
 */
class OwnEngineFirstTest {
    /** A flutter_webrtc instance: the tracks it created. */
    private class FakeWebRtc(val name: String, vararg tracks: String) {
        val tracks = tracks.toSet()
        var lookups = 0
        fun localTrack(id: String): String? {
            lookups++
            return if (id in tracks) "track:$name:$id" else null
        }
    }

    @Test
    fun `the service engine overwrote the singleton - the own engine still finds the camera`() {
        val app = FakeWebRtc("app", "cam-1")
        val service = FakeWebRtc("service")
        val found = OwnEngineFirst.find(own = app, shared = service) { it.localTrack("cam-1") }
        assertSame(app, found!!.first)
        assertEquals("track:app:cam-1", found.second)
        assertEquals("the singleton is not even asked", 0, service.lookups)
    }

    @Test
    fun `before the service the singleton is the own instance - asked once`() {
        val app = FakeWebRtc("app", "cam-1")
        val found = OwnEngineFirst.find(own = app, shared = app) { it.localTrack("cam-1") }
        assertSame(app, found!!.first)
        assertEquals(1, app.lookups)
    }

    @Test
    fun `no own instance (engine without the registry entry) - the singleton is the fallback`() {
        val app = FakeWebRtc("app", "cam-1")
        val found = OwnEngineFirst.find(own = null, shared = app) { it.localTrack("cam-1") }
        assertSame(app, found!!.first)
    }

    @Test
    fun `the own instance lacks the track but the singleton has it - the singleton wins`() {
        val own = FakeWebRtc("own")
        val shared = FakeWebRtc("shared", "cam-2")
        assertSame(shared, OwnEngineFirst.find(own, shared) { it.localTrack("cam-2") }!!.first)
    }

    @Test
    fun `nobody has the track, or a lookup throws - null, never a crash`() {
        val own = FakeWebRtc("own")
        val shared = FakeWebRtc("shared")
        assertNull(OwnEngineFirst.find(own, shared) { it.localTrack("cam-9") })
        assertNull(OwnEngineFirst.find<FakeWebRtc, String>(null, null) { it.localTrack("x") })
        val throwing = OwnEngineFirst.find(own, FakeWebRtc("shared", "cam-1")) { plugin ->
            if (plugin === own) throw IllegalStateException("no factory") else plugin.localTrack("cam-1")
        }
        assertEquals("track:shared:cam-1", throwing!!.second)
    }
}
