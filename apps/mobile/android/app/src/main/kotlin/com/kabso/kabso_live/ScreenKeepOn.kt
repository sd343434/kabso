package com.kabso.kabso_live

/**
 * D251: the `com.kabso/screen` `keepOn` rule, kept apart from the Activity
 * so it can be tested on the JVM (`ScreenKeepOnTest`).
 *
 * The call is answered exactly once, at once, on the thread it arrives on
 * (the platform's main thread, where the window may be touched), and never
 * throws: a missing or finishing window, or a window that refuses the flag,
 * is an error reply the Dart side treats as best effort (a note on the
 * second camera's screen). The Dart side also never waits on it for more
 * than a few seconds.
 */
internal object ScreenKeepOn {
    /** The window's `FLAG_KEEP_SCREEN_ON`. */
    interface Flags {
        fun add()

        fun clear()
    }

    /** No window to set the flag on (the Activity is finishing or gone). */
    const val NO_WINDOW = "no_window"

    /** The window refused the flag. */
    const val FAILED = "failed"

    /**
     * Turns the flag on when [argument] is `true`, off otherwise. Returns
     * null when done, else [NO_WINDOW] or [FAILED].
     */
    fun apply(argument: Any?, flags: Flags?): String? {
        val on = argument as? Boolean ?: false
        val window = flags ?: return NO_WINDOW
        return try {
            if (on) window.add() else window.clear()
            null
        } catch (error: Throwable) {
            FAILED
        }
    }
}
