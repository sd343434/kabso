package com.kabso.kabso_camera_fx

import android.opengl.GLES20
import org.webrtc.GlShader
import org.webrtc.GlTextureFrameBuffer
import org.webrtc.GlUtil
import java.nio.ByteBuffer
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * D228: the free engine's GLSL passes (GLES 2.0, on [FreeFxStage]'s GL thread
 * and EGL context, which shares flutter_webrtc's root context).
 *
 * - [BLUR_FRAGMENT]: a separable 9-tap Gaussian (linear-sampled), run on a
 *   quarter-size copy — the background of «Background blur».
 * - [FX_FRAGMENT]: one full-size pass doing, in order: the face warp
 *   (slimming pulls, eye magnification — the twin of [WarpMath.warp]), skin
 *   smoothing (a 12-tap bilateral filter weighted by the landmark skin mask,
 *   [WarpMath.skin]), brighten/whiten ([WarpMath.brighten]) and the
 *   background composite with ML Kit's mask.
 *
 * Every GL error is thrown (GlUtil); [FreeFxStage] turns it into
 * [FreeFxFramePath.GlFailure]: the stage goes off, frames pass untouched.
 */
internal class FreeFxGl {
    private val blur = GlShader(VERTEX, BLUR_FRAGMENT)
    private val fx = GlShader(VERTEX, FX_FRAGMENT)
    private var maskTexture = 0
    private var maskW = 0
    private var maskH = 0

    /** The last mask upload's sequence number (-1: none). */
    var maskSeq = -1L
        private set

    // Quarter-size ping-pong textures for the blurred background.
    private var small: GlTextureFrameBuffer? = null
    private var small2: GlTextureFrameBuffer? = null

    private val taps = FloatArray(TAPS * 2)

    /** Uploads ML Kit's smoothed mask (one byte per cell, top-down rows). */
    fun uploadMask(bytes: ByteArray, w: Int, h: Int, seq: Long) {
        if (maskTexture == 0) maskTexture = GlUtil.generateTexture(GLES20.GL_TEXTURE_2D)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, maskTexture)
        GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
        val buffer = ByteBuffer.allocateDirect(w * h).put(bytes, 0, w * h)
        buffer.position(0)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, w, h, 0,
            GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, buffer,
        )
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        maskW = w
        maskH = h
        maskSeq = seq
        GlUtil.checkNoGLES2Error("FreeFxGl.uploadMask")
    }

    val hasMask: Boolean get() = maskTexture != 0 && maskSeq >= 0

    /**
     * The background: [src] (full size, RGBA texture) scaled to a quarter and
     * blurred twice each way; returns the texture id.
     */
    fun blurBackground(src: Int, width: Int, height: Int, copy: (Int, GlTextureFrameBuffer) -> Unit): Int {
        val w = max(2, width / 4)
        val h = max(2, height / 4)
        val a = small ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { small = it }
        val b = small2 ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { small2 = it }
        a.setSize(w, h)
        b.setSize(w, h)
        copy(src, a)
        repeat(2) {
            blurPass(a.textureId, b, 1f / w, 0f)
            blurPass(b.textureId, a, 0f, 1f / h)
        }
        GlUtil.checkNoGLES2Error("FreeFxGl.blur")
        return a.textureId
    }

    private fun blurPass(input: Int, out: GlTextureFrameBuffer, dx: Float, dy: Float) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, out.frameBufferId)
        GLES20.glViewport(0, 0, out.width, out.height)
        blur.useProgram()
        attributes(blur)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, input)
        GLES20.glUniform1i(blur.getUniformLocation("tex"), 0)
        GLES20.glUniform2f(blur.getUniformLocation("step"), dx, dy)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    /**
     * The final pass into [out]: [src] warped/smoothed/brightened where the
     * face is ([shape], null: no face), over [background] where ML Kit's
     * mask says background ([background] 0: no blur).
     */
    fun drawFx(
        src: Int,
        background: Int,
        out: GlTextureFrameBuffer,
        params: FreeFxParams,
        shape: FaceShape?,
        presence: Float,
    ) {
        val width = out.width
        val height = out.height
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, out.frameBufferId)
        GLES20.glViewport(0, 0, width, height)
        fx.useProgram()
        attributes(fx)
        bind(fx, "src", 0, src)
        bind(fx, "bg", 1, if (background != 0) background else src)
        bind(fx, "mask", 2, if (maskTexture != 0) maskTexture else src)
        val aspect = width.toFloat() / height
        u1(fx, "u_aspect", aspect)
        u1(fx, "u_blur", if (background != 0 && hasMask) 1f else 0f)
        val face = if (shape != null) presence.coerceIn(0f, 1f) else 0f
        u1(fx, "u_face", face)
        u1(fx, "u_smooth", if (shape != null) params.smooth else 0f)
        u1(fx, "u_brighten", params.brighten)
        val warp = shape != null && (params.slim > 0f || params.eyes > 0f)
        u1(fx, "u_warp", if (warp) 1f else 0f)
        if (shape != null) {
            GLES20.glUniform4f(fx.getUniformLocation("u_ellipse"), shape.cx, shape.cy, shape.ax, shape.ay)
            GLES20.glUniform2f(fx.getUniformLocation("u_rot"), cos(-shape.angle), sin(-shape.angle))
            val eyeS = params.eyes * FaceShape.MAX_EYES * face
            val e0 = shape.eyes[0]
            val e1 = shape.eyes[1]
            GLES20.glUniform4f(fx.getUniformLocation("u_eye0"), e0.x, e0.y, e0.r, eyeS)
            GLES20.glUniform4f(fx.getUniformLocation("u_eye1"), e1.x, e1.y, e1.r, eyeS)
            GLES20.glUniform3f(fx.getUniformLocation("u_mouth"), shape.mouth.x, shape.mouth.y, shape.mouth.r)
            for (i in 0 until 4) {
                val p = shape.pulls[i]
                GLES20.glUniform4f(fx.getUniformLocation("u_pull$i"), p.cx, p.cy, p.tx, p.ty)
                u1(fx, "u_pullR$i", p.r)
            }
            // Bilateral taps: two rings of 6, the radius ~1.8 % of the face
            // width in pixels (at least 2 px).
            val radiusPx = max(2f, shape.faceWidth * height * 0.018f)
            for (i in 0 until TAPS) {
                val ring = if (i % 2 == 0) 1f else 0.5f
                val a = i * (PI.toFloat() / 6f)
                taps[2 * i] = cos(a) * ring * radiusPx / width
                taps[2 * i + 1] = sin(a) * ring * radiusPx / height
            }
            GLES20.glUniform2fv(fx.getUniformLocation("u_taps"), TAPS, taps, 0)
        }
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        for (unit in 0..2) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + unit)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        }
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GlUtil.checkNoGLES2Error("FreeFxGl.fx")
    }

    fun release() {
        blur.release()
        fx.release()
        small?.release()
        small2?.release()
        small = null
        small2 = null
        if (maskTexture != 0) GLES20.glDeleteTextures(1, intArrayOf(maskTexture), 0)
        maskTexture = 0
        maskSeq = -1
    }

    private fun bind(shader: GlShader, name: String, unit: Int, texture: Int) {
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + unit)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
        GLES20.glUniform1i(shader.getUniformLocation(name), unit)
    }

    private fun u1(shader: GlShader, name: String, value: Float) =
        GLES20.glUniform1f(shader.getUniformLocation(name), value)

    private fun attributes(shader: GlShader) {
        shader.setVertexAttribArray("in_pos", 2, FULL_RECTANGLE)
        shader.setVertexAttribArray("in_tc", 2, FULL_RECTANGLE_TEXTURE)
    }

    companion object {
        const val TAPS = 12

        const val VERTEX = """
            attribute vec4 in_pos;
            attribute vec4 in_tc;
            varying vec2 tc;
            void main() {
              gl_Position = in_pos;
              tc = in_tc.xy;
            }
        """

        /** 9 taps in 5 linear samples (weights of a 9-wide Gaussian). */
        const val BLUR_FRAGMENT = """
            precision mediump float;
            varying vec2 tc;
            uniform sampler2D tex;
            uniform vec2 step;
            void main() {
              vec3 c = texture2D(tex, tc).rgb * 0.2270270270;
              c += texture2D(tex, tc + step * 1.3846153846).rgb * 0.3162162162;
              c += texture2D(tex, tc - step * 1.3846153846).rgb * 0.3162162162;
              c += texture2D(tex, tc + step * 3.2307692308).rgb * 0.0702702703;
              c += texture2D(tex, tc - step * 3.2307692308).rgb * 0.0702702703;
              gl_FragColor = vec4(c, 1.0);
            }
        """

        /**
         * Coordinates: `tc` is the output texture's (v bottom → top); the
         * face uniforms are in aspect space (`u · aspect`, v) — see
         * [FaceShape]. The mask's rows are top-down: sampled at (u, 1 − v).
         */
        const val FX_FRAGMENT = """
            #ifdef GL_FRAGMENT_PRECISION_HIGH
            precision highp float;
            #else
            precision mediump float;
            #endif
            varying vec2 tc;
            uniform sampler2D src;
            uniform sampler2D bg;
            uniform sampler2D mask;
            uniform float u_aspect;
            uniform float u_blur;
            uniform float u_face;
            uniform float u_smooth;
            uniform float u_brighten;
            uniform float u_warp;
            uniform vec4 u_ellipse;
            uniform vec2 u_rot;
            uniform vec4 u_eye0;
            uniform vec4 u_eye1;
            uniform vec3 u_mouth;
            uniform vec4 u_pull0;
            uniform vec4 u_pull1;
            uniform vec4 u_pull2;
            uniform vec4 u_pull3;
            uniform float u_pullR0;
            uniform float u_pullR1;
            uniform float u_pullR2;
            uniform float u_pullR3;
            uniform vec2 u_taps[12];

            float falloff(float t) {
              if (t >= 1.0) return 0.0;
              float q = 1.0 - t * t;
              return q * q;
            }

            vec2 pull(vec2 p, vec4 ct, float r) {
              return p + (ct.xy - ct.zw) * falloff(length(p - ct.zw) / r);
            }

            vec2 magnify(vec2 p, vec4 e) {
              vec2 d = p - e.xy;
              float dist = length(d);
              if (dist >= e.z || e.z <= 0.0) return p;
              float t = dist / e.z;
              return e.xy + d * (1.0 - e.w * (1.0 - t * t));
            }

            vec2 warp(vec2 p) {
              p = pull(p, u_pull0, u_pullR0);
              p = pull(p, u_pull1, u_pullR1);
              p = pull(p, u_pull2, u_pullR2);
              p = pull(p, u_pull3, u_pullR3);
              p = magnify(p, u_eye0);
              p = magnify(p, u_eye1);
              return p;
            }

            float skin(vec2 p) {
              vec2 d = p - u_ellipse.xy;
              vec2 q = vec2(d.x * u_rot.x - d.y * u_rot.y, d.x * u_rot.y + d.y * u_rot.x) / u_ellipse.zw;
              float w = 1.0 - smoothstep(0.8, 1.0, length(q));
              w *= smoothstep(0.9, 1.4, length(p - u_eye0.xy) / u_eye0.z);
              w *= smoothstep(0.9, 1.4, length(p - u_eye1.xy) / u_eye1.z);
              w *= smoothstep(0.9, 1.3, length(p - u_mouth.xy) / u_mouth.z);
              return w;
            }

            vec3 bilateral(vec2 uv, vec3 centre) {
              vec3 sum = centre;
              float total = 1.0;
              for (int i = 0; i < 12; i++) {
                vec3 c = texture2D(src, uv + u_taps[i]).rgb;
                float diff = dot(abs(c - centre), vec3(0.3333));
                float w = exp(-diff * diff * 120.0);
                sum += c * w;
                total += w;
              }
              return sum / total;
            }

            void main() {
              vec2 p = vec2(tc.x * u_aspect, tc.y);
              vec2 sp = u_warp > 0.5 ? warp(p) : p;
              vec2 suv = vec2(sp.x / u_aspect, sp.y);
              vec3 col = texture2D(src, suv).rgb;
              float sk = u_face > 0.0 ? u_face * skin(sp) : 0.0;
              if (u_smooth > 0.0 && sk > 0.01) {
                col = mix(col, bilateral(suv, col), u_smooth * sk * 0.85);
              }
              if (u_brighten > 0.0) {
                float k = u_brighten * 0.45 * (0.3 + 0.7 * sk);
                col = clamp(col + k * col * (1.0 - col) * 1.6, 0.0, 1.0);
                float l = dot(col, vec3(0.299, 0.587, 0.114));
                col = mix(col, vec3(l), u_brighten * 0.12 * sk);
              }
              if (u_blur > 0.5) {
                float m = smoothstep(0.3, 0.7, texture2D(mask, vec2(tc.x, 1.0 - tc.y)).r);
                col = mix(texture2D(bg, tc).rgb, col, m);
              }
              gl_FragColor = vec4(col, 1.0);
            }
        """

        val FULL_RECTANGLE = GlUtil.createFloatBuffer(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        val FULL_RECTANGLE_TEXTURE = GlUtil.createFloatBuffer(floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f))
    }
}
