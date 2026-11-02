package com.kabso.kabso_live_music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class MusicFilesTest {
    @Test
    fun arabicNameWithBracketsKeepsTheExtension() {
        assertEquals(
            "7_audio.mp3",
            MusicFiles.safeName("(تمثيل صوتى مسرحى - كأنها بترحب بالجو).mp3", "mpeg", 7),
        )
    }

    @Test
    fun noExtensionTakesTheMimeTypes() {
        assertEquals("7_audio.m4a", MusicFiles.safeName("(تمثيل صوتى مسرحى - كأنها بترحب بالجو)", "m4a", 7))
        assertEquals("7_audio", MusicFiles.safeName("تسجيل", null, 7))
    }

    @Test
    fun latinNamesAndOddExtensions() {
        assertEquals("1_My_Song_1.aac", MusicFiles.safeName("My Song (1).AAC", "aac", 1))
        assertEquals("1_a_b.ogg", MusicFiles.safeName("a b.ogg", null, 1))
        assertEquals("1_track.wav", MusicFiles.safeName("track.wav", "x-wav", 1))
        // A dot inside the name that is not an extension.
        assertEquals("1_v1_2_final_mp3.opus", MusicFiles.safeName("v1.2 final mp3.opus", "ogg", 1))
    }

    @Test
    fun pruneRemovesOnlyOldCopies() {
        val dir = Files.createTempDirectory("music").toFile()
        val old = File(dir, "old.mp3").apply { writeText("x"); setLastModified(0) }
        val fresh = File(dir, "new.mp3").apply { writeText("x") }
        MusicFiles.prune(dir, System.currentTimeMillis())
        assertFalse(old.exists())
        assertTrue(fresh.exists())
        dir.deleteRecursively()
    }
}
