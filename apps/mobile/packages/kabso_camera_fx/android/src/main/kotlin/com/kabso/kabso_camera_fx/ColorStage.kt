package com.kabso.kabso_camera_fx

import android.graphics.Matrix
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import com.cloudwebrtc.webrtc.utils.EglUtils
import org.webrtc.EglBase
import org.webrtc.GlShader
import org.webrtc.GlTextureFrameBuffer
import org.webrtc.GlUtil
import org.webrtc.RendererCommon
import org.webrtc.TextureBufferImpl
import org.webrtc.VideoFrame
import org.webrtc.VideoFrameDrawer
import org.webrtc.YuvConverter
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean

/**
 * D144: the colour stage of [CameraFxProcessor] — D143 Magic's colour filters
 * on Android.
 *
 * One affine transform on RGB in 0 … 1 (`out = M · rgb + offset`, the same
 * matrices the web shader uses), drawn on the GPU: the incoming frame (camera
 * OES texture, DeepAR's output, or I420) is drawn with [ColorMatrixDrawer] into
 * an RGBA framebuffer texture on this stage's own GL thread, whose EGL context
 * shares flutter_webrtc's root context (the camera's and the encoder's share
 * group). The result is a texture frame, rotation 0, upright.
 *
 * - No matrix → [process] returns null and the frame passes untouched (no GL
 *   work at all).
 * - Three output textures rotate; one still held downstream (encoder, preview)
 *   is never drawn over. All three held → the frame passes unfiltered.
 * - `glFinish` before handing a texture over: it is read on other threads'
 *   contexts.
 * - Any GL failure turns the stage off for good (frames pass untouched) and
 *   is logged once.
 */
internal class ColorStage {
    private val thread = HandlerThread("KabsoCameraFxGl").apply { start() }
    private val handler = Handler(thread.looper)

    /** Row-major 3 × 4; null: no filter. Read on the capture thread. */
    @Volatile private var coefficients: FloatArray? = null
    private val broken = AtomicBoolean(false)
    private val disposed = AtomicBoolean(false)

    // GL thread only.
    private var egl: EglBase? = null
    private var drawer: ColorMatrixDrawer? = null
    private var frameDrawer: VideoFrameDrawer? = null
    private var yuvConverter: YuvConverter? = null
    private val targets = ArrayList<Target>()

    private class Target(val buffer: GlTextureFrameBuffer) {
        /** Handed downstream and not yet released. GL thread only. */
        var busy = false

        /** Size changed while busy: free it when it comes back. */
        var stale = false
    }

    /** [matrix]: 12 values, row-major 3 × 4; null or identity: none. */
    fun setMatrix(matrix: FloatArray?) {
        coefficients = matrix?.takeUnless(::isIdentity)?.copyOf()
    }

    /**
     * The filtered frame, owned by the caller (release it when done), or
     * null: pass [frame] on as it is. [frame] is not released.
     */
    fun process(frame: VideoFrame): VideoFrame? {
        val matrix = coefficients ?: return null
        if (broken.get() || disposed.get()) return null
        val task = FutureTask { draw(frame, matrix) }
        if (!handler.postAtFrontOfQueue(task)) return null
        return try {
            task.get(DRAW_TIMEOUT_MS, TimeUnit.MILLISECONDS)
        } catch (_: TimeoutException) {
            // Not started yet: drop it. Started: it is using [frame], so wait.
            if (task.cancel(false)) null else runCatching { task.get() }.getOrNull()
        } catch (error: Throwable) {
            fail("draw", error)
            null
        }
    }

    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        handler.post {
            for (target in targets) target.buffer.release()
            targets.clear()
            drawer?.release()
            frameDrawer?.release()
            yuvConverter?.release()
            drawer = null
            frameDrawer = null
            yuvConverter = null
            egl?.release()
            egl = null
            thread.quitSafely()
        }
    }

    // ---------------------------------------------------------------- GL thread

    private fun draw(frame: VideoFrame, matrix: FloatArray): VideoFrame? {
        if (broken.get() || disposed.get()) return null
        if (!ensureGl()) return null
        val width = frame.rotatedWidth
        val height = frame.rotatedHeight
        if (width <= 0 || height <= 0) return null
        val target = targetFor(width, height) ?: return null
        return try {
            val drawer = drawer!!
            drawer.setMatrix(matrix)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, target.buffer.frameBufferId)
            frameDrawer!!.drawFrame(frame, drawer, null, 0, 0, width, height)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            GLES20.glFinish()
            GlUtil.checkNoGLES2Error("ColorStage.draw")
            target.busy = true
            val buffer = TextureBufferImpl(
                width, height, VideoFrame.TextureBuffer.Type.RGB,
                target.buffer.textureId, Matrix(), handler, yuvConverter!!,
            ) { handler.post { giveBack(target) } }
            VideoFrame(buffer, 0, frame.timestampNs)
        } catch (error: Throwable) {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            fail("draw", error)
            null
        }
    }

    private fun giveBack(target: Target) {
        target.busy = false
        if (target.stale || disposed.get()) {
            targets.remove(target)
            if (!disposed.get()) target.buffer.release()
        }
    }

    private fun targetFor(width: Int, height: Int): Target? {
        // A new size: free the idle ones, mark the held ones.
        val iterator = targets.iterator()
        while (iterator.hasNext()) {
            val target = iterator.next()
            if (target.buffer.width == width && target.buffer.height == height) continue
            if (target.busy) {
                target.stale = true
            } else {
                target.buffer.release()
                iterator.remove()
            }
        }
        targets.firstOrNull { !it.busy && !it.stale }?.let { return it }
        if (targets.count { !it.stale } >= POOL_SIZE) return null
        val buffer = GlTextureFrameBuffer(GLES20.GL_RGBA)
        buffer.setSize(width, height)
        return Target(buffer).also(targets::add)
    }

    private fun ensureGl(): Boolean {
        if (egl != null) return true
        return try {
            val root = EglUtils.getRootEglBaseContext()
                ?: throw IllegalStateException("no root EGL context")
            val base = EglBase.create(root, EglBase.CONFIG_PIXEL_BUFFER)
            base.createDummyPbufferSurface()
            base.makeCurrent()
            egl = base
            drawer = ColorMatrixDrawer()
            frameDrawer = VideoFrameDrawer()
            yuvConverter = YuvConverter()
            true
        } catch (error: Throwable) {
            fail("EGL setup", error)
            false
        }
    }

    private fun fail(what: String, error: Throwable) {
        if (broken.compareAndSet(false, true)) {
            Log.w(TAG, "colour stage off ($what): $error")
        }
    }

    private fun isIdentity(m: FloatArray): Boolean {
        if (m.size != 12) return false
        for (i in 0 until 12) {
            val expected = if (i == 0 || i == 5 || i == 10) 1f else 0f
            if (kotlin.math.abs(m[i] - expected) > 1e-6f) return false
        }
        return true
    }

    private companion object {
        const val TAG = "KabsoCameraFx"
        const val POOL_SIZE = 3
        const val DRAW_TIMEOUT_MS = 100L
    }
}

/**
 * A [RendererCommon.GlDrawer] that samples a frame (OES, RGB or I420
 * textures) and applies `out = M · rgb + offset` before writing it.
 * WebRTC's own GlGenericDrawer is package-private, hence this small copy of
 * its vertex/sampling conventions.
 */
internal class ColorMatrixDrawer : RendererCommon.GlDrawer {
    private enum class Kind { OES, RGB, YUV }

    private val shaders = HashMap<Kind, GlShader>()

    /** Column-major 3 × 3 (what `glUniformMatrix3fv` takes) and the offset. */
    private val matrix3 = FloatArray(9)
    private val offset = FloatArray(3)

    /** [m]: row-major 3 × 4. */
    fun setMatrix(m: FloatArray) {
        for (row in 0 until 3) {
            for (col in 0 until 3) matrix3[col * 3 + row] = m[row * 4 + col]
            offset[row] = m[row * 4 + 3]
        }
    }

    override fun drawOes(
        oesTextureId: Int, texMatrix: FloatArray, frameWidth: Int, frameHeight: Int,
        viewportX: Int, viewportY: Int, viewportWidth: Int, viewportHeight: Int,
    ) {
        prepare(Kind.OES, texMatrix, viewportX, viewportY, viewportWidth, viewportHeight)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
    }

    override fun drawRgb(
        textureId: Int, texMatrix: FloatArray, frameWidth: Int, frameHeight: Int,
        viewportX: Int, viewportY: Int, viewportWidth: Int, viewportHeight: Int,
    ) {
        prepare(Kind.RGB, texMatrix, viewportX, viewportY, viewportWidth, viewportHeight)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    override fun drawYuv(
        yuvTextures: IntArray, texMatrix: FloatArray, frameWidth: Int, frameHeight: Int,
        viewportX: Int, viewportY: Int, viewportWidth: Int, viewportHeight: Int,
    ) {
        prepare(Kind.YUV, texMatrix, viewportX, viewportY, viewportWidth, viewportHeight)
        for (i in 0 until 3) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[i])
        }
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        for (i in 0 until 3) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        }
    }

    override fun release() {
        for (shader in shaders.values) shader.release()
        shaders.clear()
    }

    private fun prepare(kind: Kind, texMatrix: FloatArray, x: Int, y: Int, w: Int, h: Int) {
        val shader = shaders.getOrPut(kind) { create(kind) }
        shader.useProgram()
        if (kind == Kind.YUV) {
            GLES20.glUniform1i(shader.getUniformLocation("y_tex"), 0)
            GLES20.glUniform1i(shader.getUniformLocation("u_tex"), 1)
            GLES20.glUniform1i(shader.getUniformLocation("v_tex"), 2)
        } else {
            GLES20.glUniform1i(shader.getUniformLocation("tex"), 0)
        }
        shader.setVertexAttribArray("in_pos", 2, FULL_RECTANGLE)
        shader.setVertexAttribArray("in_tc", 2, FULL_RECTANGLE_TEXTURE)
        GLES20.glUniformMatrix4fv(shader.getUniformLocation("tex_mat"), 1, false, texMatrix, 0)
        GLES20.glUniformMatrix3fv(shader.getUniformLocation("color_mat"), 1, false, matrix3, 0)
        GLES20.glUniform3fv(shader.getUniformLocation("color_off"), 1, offset, 0)
        GLES20.glViewport(x, y, w, h)
    }

    private fun create(kind: Kind): GlShader {
        val sample = when (kind) {
            Kind.OES -> "texture2D(tex, tc).rgb"
            Kind.RGB -> "texture2D(tex, tc).rgb"
            // BT.601 limited range, as WebRTC's own I420 drawer.
            Kind.YUV -> "yuvToRgb()"
        }
        val header = when (kind) {
            Kind.OES -> "#extension GL_OES_EGL_image_external : require\n" +
                "precision mediump float;\nuniform samplerExternalOES tex;\n"
            Kind.RGB -> "precision mediump float;\nuniform sampler2D tex;\n"
            Kind.YUV -> "precision mediump float;\n" +
                "uniform sampler2D y_tex;\nuniform sampler2D u_tex;\nuniform sampler2D v_tex;\n"
        }
        val yuv = if (kind != Kind.YUV) "" else """
            vec3 yuvToRgb() {
              float y = texture2D(y_tex, tc).r * 1.16438;
              float u = texture2D(u_tex, tc).r;
              float v = texture2D(v_tex, tc).r;
              return vec3(y + 1.59603 * v - 0.874202,
                          y - 0.391762 * u - 0.812968 * v + 0.531668,
                          y + 2.01723 * u - 1.08563);
            }
        """.trimIndent()
        val fragment = header + """
            varying vec2 tc;
            uniform mat3 color_mat;
            uniform vec3 color_off;
        """.trimIndent() + "\n" + yuv + "\n" + """
            void main() {
              vec3 rgb = $sample;
              gl_FragColor = vec4(clamp(color_mat * rgb + color_off, 0.0, 1.0), 1.0);
            }
        """.trimIndent()
        return GlShader(VERTEX_SHADER, fragment)
    }

    private companion object {
        const val VERTEX_SHADER = """
            attribute vec4 in_pos;
            attribute vec4 in_tc;
            uniform mat4 tex_mat;
            varying vec2 tc;
            void main() {
              gl_Position = in_pos;
              tc = (tex_mat * in_tc).xy;
            }
        """

        val FULL_RECTANGLE = GlUtil.createFloatBuffer(
            floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f),
        )
        val FULL_RECTANGLE_TEXTURE = GlUtil.createFloatBuffer(
            floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f),
        )
    }
}
