package com.kabso.kabso_camera_fx

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * D251c: a camera with a session (or one opening) switches in place; one
 * with no session is restarted on the other camera (never stopped: nothing
 * waits on the main thread); a switch already under way is left alone. The
 * error message has fixed words only.
 */
class FlipRulesTest {
    @Test
    fun runningOrOpeningSwitches() {
        assertEquals(FlipRules.Action.SWITCH, FlipRules.decide(running = true, opening = false, switchIdle = true))
        assertEquals(FlipRules.Action.SWITCH, FlipRules.decide(running = false, opening = true, switchIdle = true))
    }

    @Test
    fun noSessionRestarts() {
        assertEquals(FlipRules.Action.RESTART, FlipRules.decide(running = false, opening = false, switchIdle = true))
    }

    @Test
    fun aSwitchUnderWayIsBusy() {
        assertEquals(FlipRules.Action.BUSY, FlipRules.decide(running = true, opening = false, switchIdle = false))
        assertEquals(FlipRules.Action.BUSY, FlipRules.decide(running = false, opening = false, switchIdle = false))
    }

    @Test
    fun messagesUseFixedWordsOnly() {
        assertEquals(
            "why=no-capturer state=DISCONNECTED",
            FlipRules.message(FlipRules.Why.NO_CAPTURER, "DISCONNECTED"),
        )
        assertEquals("why=no-device", FlipRules.message(FlipRules.Why.NO_DEVICE, null))
        // Anything that isn't a known camera state (an id, free text) is dropped.
        assertEquals("why=switch-error", FlipRules.message(FlipRules.Why.SWITCH_ERROR, "track-123"))
    }
}
