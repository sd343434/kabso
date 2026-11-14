package com.kabso.kabso_live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** D251: `com.kabso/screen` `keepOn` always answers, never throws. */
class ScreenKeepOnTest {
    private class Window(private val failing: Boolean = false) : ScreenKeepOn.Flags {
        val calls = mutableListOf<String>()

        override fun add() {
            calls += "add"
            if (failing) throw IllegalStateException("window gone")
        }

        override fun clear() {
            calls += "clear"
            if (failing) throw IllegalStateException("window gone")
        }
    }

    @Test
    fun trueAddsTheFlagAndAnswersSuccess() {
        val window = Window()
        assertNull(ScreenKeepOn.apply(true, window))
        assertEquals(listOf("add"), window.calls)
    }

    @Test
    fun falseClearsTheFlag() {
        val window = Window()
        assertNull(ScreenKeepOn.apply(false, window))
        assertEquals(listOf("clear"), window.calls)
    }

    @Test
    fun anythingButTrueClearsTheFlag() {
        val window = Window()
        assertNull(ScreenKeepOn.apply(null, window))
        assertNull(ScreenKeepOn.apply("true", window))
        assertNull(ScreenKeepOn.apply(1, window))
        assertEquals(listOf("clear", "clear", "clear"), window.calls)
    }

    @Test
    fun noWindowIsAnErrorReplyNotACrash() {
        assertEquals(ScreenKeepOn.NO_WINDOW, ScreenKeepOn.apply(true, null))
        assertEquals(ScreenKeepOn.NO_WINDOW, ScreenKeepOn.apply(false, null))
    }

    @Test
    fun aWindowThatThrowsIsAnErrorReplyNotACrash() {
        val window = Window(failing = true)
        assertEquals(ScreenKeepOn.FAILED, ScreenKeepOn.apply(true, window))
        assertEquals(ScreenKeepOn.FAILED, ScreenKeepOn.apply(false, window))
        assertEquals(listOf("add", "clear"), window.calls)
    }
}
