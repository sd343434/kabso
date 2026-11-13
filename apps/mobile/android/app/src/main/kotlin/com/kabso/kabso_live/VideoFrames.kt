package com.kabso.kabso_live

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

/**
 * v1.136-social (D384, CONVENTIONS §10.173.2, owner 2026-11-12: «record and pick from the gallery»): the frames of a
 * picked video at given times, for the VIP animated picture. Each frame is the one closest to its time
 * (`OPTION_CLOSEST`), upright (the platform applies the video's rotation; a frame that still has the stored,
 * unrotated size of a 90° / 270° video is turned here), scaled so its longer side is at most `maxSide`, and written
 * as a JPEG into `outDir`. A time with no frame gives null. The Dart side runs the person segmentation on these files.
 */
object VideoFrames {
    fun extract(
        context: Context,
        source: String,
        timesMs: List<Long>,
        maxSide: Int,
        outDir: File,
    ): List<String?> {
        val retriever = MediaMetadataRetriever()
        try {
            if (source.startsWith("content://")) {
                retriever.setDataSource(context, Uri.parse(source))
            } else {
                retriever.setDataSource(source)
            }
            val rotation = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            val storedWidth = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val storedHeight = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            outDir.mkdirs()
            return timesMs.mapIndexed { i, ms ->
                val frame = retriever.getFrameAtTime(
                    ms * 1000,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                ) ?: return@mapIndexed null
                val upright = upright(frame, rotation, storedWidth, storedHeight)
                val scaled = scaleDown(upright, maxSide)
                val file = File(outDir, "d384_frame_${System.nanoTime()}_$i.jpg")
                FileOutputStream(file).use { scaled.compress(Bitmap.CompressFormat.JPEG, 90, it) }
                if (scaled !== upright) scaled.recycle()
                if (upright !== frame) upright.recycle()
                frame.recycle()
                file.absolutePath
            }
        } finally {
            retriever.release()
        }
    }

    /** Turns [frame] by [rotation] only when it still has the stored (unrotated) size of a 90° / 270° video. */
    private fun upright(frame: Bitmap, rotation: Int, storedWidth: Int, storedHeight: Int): Bitmap {
        val quarter = rotation == 90 || rotation == 270
        val unrotated = quarter && storedWidth != storedHeight &&
            frame.width == storedWidth && frame.height == storedHeight
        if (!unrotated) return frame
        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        return Bitmap.createBitmap(frame, 0, 0, frame.width, frame.height, matrix, true)
    }

    private fun scaleDown(frame: Bitmap, maxSide: Int): Bitmap {
        val longer = maxOf(frame.width, frame.height)
        if (maxSide <= 0 || longer <= maxSide) return frame
        val scale = maxSide.toFloat() / longer
        return Bitmap.createScaledBitmap(
            frame,
            maxOf(1, (frame.width * scale).toInt()),
            maxOf(1, (frame.height * scale).toInt()),
            true,
        )
    }
}
