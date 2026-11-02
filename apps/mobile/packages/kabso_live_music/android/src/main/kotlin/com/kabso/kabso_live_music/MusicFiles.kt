package com.kabso.kabso_live_music

import java.io.File

/**
 * D232: the copies of the files the host picked (plain Kotlin, JVM-tested).
 *
 * A picked file arrives as a `content://` URI whose display name can be Arabic,
 * hold spaces and brackets, or have no extension at all («(تمثيل صوتى مسرحى -
 * كأنها بترحب بالجو)»). The copy gets an ASCII name that is unique, short, and
 * keeps the format's extension — from the name, else from the MIME type — so
 * nothing downstream depends on the original name.
 */
object MusicFiles {
    private const val MAX_STEM = 60
    private val EXT = Regex("^[A-Za-z0-9]{1,5}$")

    /** A day: copies older than this are removed when the plugin starts. */
    const val MAX_AGE_MS = 24L * 60 * 60 * 1000

    /** `<stamp>_<ascii stem>.<ext>`; [mimeExt] is the extension of the URI's MIME type, if any. */
    fun safeName(displayName: String, mimeExt: String?, stamp: Long): String {
        val dot = displayName.lastIndexOf('.')
        val nameExt = if (dot > 0) displayName.substring(dot + 1) else null
        val ext =
            when {
                nameExt != null && EXT.matches(nameExt) -> nameExt.lowercase()
                mimeExt != null && EXT.matches(mimeExt) -> mimeExt.lowercase()
                else -> null
            }
        val stem = if (dot > 0 && ext == nameExt?.lowercase()) displayName.substring(0, dot) else displayName
        val ascii =
            stem
                .replace(Regex("[^A-Za-z0-9_-]+"), "_")
                .trim('_', '-')
                .take(MAX_STEM)
                .ifEmpty { "audio" }
        return if (ext == null) "${stamp}_$ascii" else "${stamp}_$ascii.$ext"
    }

    /** Removes the copies in [dir] older than [MAX_AGE_MS] at [now]. */
    fun prune(dir: File, now: Long) {
        dir.listFiles()?.forEach { f ->
            if (f.isFile && now - f.lastModified() > MAX_AGE_MS) f.delete()
        }
    }
}
