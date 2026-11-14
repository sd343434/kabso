package com.kabso.kabso_streamer

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * D213: the streamer's audio, on flutter_webrtc's capture post-processing (the
 * D201 music's place): WebRTC calls [process] on its audio thread with every
 * 10 ms frame of the published microphone (channel 0, floats in the 16-bit
 * range, after echo cancelling and noise suppression). The frame leaves as the
 * host's voice (silenced while the microphone is muted here) plus the game's
 * sound (Android 10+, [GameCapture]; silenced while the game is muted). One
 * published track carries both, so the microphone track itself stays
 * published while the host mutes only the voice.
 *
 * Why mixed and not a second track: flutter_webrtc 1.6.2 has no way to publish
 * a custom audio source on Android (its `getDisplayMedia` returns no audio
 * track there), and a second microphone-style track would go through the same
 * single audio device module anyway.
 */
class StreamerMixer : AudioProcessingAdapter.ExternalAudioFrameProcessing {
    @Volatile var micMuted = false
    @Volatile var gameMuted = false
    @Volatile var rate = 48000
        private set
    @Volatile var capture: GameCapture? = null
    /** Called (audio thread) when WebRTC's processing rate changes. */
    @Volatile var onRate: ((Int) -> Unit)? = null

    private var voice = FloatArray(480)
    private var game = FloatArray(480)

    override fun initialize(sampleRateHz: Int, numChannels: Int) {
        if (sampleRateHz > 0 && sampleRateHz != rate) {
            rate = sampleRateHz
            onRate?.invoke(sampleRateHz)
        }
    }

    override fun reset(newRate: Int) {
        initialize(newRate, 1)
    }

    override fun process(numBands: Int, numFrames: Int, buffer: ByteBuffer) {
        val c = capture
        if (numFrames <= 0 || (!micMuted && c == null)) return
        val floats = buffer.order(ByteOrder.nativeOrder()).asFloatBuffer()
        val n = minOf(numFrames, floats.limit())
        if (voice.size < n) {
            voice = FloatArray(n)
            game = FloatArray(n)
        }
        floats.position(0)
        floats.get(voice, 0, n)
        val got = if (c != null && c.rate == rate) c.ring.poll(game, n) else 0
        StreamerRules.mix(voice, n, micMuted, game, got, gameMuted)
        floats.position(0)
        floats.put(voice, 0, n)
    }
}

/**
 * Android 10+: the sound other apps play (media, game and unknown usages —
 * what games use) through `AudioPlaybackCapture` on the screen's own
 * MediaProjection, as mono 16-bit PCM at [rate] into [ring] (1 s). An app
 * that forbids capture (`android:allowAudioPlaybackCapture="false"` or
 * `ALLOW_CAPTURE_BY_NONE`) simply comes out silent: Android gives no error,
 * so the app tells the host up front.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class GameCapture(projection: MediaProjection, val rate: Int) {
    val ring = FloatRing(rate)
    private val record: AudioRecord
    @Volatile private var running = true
    private var thread: Thread? = null

    init {
        val config =
            AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
        val format =
            AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(rate)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        @SuppressLint("MissingPermission") // RECORD_AUDIO: the live already holds it.
        val r =
            AudioRecord.Builder()
                .setAudioFormat(format)
                .setBufferSizeInBytes(maxOf(min, rate / 5 * 2))
                .setAudioPlaybackCaptureConfig(config)
                .build()
        record = r
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("playback capture not initialized")
        }
    }

    fun start() {
        record.startRecording()
        thread =
            Thread({
                val pcm = ShortArray(rate / 100)
                val floats = FloatArray(pcm.size)
                while (running) {
                    val n =
                        try {
                            record.read(pcm, 0, pcm.size)
                        } catch (e: Exception) {
                            Log.w(TAG, "game audio read failed", e)
                            -1
                        }
                    if (n < 0) break
                    if (n == 0) continue
                    StreamerRules.pcm16ToFloat(pcm, n, floats)
                    ring.write(floats, n)
                }
            }, "kabso-streamer-game-audio").also { it.start() }
    }

    fun stop() {
        running = false
        try {
            record.stop()
        } catch (_: Exception) {
            // Already stopped.
        }
        thread?.join(500)
        record.release()
    }

    companion object {
        private const val TAG = "KabsoStreamer"
    }
}
