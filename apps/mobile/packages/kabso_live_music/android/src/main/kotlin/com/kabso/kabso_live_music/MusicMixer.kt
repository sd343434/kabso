package com.kabso.kabso_live_music

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import com.cloudwebrtc.webrtc.audio.AudioProcessingAdapter
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * D201: one music file mixed into the host's microphone.
 *
 * Registered on flutter_webrtc's `capturePostProcessing`: WebRTC calls [process]
 * on its audio thread with every 10 ms capture frame of the microphone that is
 * published (channel 0, floats in the 16-bit range), after echo cancelling and
 * noise suppression — so the music is neither cancelled nor suppressed, and the
 * one published track carries voice + music. The host does not hear the music
 * on the phone (nothing is played locally; playing it would leak into the
 * microphone a second time).
 *
 * A decoder thread ([Decoder]) turns the file into mono floats at the
 * processing rate into a 1-second [FloatRing]; [process] only reads from it.
 */
class MusicMixer(private val events: Events) : AudioProcessingAdapter.ExternalAudioFrameProcessing {
    interface Events {
        /** Every ~250 ms while playing (any thread). */
        fun position(positionMs: Long, durationMs: Long)

        /** The file played to its end (any thread). */
        fun completed()

        /** The file could not be decoded (any thread): `unsupported` or `unreadable`. */
        fun failed(reason: String)
    }

    @Volatile private var rate = 48000

    @Volatile private var decoder: Decoder? = null

    @Volatile var playing = false

    /** 0 … 1. */
    @Volatile var volume = 0.35f

    @Volatile var ducking = true

    private val ducker = Ducker()
    private var lastGain = 0f
    private var voice = FloatArray(480)
    private var music = FloatArray(480)
    private var consumed = 0L
    private var lastReportAt = 0L

    // ---- the audio thread ------------------------------------------------------------------

    override fun initialize(sampleRateHz: Int, numChannels: Int) {
        if (sampleRateHz > 0 && sampleRateHz != rate) {
            rate = sampleRateHz
            decoder?.retarget(sampleRateHz)
        }
    }

    override fun reset(newRate: Int) {
        initialize(newRate, 1)
    }

    override fun process(numBands: Int, numFrames: Int, buffer: ByteBuffer) {
        val d = decoder
        if (!playing || d == null || numFrames <= 0) {
            lastGain = 0f
            return
        }
        val floats = buffer.order(ByteOrder.nativeOrder()).asFloatBuffer()
        val n = minOf(numFrames, floats.limit())
        if (voice.size < n) {
            voice = FloatArray(n)
            music = FloatArray(n)
        }
        floats.position(0)
        floats.get(voice, 0, n)
        val frameMs = n * 1000f / rate
        val factor = ducker.next(MixMath.rms(voice, n), ducking, frameMs)
        val gain = volume * factor
        val got = d.ring.poll(music, n)
        MixMath.mixInto(voice, music, n, lastGain, gain)
        lastGain = gain
        floats.position(0)
        floats.put(voice, 0, n)
        consumed += got
        val atMs = consumed * 1000 / rate
        if (atMs - lastReportAt >= 250) {
            lastReportAt = atMs
            events.position(atMs, d.durationMs)
        }
        if (got == 0 && d.finished) {
            playing = false
            events.completed()
        }
    }

    // ---- control (the platform thread) ----------------------------------------------------

    /** Loads [path] (stops the last file); its duration in ms, or 0 when unknown. Throws when unreadable. */
    fun load(path: String): Long {
        stop()
        val next = Decoder(path, rate) { events.failed("unreadable") }
        decoder = next
        consumed = 0
        lastReportAt = 0
        ducker.reset()
        next.start()
        return next.durationMs
    }

    fun play() {
        decoder?.resume()
        playing = decoder != null
    }

    fun pause() {
        playing = false
        decoder?.pause()
    }

    fun stop() {
        playing = false
        val d = decoder
        decoder = null
        d?.close()
    }

    /** D232: the phone has no decoder for [mime]. */
    class UnsupportedFormat(val mime: String) : Exception("no decoder for $mime")

    /**
     * Decodes [path] to mono floats at [target] Hz on its own thread, filling
     * [ring] (blocking while it is full or paused).
     */
    class Decoder(private val path: String, target: Int, private val onFailed: () -> Unit) {
        val ring = FloatRing(48000)

        @Volatile var finished = false
            private set

        @Volatile private var target = target

        @Volatile private var running = true

        @Volatile private var paused = true

        private val extractor = MediaExtractor()
        private val format: MediaFormat
        private val track: Int
        val durationMs: Long
        private var thread: Thread? = null

        /**
         * D232: created and started here, on `load`, so a format the phone cannot
         * decode fails the `load` itself (`unsupported`) instead of a silent
         * error event after "play".
         */
        private val codec: MediaCodec

        init {
            try {
                extractor.setDataSource(path)
                var found = -1
                var f: MediaFormat? = null
                for (i in 0 until extractor.trackCount) {
                    val tf = extractor.getTrackFormat(i)
                    if (tf.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                        found = i
                        f = tf
                        break
                    }
                }
                if (found < 0 || f == null) throw IllegalArgumentException("no audio track")
                track = found
                format = f
                durationMs =
                    if (f.containsKey(MediaFormat.KEY_DURATION)) f.getLong(MediaFormat.KEY_DURATION) / 1000 else 0
                extractor.selectTrack(track)
                // Some extractors (WAV, FLAC) hand samples larger than a decoder's
                // default input buffer: readSampleData would throw.
                if (!f.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    f.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 256 * 1024)
                }
                val mime = f.getString(MediaFormat.KEY_MIME)!!
                codec =
                    try {
                        MediaCodec.createDecoderByType(mime).also {
                            try {
                                it.configure(f, null, null, 0)
                                it.start()
                            } catch (e: Exception) {
                                it.release()
                                throw e
                            }
                        }
                    } catch (e: Exception) {
                        throw UnsupportedFormat(mime)
                    }
            } catch (e: Exception) {
                extractor.release()
                throw e
            }
        }

        fun start() {
            thread = Thread({ run() }, "kabso-live-music").also { it.start() }
        }

        fun retarget(rate: Int) {
            target = rate
        }

        fun pause() {
            paused = true
        }

        fun resume() {
            paused = false
        }

        fun close() {
            running = false
            thread?.interrupt()
        }

        private fun run() {
            try {
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                var floatPcm = false
                var resampler = LinearResampler(outRate, target)
                var resampledFor = target
                var mono = FloatArray(4096)
                var interleaved = FloatArray(8192)
                while (running) {
                    while (paused && running) Thread.sleep(10)
                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(10_000)
                        if (inIndex >= 0) {
                            val input = codec.getInputBuffer(inIndex)!!
                            val size = extractor.readSampleData(input, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val outIndex = codec.dequeueOutputBuffer(info, 10_000)
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val of = codec.outputFormat
                        outRate = of.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = of.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        floatPcm =
                            of.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            of.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                        resampler = LinearResampler(outRate, target)
                        resampledFor = target
                        continue
                    }
                    if (outIndex < 0) continue
                    val out = codec.getOutputBuffer(outIndex)!!.order(ByteOrder.nativeOrder())
                    val samples = if (floatPcm) info.size / 4 else info.size / 2
                    if (interleaved.size < samples) interleaved = FloatArray(samples)
                    out.position(info.offset)
                    if (floatPcm) {
                        val fb = out.asFloatBuffer()
                        fb.get(interleaved, 0, samples)
                    } else {
                        val sb = out.asShortBuffer()
                        for (i in 0 until samples) interleaved[i] = sb.get(i) / MixMath.S16
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    val frames = samples / maxOf(1, channels)
                    if (mono.size < frames) mono = FloatArray(frames)
                    MixMath.downmix(interleaved, frames, maxOf(1, channels), mono)
                    if (resampledFor != target) {
                        resampler = LinearResampler(outRate, target)
                        resampledFor = target
                        ring.clear()
                    }
                    resampler.process(mono, frames) { v ->
                        while (running && !ring.offer(v)) Thread.sleep(5)
                    }
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
                finished = true
            } catch (_: InterruptedException) {
                // Closed.
            } catch (e: Exception) {
                Log.w(TAG, "music decode failed: ${e.javaClass.simpleName}")
                finished = true
                if (running) onFailed()
            } finally {
                try {
                    codec.stop()
                } catch (_: Exception) {
                }
                codec.release()
                extractor.release()
            }
        }
    }

    companion object {
        private const val TAG = "KabsoLiveMusic"
    }
}
