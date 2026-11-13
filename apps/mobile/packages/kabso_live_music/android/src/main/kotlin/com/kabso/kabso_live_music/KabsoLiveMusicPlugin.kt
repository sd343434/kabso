package com.kabso.kabso_live_music

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.audio.AudioProcessingController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

/**
 * D201: the Dart side of [MusicMixer] (`com.kabso/live_music`).
 *
 * - `pick`: the system document picker for audio files (`ACTION_OPEN_DOCUMENT`,
 *   any audio type, several at once). No storage permission: the picker grants the
 *   chosen files only; each is copied into the app's own storage (≤ 50 MB each)
 *   under a safe ASCII name that keeps the format's extension ([MusicFiles]), so
 *   the decoder reads a plain file; answers `[{path, name}]`.
 * - `load {path}` → duration ms; `play`, `pause`, `stop`, `setVolume {volume}`,
 *   `setDucking {on}`.
 * - Errors (D232): `load` fails with `not_ready` (no live microphone to mix
 *   into), `unsupported` (no decoder for the format) or `unreadable`; the
 *   `error` event carries `{reason}` (the same codes).
 * - Back to Dart: `position {positionMs, durationMs}`, `completed`, `error`.
 *
 * The mixer joins flutter_webrtc's capture post-processing on the first `load`
 * (its audio module exists once the live's microphone track was created) and
 * leaves it on `stop` and when the engine detaches.
 *
 * D232 (the owner's «تعذّر تشغيل هذا الملف.» for every file): the live runs a
 * foreground service (flutter_foreground_task, D123) whose task starts a SECOND
 * FlutterEngine; it registers every plugin again, and flutter_webrtc's
 * constructor overwrites the static `FlutterWebRTCPlugin.sharedSingleton` with
 * that engine's instance — whose WebRTC factory was never created, so its
 * `audioProcessingController` is null and every `load` answered `not_ready`.
 * The mixer now joins the flutter_webrtc of ITS OWN engine (the app's), and
 * only falls back to the singleton.
 */
class KabsoLiveMusicPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var cacheDir: File? = null
    private var engine: FlutterEngine? = null

    /** The controller the mixer joined (left on `stop` / detach). */
    private var joined: AudioProcessingController? = null
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var attached = false

    private val mixer =
        MusicMixer(
            object : MusicMixer.Events {
                override fun position(positionMs: Long, durationMs: Long) {
                    main.post {
                        channel?.invokeMethod(
                            "position",
                            mapOf("positionMs" to positionMs, "durationMs" to durationMs),
                        )
                    }
                }

                override fun completed() {
                    main.post { channel?.invokeMethod("completed", null) }
                }

                override fun failed(reason: String) {
                    main.post { channel?.invokeMethod("error", mapOf("reason" to reason)) }
                }
            },
        )

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        // D232: the app's own storage (not the cache the system may clear while
        // the live runs); copies older than a day are removed.
        cacheDir = File(b.applicationContext.filesDir, "kabso_music").also { dir ->
            Thread({ MusicFiles.prune(dir, System.currentTimeMillis()) }, "kabso-live-music-prune").start()
        }
        @Suppress("DEPRECATION")
        engine = b.flutterEngine
        channel = MethodChannel(b.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        mixer.stop()
        detach()
        engine = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        activity = b.activity
        b.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    /** D232: this engine's flutter_webrtc audio module, else the singleton's. */
    private fun controller(): AudioProcessingController? {
        val own = engine?.plugins?.get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin
        for (plugin in listOfNotNull(own, FlutterWebRTCPlugin.sharedSingleton)) {
            val c =
                try {
                    plugin.audioProcessingController
                } catch (_: RuntimeException) {
                    null
                }
            if (c != null) return c
        }
        return null
    }

    private fun attach(): Boolean {
        if (attached) return true
        val controller = controller() ?: return false
        controller.capturePostProcessing.addProcessor(mixer)
        joined = controller
        attached = true
        return true
    }

    private fun detach() {
        if (!attached) return
        joined?.capturePostProcessing?.removeProcessor(mixer)
        joined = null
        attached = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "load" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path", null)
                    return
                }
                if (!attach()) {
                    result.error("not_ready", "the live microphone is not running", null)
                    return
                }
                try {
                    result.success(mixer.load(path))
                } catch (e: MusicMixer.UnsupportedFormat) {
                    Log.w(TAG, "load: no decoder for ${e.mime}")
                    result.error("unsupported", e.mime, null)
                } catch (e: Exception) {
                    Log.w(TAG, "load failed: ${e.javaClass.simpleName}")
                    result.error("unreadable", "the file cannot be decoded", null)
                }
            }
            "play" -> {
                mixer.play()
                result.success(null)
            }
            "pause" -> {
                mixer.pause()
                result.success(null)
            }
            "stop" -> {
                mixer.stop()
                detach()
                result.success(null)
            }
            "setVolume" -> {
                val v = call.argument<Double>("volume") ?: 0.35
                mixer.volume = v.toFloat().coerceIn(0f, 1f)
                result.success(null)
            }
            "setDucking" -> {
                mixer.ducking = call.argument<Boolean>("on") ?: true
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        val a = activity
        if (a == null || pending != null) {
            result.error("busy", "no activity or a pick is open", null)
            return
        }
        pending = result
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        a.startActivityForResult(intent, REQUEST_PICK)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, String>>())
            return true
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
        data.data?.let { if (uris.isEmpty()) uris.add(it) }
        val a = activity
        val dir = cacheDir
        if (a == null || dir == null) {
            result.success(emptyList<Map<String, String>>())
            return true
        }
        Thread({
            val files = mutableListOf<Map<String, String>>()
            dir.mkdirs()
            for (uri in uris) {
                try {
                    val name = displayName(a, uri)
                    val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(a.contentResolver.getType(uri))
                    val target = File(dir, MusicFiles.safeName(name, ext, System.nanoTime()))
                    var copied = 0L
                    a.contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { out ->
                            val buf = ByteArray(64 * 1024)
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                copied += n
                                if (copied > MAX_BYTES) throw IllegalStateException("too large")
                                out.write(buf, 0, n)
                            }
                        }
                    }
                    if (copied > 0) files.add(mapOf("path" to target.path, "name" to name)) else target.delete()
                } catch (e: Exception) {
                    Log.w(TAG, "copy failed: ${e.javaClass.simpleName}")
                }
            }
            main.post { result.success(files) }
        }, "kabso-live-music-copy").start()
        return true
    }

    private fun displayName(a: Activity, uri: Uri): String {
        a.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val name = c.getString(0)
                if (!name.isNullOrBlank()) return name
            }
        }
        return uri.lastPathSegment ?: "audio"
    }

    companion object {
        const val CHANNEL = "com.kabso/live_music"
        private const val TAG = "KabsoLiveMusic"
        private const val REQUEST_PICK = 0x4B4D
        private const val MAX_BYTES = 50L * 1024 * 1024
    }
}
